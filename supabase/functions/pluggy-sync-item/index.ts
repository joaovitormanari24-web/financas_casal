// Chamado pelo app: (a) logo após o widget Pluggy Connect linkar um banco
// novo, pra registrar o Item e trazer os dados pela primeira vez; e (b) no
// botão "Sincronizar agora" — mesma chamada, idempotente.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { syncItem } from "./sync.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "missing_authorization" }), { status: 401 });
  }

  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) {
    return new Response(JSON.stringify({ error: "invalid_session" }), { status: 401 });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    const { itemId, institutionName } = await req.json();
    if (!itemId) {
      return new Response(JSON.stringify({ error: "missing_item_id" }), { status: 400 });
    }

    const { data: member, error: memberError } = await admin
      .from("household_members")
      .select("id, household_id")
      .eq("user_id", userData.user.id)
      .limit(1)
      .single();
    if (memberError || !member) {
      return new Response(JSON.stringify({ error: "no_household" }), { status: 400 });
    }

    await admin.from("bank_connections").upsert(
      {
        household_id: member.household_id,
        member_id: member.id,
        pluggy_item_id: itemId,
        institution_name: institutionName ?? null,
      },
      { onConflict: "pluggy_item_id", ignoreDuplicates: false },
    );

    const result = await syncItem(admin, itemId);
    return new Response(JSON.stringify({ success: true, ...result }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
