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

// Chamado direto do navegador — precisa responder o preflight OPTIONS do
// CORS, senão o fetch nunca chega a sair (mesma causa do bug visto em
// pluggy-connect-token/pluggy-sync-item).
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
  const userId = userData.user.id;

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: memberships, error: membershipError } = await admin
    .from("household_members")
    .select("id, household_id")
    .eq("user_id", userId);

  if (membershipError) {
    return jsonResponse({ error: membershipError.message }, 500);
  }

  for (const membership of memberships ?? []) {
    const { count, error: countError } = await admin
      .from("household_members")
      .select("id", { count: "exact", head: true })
      .eq("household_id", membership.household_id);

    if (countError) {
      return jsonResponse({ error: countError.message }, 500);
    }

    if ((count ?? 0) > 1) {
      return jsonResponse(
        {
          error: "shared_household",
          message:
            "Você compartilha um household com outra pessoa — exclua sua conta só depois que " +
            "ela sair do household (Configurações > Sair do household), pra não apagar os dados dela também.",
        },
        409,
      );
    }

    // Único membro: apaga o household inteiro (cascade cuida do resto).
    await admin.from("households").delete().eq("id", membership.household_id);
  }

  const { error: deleteUserError } = await admin.auth.admin.deleteUser(userId);
  if (deleteUserError) {
    return jsonResponse({ error: deleteUserError.message }, 500);
  }

  return jsonResponse({ success: true });
});
