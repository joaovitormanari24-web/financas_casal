// Chamado pelo app: (a) logo após o widget Pluggy Connect linkar um banco
// novo, pra registrar o Item e trazer os dados pela primeira vez; e (b) no
// botão "Sincronizar agora" — mesma chamada, idempotente.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { syncItem } from "./sync.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "missing_authorization" }, 401);
  }

  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await callerClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "invalid_session" }, 401);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    const { itemId, institutionName } = await req.json();
    if (!itemId) {
      return jsonResponse({ error: "missing_item_id" }, 400);
    }

    const { data: member, error: memberError } = await admin
      .from("household_members")
      .select("id, household_id")
      .eq("user_id", userData.user.id)
      .limit(1)
      .single();
    if (memberError || !member) {
      return jsonResponse({ error: "no_household" }, 400);
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
    return jsonResponse({ success: true, ...result });
  } catch (err) {
    return jsonResponse({ error: String(err) }, 500);
  }
});
