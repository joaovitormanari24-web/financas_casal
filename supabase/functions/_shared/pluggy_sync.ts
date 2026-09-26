// Lógica de sincronização compartilhada entre pluggy-sync-item (chamado
// pelo app, na hora de conectar ou num "sincronizar agora" manual) e
// pluggy-webhook (chamado pela própria Pluggy quando há dado novo).
// Copiado em ambos os deploys — Supabase Edge Functions não compartilham
// arquivos entre funções distintas, cada deploy leva sua própria cópia.
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

const PLUGGY_CLIENT_ID = Deno.env.get("PLUGGY_CLIENT_ID")!;
const PLUGGY_CLIENT_SECRET = Deno.env.get("PLUGGY_CLIENT_SECRET")!;

export async function getPluggyApiKey(): Promise<string> {
  const res = await fetch("https://api.pluggy.ai/auth", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ clientId: PLUGGY_CLIENT_ID, clientSecret: PLUGGY_CLIENT_SECRET }),
  });
  if (!res.ok) throw new Error(`pluggy auth failed: ${res.status} ${await res.text()}`);
  return (await res.json()).apiKey as string;
}

async function pluggyGet(path: string, apiKey: string) {
  const res = await fetch(`https://api.pluggy.ai${path}`, {
    headers: { "X-API-KEY": apiKey },
  });
  if (!res.ok) throw new Error(`pluggy GET ${path} failed: ${res.status} ${await res.text()}`);
  return res.json();
}

/// Busca contas + lançamentos de um Item já vinculado (bank_connections já
/// tem uma linha pra ele) e importa o que for novo. Idempotente — chamado
/// de novo só traz o que ainda não existe (dedup pelo external_id).
export async function syncItem(admin: SupabaseClient, itemId: string) {
  const apiKey = await getPluggyApiKey();
  const item = await pluggyGet(`/items/${itemId}`, apiKey);

  const { data: connection, error: connError } = await admin
    .from("bank_connections")
    .select("id, household_id, member_id")
    .eq("pluggy_item_id", itemId)
    .single();
  if (connError || !connection) {
    throw new Error(`no bank_connection registered for item ${itemId}`);
  }

  const { data: outrosCategory } = await admin
    .from("categories")
    .select("id")
    .is("household_id", null)
    .eq("name", "Outros")
    .single();
  const fallbackCategoryId = outrosCategory?.id;

  const accountsRes = await pluggyGet(`/accounts?itemId=${itemId}`, apiKey);
  const pluggyAccounts = accountsRes.results ?? [];

  let importedCount = 0;

  for (const pAccount of pluggyAccounts) {
    const { data: existingAccount } = await admin
      .from("accounts")
      .select("id")
      .eq("pluggy_account_id", pAccount.id)
      .maybeSingle();

    let accountId: string;
    let isNewAccount = false;

    if (existingAccount) {
      accountId = existingAccount.id;
    } else {
      isNewAccount = true;
      const { data: createdAccount, error: createError } = await admin
        .from("accounts")
        .insert({
          household_id: connection.household_id,
          name: pAccount.name ?? "Conta importada",
          owner_member_id: connection.member_id,
          external_source: "pluggy",
          pluggy_account_id: pAccount.id,
          bank_connection_id: connection.id,
          initial_balance: 0,
        })
        .select("id")
        .single();
      if (createError || !createdAccount) {
        throw new Error(
          `failed to create account for pluggy account ${pAccount.id}: ${createError?.message}`,
        );
      }
      accountId = createdAccount.id;
    }

    let page = 1;
    let totalPages = 1;
    let importedForAccount = 0;
    const fetchedTransactions: Array<{ amount: number; type: string }> = [];

    do {
      const txRes = await pluggyGet(
        `/transactions?accountId=${pAccount.id}&page=${page}&pageSize=500`,
        apiKey,
      );
      const results = txRes.results ?? [];
      totalPages = txRes.totalPages ?? 1;

      for (const t of results) {
        fetchedTransactions.push({ amount: Number(t.amount), type: t.type });
        const isCredit = t.type === "CREDIT";
        const { error: insertError } = await admin.from("transactions").upsert(
          {
            household_id: connection.household_id,
            type: isCredit ? "income" : "expense",
            amount: Math.abs(Number(t.amount)),
            description: t.description ?? "Lançamento importado",
            category_id: fallbackCategoryId,
            date: t.date,
            paid_by_member_id: connection.member_id,
            payment_method: "debit",
            account_id: accountId,
            external_source: "pluggy",
            external_id: t.id,
          },
          { onConflict: "external_id", ignoreDuplicates: true },
        );
        if (!insertError) importedForAccount += 1;
      }
      page += 1;
    } while (page <= totalPages && page <= 20);

    importedCount += importedForAccount;

    if (isNewAccount) {
      const netImported = fetchedTransactions.reduce(
        (sum, t) => sum + (t.type === "CREDIT" ? t.amount : -Math.abs(t.amount)),
        0,
      );
      const reportedBalance = Number(pAccount.balance ?? 0);
      await admin
        .from("accounts")
        .update({ initial_balance: reportedBalance - netImported })
        .eq("id", accountId);
    }
  }

  await admin
    .from("bank_connections")
    .update({ status: item.status ?? "UPDATED", last_synced_at: new Date().toISOString() })
    .eq("id", connection.id);

  return { importedCount, accounts: pluggyAccounts.length };
}
