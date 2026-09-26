// Gera um Connect Token de curta duração pro widget Pluggy Connect abrir
// com segurança no cliente — o CLIENT_ID/CLIENT_SECRET nunca saem daqui.
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const PLUGGY_CLIENT_ID = Deno.env.get("PLUGGY_CLIENT_ID")!;
const PLUGGY_CLIENT_SECRET = Deno.env.get("PLUGGY_CLIENT_SECRET")!;

async function getPluggyApiKey(): Promise<string> {
  const res = await fetch("https://api.pluggy.ai/auth", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ clientId: PLUGGY_CLIENT_ID, clientSecret: PLUGGY_CLIENT_SECRET }),
  });
  if (!res.ok) {
    throw new Error(`pluggy auth failed: ${res.status} ${await res.text()}`);
  }
  const data = await res.json();
  return data.apiKey as string;
}

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

  try {
    const apiKey = await getPluggyApiKey();
    const res = await fetch("https://api.pluggy.ai/connect_token", {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-API-KEY": apiKey },
      body: JSON.stringify({ clientUserId: userData.user.id }),
    });
    if (!res.ok) {
      return new Response(
        JSON.stringify({ error: "pluggy_connect_token_failed", details: await res.text() }),
        { status: 502 },
      );
    }
    const data = await res.json();
    return new Response(JSON.stringify({ connectToken: data.accessToken }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
