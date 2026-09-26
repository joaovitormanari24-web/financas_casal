// Exclusão de conta (LGPD): o próprio usuário decide se apaga tudo. Só
// funciona quando ele é o único membro do household — se o household é
// compartilhado, apagar tudo destruiria o histórico do parceiro(a) também,
// então isso é recusado com uma mensagem explicando o motivo (ver
// SettingsScreen._deleteAccount no cliente).
//
// verify_jwt fica ligado (padrão) — a identidade vem do próprio token de
// quem chama, nunca de um id enviado no corpo da requisição, então ninguém
// consegue apagar a conta de outra pessoa.
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

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
  const userId = userData.user.id;

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: memberships, error: membershipError } = await admin
    .from("household_members")
    .select("id, household_id")
    .eq("user_id", userId);

  if (membershipError) {
    return new Response(JSON.stringify({ error: membershipError.message }), { status: 500 });
  }

  for (const membership of memberships ?? []) {
    const { count, error: countError } = await admin
      .from("household_members")
      .select("id", { count: "exact", head: true })
      .eq("household_id", membership.household_id);

    if (countError) {
      return new Response(JSON.stringify({ error: countError.message }), { status: 500 });
    }

    if ((count ?? 0) > 1) {
      return new Response(
        JSON.stringify({
          error: "shared_household",
          message:
            "Você compartilha um household com outra pessoa — exclua sua conta só depois que " +
            "ela sair do household (Configurações > Sair do household), pra não apagar os dados dela também.",
        }),
        { status: 409, headers: { "Content-Type": "application/json" } },
      );
    }

    // Único membro: apaga o household inteiro (cascade cuida do resto).
    await admin.from("households").delete().eq("id", membership.household_id);
  }

  const { error: deleteUserError } = await admin.auth.admin.deleteUser(userId);
  if (deleteUserError) {
    return new Response(JSON.stringify({ error: deleteUserError.message }), { status: 500 });
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
