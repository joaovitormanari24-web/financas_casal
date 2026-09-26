// Envia push notifications pros dispositivos inscritos de um household,
// disparado por um trigger no Postgres a cada nova linha em `notifications`
// (ver supabase/migrations/0010_push_notifications.sql).
//
// Autenticado por um segredo compartilhado (header x-push-secret) em vez de
// JWT — quem chama é o próprio Postgres do projeto, não um usuário logado.
// Chaves e segredo vêm de variáveis de ambiente (Edge Function secrets) —
// nunca hardcoded aqui.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "jsr:@supabase/supabase-js@2";

const PUSH_SHARED_SECRET = Deno.env.get("PUSH_SHARED_SECRET")!;
const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY")!;
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY")!;

webpush.setVapidDetails(
  "mailto:joaovitormanari24@gmail.com",
  VAPID_PUBLIC_KEY,
  VAPID_PRIVATE_KEY,
);

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req) => {
  if (!PUSH_SHARED_SECRET || req.headers.get("x-push-secret") !== PUSH_SHARED_SECRET) {
    return new Response("Forbidden", { status: 403 });
  }

  const { household_id, title, body } = await req.json();
  if (!household_id || !title) {
    return new Response("Bad request", { status: 400 });
  }

  const { data: subs, error } = await supabase
    .from("push_subscriptions")
    .select("id, endpoint, p256dh, auth")
    .eq("household_id", household_id);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  const payload = JSON.stringify({ title, body: body ?? "" });

  const results = await Promise.allSettled(
    (subs ?? []).map(async (sub) => {
      try {
        await webpush.sendNotification(
          {
            endpoint: sub.endpoint,
            keys: { p256dh: sub.p256dh, auth: sub.auth },
          },
          payload,
        );
      } catch (err) {
        const status = (err as { statusCode?: number }).statusCode;
        if (status === 404 || status === 410) {
          await supabase.from("push_subscriptions").delete().eq("id", sub.id);
        }
        throw err;
      }
    }),
  );

  return new Response(
    JSON.stringify({ sent: results.filter((r) => r.status === "fulfilled").length, total: results.length }),
    { headers: { "Content-Type": "application/json" } },
  );
});
