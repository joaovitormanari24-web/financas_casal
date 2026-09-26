// Chamado pela própria Pluggy (não pelo app) quando um Item termina de
// atualizar ou há lançamentos novos — assim a sincronização acontece sem
// precisar o usuário abrir o app e apertar "sincronizar agora".
//
// Sem verificação de JWT (a Pluggy não manda um token nosso) — o "pior
// caso" de alguém forjar uma chamada é tentar disparar uma sincronização
// pra um itemId que não é nosso, o que falha ao chamar a API da Pluggy com
// nossas próprias credenciais (ela só devolve dado de Items do nosso app).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { syncItem } from "./sync.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    const payload = await req.json();
    const itemId = payload.itemId ?? payload.item?.id;
    const event = payload.event;

    if (!itemId || (event !== "item/updated" && event !== "transactions/created")) {
      return new Response(JSON.stringify({ ignored: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: connection } = await admin
      .from("bank_connections")
      .select("id")
      .eq("pluggy_item_id", itemId)
      .maybeSingle();

    if (connection) {
      await syncItem(admin, itemId);
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("pluggy webhook error", err);
    // 200 mesmo em erro nosso — evita retry agressivo da Pluggy; o próximo
    // evento ou um "sincronizar agora" manual cobre o que faltar.
    return new Response(JSON.stringify({ received: true, error: String(err) }), {
      headers: { "Content-Type": "application/json" },
    });
  }
});
