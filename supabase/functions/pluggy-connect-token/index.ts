// Gera um Connect Token de curta duração pro widget Pluggy Connect abrir
// com segurança no cliente — o CLIENT_ID/CLIENT_SECRET nunca saem daqui.
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const PLUGGY_CLIENT_ID = Deno.env.get("PLUGGY_CLIENT_ID")!;
const PLUGGY_CLIENT_SECRET = Deno.env.get("PLUGGY_CLIENT_SECRET")!;

// O app chama isso direto do navegador (fetch cross-origin), que sempre
// manda um OPTIONS de "preflight" antes da chamada de verdade — sem
// responder esse preflight com os headers certos, o navegador nunca chega
// a mandar a chamada real (é o que estava dando o erro reportado).
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

async function getPluggyApiKey(): Promise<string> {
  if (!PLUGGY_CLIENT_ID || !PLUGGY_CLIENT_SECRET) {
    throw new Error("PLUGGY_CLIENT_ID/PLUGGY_CLIENT_SECRET not configured");
  }
  const res = await fetch("https://api.pluggy.ai/auth", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ clientId: PLUGGY_CLIENT_ID, clientSecret: PLUGGY_CLIENT_SECRET }),
  });
  if (!res.ok) {
    const details = await res.text();
    console.error("pluggy auth failed", res.status, details);
    throw new Error(`pluggy auth failed: ${res.status} ${details}`);
  }
  const data = await res.json();
  return data.apiKey as string;
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

  try {
    const apiKey = await getPluggyApiKey();
    const res = await fetch("https://api.pluggy.ai/connect_token", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-API-KEY": apiKey },
      body: JSON.stringify({ clientUserId: userData.user.id }),
    });
    if (!res.ok) {
      const details = await res.text();
      console.error("pluggy connect_token failed", res.status, details);
      return jsonResponse({ error: "pluggy_connect_token_failed", details }, 502);
    }
    const data = await res.json();
    return jsonResponse({ connectToken: data.accessToken });
  } catch (err) {
    console.error("pluggy-connect-token error", err);
    return jsonResponse({ error: String(err) }, 500);
  }
});
