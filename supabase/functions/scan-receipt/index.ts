// Lê um comprovante/recibo (foto) via IA com visão (Claude) e devolve os
// dados já estruturados pra pré-preencher o formulário de lançamento —
// "lançamento rápido": tira a foto, revisa o que a IA leu, confirma.
//
// A leitura das categorias usa o client escopado pelo JWT de quem chama (não
// service role) — o RLS de `categories` já garante que só vêm categorias do
// household do próprio usuário, sem precisar checar membership à mão aqui.
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;

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

  try {
    const { image, mediaType, householdId } = await req.json();
    if (!image || !householdId) {
      return jsonResponse({ error: "missing_image_or_household" }, 400);
    }

    const { data: categories } = await callerClient
      .from("categories")
      .select("name")
      .or(`household_id.is.null,household_id.eq.${householdId}`);
    const categoryNames = (categories ?? []).map((c) => c.name as string);

    const prompt = `Você lê comprovantes de compra/recibos brasileiros a partir de uma foto e devolve SOMENTE um JSON válido, sem markdown e sem texto adicional, neste formato exato:
{"amount": <número em reais, com ponto decimal, sem símbolo>, "description": "<nome do estabelecimento ou item principal, curto>", "type": "expense" ou "income", "category": "<uma destas categorias, exatamente como escrita, ou null se nenhuma encaixar>", "date": "<AAAA-MM-DD, ou null se a data não estiver visível>"}

Categorias disponíveis: ${categoryNames.join(", ")}

A maioria dos comprovantes é despesa ("expense"). Só use "income" se for claramente um recibo de recebimento. Se não conseguir ler o valor com confiança, devolva {"error": "não foi possível ler o comprovante"} em vez do formato acima.`;

    const aiRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 300,
        messages: [
          {
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: mediaType ?? "image/jpeg", data: image } },
              { type: "text", text: prompt },
            ],
          },
        ],
      }),
    });

    if (!aiRes.ok) {
      const errText = await aiRes.text();
      console.error("anthropic error", aiRes.status, errText);
      return jsonResponse({ error: "ai_request_failed" }, 502);
    }

    const aiJson = await aiRes.json();
    const rawText = aiJson?.content?.[0]?.text as string | undefined;
    if (!rawText) {
      return jsonResponse({ error: "ai_empty_response" }, 502);
    }

    // O modelo às vezes envolve o JSON em ```json ... ``` mesmo pedindo pra
    // não fazer isso — remove antes de parsear.
    const cleaned = rawText.trim().replace(/^```json\s*|^```\s*|```$/g, "").trim();

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(cleaned);
    } catch {
      console.error("failed to parse AI JSON", cleaned);
      return jsonResponse({ error: "ai_invalid_json" }, 502);
    }

    if (parsed.error) {
      return jsonResponse({ error: String(parsed.error) }, 422);
    }

    return jsonResponse({ success: true, ...parsed });
  } catch (err) {
    console.error("scan-receipt error", err);
    const message = err instanceof Error ? err.message : String(err);
    return jsonResponse({ error: message }, 500);
  }
});
