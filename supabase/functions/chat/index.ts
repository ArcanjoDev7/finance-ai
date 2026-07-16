import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type ChatRequest = { message?: unknown; sessionId?: unknown; idempotencyKey?: unknown; operation?: unknown };

type FinanceAction = {
  intent: string;
  amount?: number;
  answer?: string;
  currency?: string;
  category?: string;
  description?: string;
  date?: string;
  account?: string;
  quantity?: number;
  investment?: string;
  bank?: string;
  wallet?: string;
  confidence: number;
  savedTransactionId?: string;
};

const jsonHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-request-id',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
};

function response(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function isUuid(value: unknown): value is string {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function parseModelPayload(content: string): FinanceAction {
  const candidate = JSON.parse(content) as Partial<FinanceAction>;
  if (typeof candidate.intent !== 'string' || !candidate.intent.trim()) {
    throw new Error('A IA não retornou um intent válido.');
  }

  const aliases: Record<string, string> = {
    income: 'create_income',
    expense: 'create_expense',
    investment: 'create_investment',
    crypto_purchase: 'create_crypto_purchase',
    crypto_buy: 'create_crypto_purchase',
    crypto_sale: 'create_crypto_sale',
    crypto_sell: 'create_crypto_sale',
    reset: 'reset_account',
    zero_account: 'reset_account',
    clear_account: 'reset_account',
  };
  const rawIntent = candidate.intent.trim().toLowerCase();
  return {
    ...candidate,
    intent: aliases[rawIntent] ?? rawIntent,
    confidence: typeof candidate.confidence === 'number' ? candidate.confidence : 0,
  } as FinanceAction;
}

function transactionTypeFor(intent: string) {
  switch (intent) {
    case 'create_expense': return 'expense';
    case 'create_income': return 'income';
    case 'create_investment': return 'investment';
    case 'create_crypto_purchase': return 'crypto_buy';
    case 'create_crypto_sale': return 'crypto_sell';
    // A conversion has an outgoing leg; the receiving asset will be modeled in
    // the dedicated crypto ledger once that schema is deployed.
    case 'create_crypto_conversion': return 'crypto_sell';
    default: return null;
  }
}

function normalizeText(value: string) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

function isoDate(value: Date) {
  return value.toISOString().slice(0, 10);
}

function validDate(year: number, month: number, day: number) {
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
}

function explicitOccurredDate(message: string, now = new Date()) {
  const normalized = normalizeText(message);
  if (/\bhoje\b/.test(normalized)) return isoDate(now);
  if (/\bontem\b/.test(normalized)) {
    const yesterday = new Date(now);
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    return isoDate(yesterday);
  }

  const isoMatch = normalized.match(/\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b/);
  if (isoMatch) {
    const [, yearText, monthText, dayText] = isoMatch;
    const year = Number(yearText);
    const month = Number(monthText);
    const day = Number(dayText);
    if (validDate(year, month, day)) return `${yearText}-${monthText.padStart(2, '0')}-${dayText.padStart(2, '0')}`;
  }

  const brMatch = normalized.match(/\b(\d{1,2})[/. -](\d{1,2})(?:[/. -](20\d{2}))?\b/);
  if (brMatch) {
    const [, dayText, monthText, yearText] = brMatch;
    const year = yearText == null ? now.getUTCFullYear() : Number(yearText);
    const month = Number(monthText);
    const day = Number(dayText);
    if (validDate(year, month, day)) return `${year}-${monthText.padStart(2, '0')}-${dayText.padStart(2, '0')}`;
  }

  const namedMatch = normalized.match(/\b(\d{1,2})\s+de\s+(janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)(?:\s+de\s+(20\d{2}))?\b/);
  if (namedMatch) {
    const months: Record<string, number> = {
      janeiro: 1, fevereiro: 2, marco: 3, abril: 4, maio: 5, junho: 6,
      julho: 7, agosto: 8, setembro: 9, outubro: 10, novembro: 11, dezembro: 12,
    };
    const [, dayText, monthName, yearText] = namedMatch;
    const year = yearText == null ? now.getUTCFullYear() : Number(yearText);
    const month = months[monthName];
    const day = Number(dayText);
    if (month != null && validDate(year, month, day)) return `${year}-${String(month).padStart(2, '0')}-${dayText.padStart(2, '0')}`;
  }

  return undefined;
}

function formatBrlMinor(value: number) {
  const sign = value < 0 ? '-' : '';
  const [integer, decimal] = Math.abs(Math.round(value)).toString().padStart(3, '0').replace(/(\d{2})$/, '.$1').split('.');
  return `${sign}R$ ${integer.replace(/\B(?=(\d{3})+(?!\d))/g, '.')},${decimal}`;
}

function sumMinor(rows: Array<{ amount_minor: number | string }>) {
  return rows.reduce((total, row) => total + Number(row.amount_minor ?? 0), 0);
}

async function directQuery(
  admin: ReturnType<typeof createClient>,
  userId: string,
  message: string,
): Promise<FinanceAction | null> {
  const text = normalizeText(message);
  const isQuestion = /\b(quanto|qual|quais|mostre|ver|resumo|saldo|patrimonio)\b/.test(text);
  if (!isQuestion) return null;

  const now = new Date();
  const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const nextMonthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1));

  if (/\b(gastei|gasto|despesa|despesas)\b/.test(text) && /\b(mes|mensal)\b/.test(text)) {
    const { data, error } = await admin
      .from('transactions')
      .select('amount_minor')
      .eq('user_id', userId)
      .eq('transaction_type', 'expense')
      .eq('status', 'paid')
      .is('deleted_at', null)
      .gte('occurred_at', monthStart.toISOString())
      .lt('occurred_at', nextMonthStart.toISOString());
    if (error) throw new Error('QUERY_FAILED');
    const amountMinor = sumMinor(data ?? []);
    return {
      intent: 'query_month_expenses',
      amount: amountMinor / 100,
      answer: `Neste mês, suas despesas registradas somam ${formatBrlMinor(amountMinor)}.`,
      confidence: 1,
    };
  }

  if (/\b(bitcoin|btc|ethereum|eth|cripto|criptomoeda)\b/.test(text) && /\b(tenho|possuo|saldo|quanto)\b/.test(text)) {
    const asset = text.includes('bitcoin') || text.includes('btc')
      ? 'Bitcoin'
      : text.includes('ethereum') || text.includes('eth')
        ? 'Ethereum'
        : null;
    let query = admin
      .from('transactions')
      .select('amount_minor,transaction_type,metadata')
      .eq('user_id', userId)
      .eq('status', 'paid')
      .is('deleted_at', null)
      .in('transaction_type', ['crypto_buy', 'crypto_sell']);
    if (asset) query = query.ilike('metadata->>investment', `%${asset}%`);
    const { data, error } = await query;
    if (error) throw new Error('QUERY_FAILED');
    const netMinor = (data ?? []).reduce(
      (total, row) => total + (row.transaction_type === 'crypto_sell' ? -1 : 1) * Number(row.amount_minor ?? 0),
      0,
    );
    const label = asset ?? 'criptoativos';
    return {
      intent: 'query_crypto_position',
      amount: netMinor / 100,
      answer: `Seu aporte líquido registrado em ${label} é ${formatBrlMinor(netMinor)}. O valor de mercado em tempo real ainda não está conectado.`,
      confidence: 1,
    };
  }

  if (/\b(investido|investimento|investimentos|cdb|lci|lca|tesouro|acoes|etf|fii)\b/.test(text)) {
    const { data, error } = await admin
      .from('transactions')
      .select('amount_minor')
      .eq('user_id', userId)
      .eq('transaction_type', 'investment')
      .eq('status', 'paid')
      .is('deleted_at', null);
    if (error) throw new Error('QUERY_FAILED');
    const amountMinor = sumMinor(data ?? []);
    return {
      intent: 'query_investments',
      amount: amountMinor / 100,
      answer: `Você tem ${formatBrlMinor(amountMinor)} registrados em renda fixa e investimentos.`,
      confidence: 1,
    };
  }

  if (/\b(saldo|patrimonio|resumo)\b/.test(text) || /\bquanto\b.*\btenho\b/.test(text)) {
    const { data, error } = await admin
      .from('transactions')
      .select('amount_minor,transaction_type')
      .eq('user_id', userId)
      .eq('status', 'paid')
      .is('deleted_at', null);
    if (error) throw new Error('QUERY_FAILED');
    const totals = (data ?? []).reduce(
      (current, row) => {
        const amount = Number(row.amount_minor ?? 0);
        if (row.transaction_type === 'income' || row.transaction_type === 'refund' || row.transaction_type === 'crypto_sell') current.income += amount;
        if (row.transaction_type === 'expense') current.expense += amount;
        if (row.transaction_type === 'investment') current.investments += amount;
        if (row.transaction_type === 'crypto_buy') current.crypto += amount;
        return current;
      },
      { income: 0, expense: 0, investments: 0, crypto: 0 },
    );
    const availableMinor = totals.income - totals.expense - totals.investments - totals.crypto;
    const netWorthMinor = availableMinor + totals.investments + totals.crypto;
    return {
      intent: 'query_summary',
      amount: netWorthMinor / 100,
      answer: `Saldo disponível: ${formatBrlMinor(availableMinor)}. Patrimônio registrado: ${formatBrlMinor(netWorthMinor)}.`,
      confidence: 1,
    };
  }

  return null;
}

async function persistFinancialAction(admin: ReturnType<typeof createClient>, userId: string, action: FinanceAction, idempotencyKey: string) {
  const transactionType = transactionTypeFor(action.intent);
  if (!transactionType || !action.amount || action.amount <= 0) return null;

  let { data: wallet } = await admin.from('wallets').select('id').eq('user_id', userId).eq('is_archived', false).order('created_at').limit(1).maybeSingle();
  if (!wallet) {
    const { data, error } = await admin.from('wallets').insert({ user_id: userId, name: 'Carteira principal', currency_code: action.currency ?? 'BRL' }).select('id').single();
    if (error) throw new Error('WALLET_CREATION_FAILED');
    wallet = data;
  }
  let { data: account } = await admin.from('accounts').select('id').eq('user_id', userId).eq('wallet_id', wallet.id).order('created_at').limit(1).maybeSingle();
  if (!account) {
    const { data, error } = await admin.from('accounts').insert({ user_id: userId, wallet_id: wallet.id, name: 'Conta principal', account_type: transactionType.startsWith('crypto_') ? 'crypto_wallet' : transactionType === 'investment' ? 'brokerage' : 'checking', currency_code: action.currency ?? 'BRL' }).select('id').single();
    if (error) throw new Error('ACCOUNT_CREATION_FAILED');
    account = data;
  }
  const { data: transaction, error } = await admin.from('transactions').insert({
    user_id: userId,
    wallet_id: wallet.id,
    account_id: account.id,
    amount_minor: Math.round(action.amount * 100),
    currency_code: action.currency ?? 'BRL',
    description: action.description ?? action.investment ?? action.intent,
    transaction_type: transactionType,
    occurred_at: action.date ? `${action.date}T12:00:00.000Z` : new Date().toISOString(),
    idempotency_key: idempotencyKey,
    metadata: { source: 'ai', category: action.category, investment: action.investment, quantity: action.quantity, account: action.account },
  }).select('id').single();
  if (error) throw new Error('TRANSACTION_CREATION_FAILED');
  return transaction.id as string;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: jsonHeaders });
  if (request.method !== 'POST') return response({ error: { code: 'METHOD_NOT_ALLOWED' } }, 405);

  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return response({ error: { code: 'UNAUTHORIZED' } }, 401);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const geminiKey = Deno.env.get('GEMINI_API_KEY');
  const configuredModel = Deno.env.get('GEMINI_MODEL');
  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey || !geminiKey) {
    return response({ error: { code: 'AI_CONFIGURATION_REQUIRED' } }, 503);
  }

  let payload: ChatRequest;
  try { payload = await request.json() as ChatRequest; } catch { return response({ error: { code: 'INVALID_JSON' } }, 400); }
  if (typeof payload.message !== 'string' || !payload.message.trim() || payload.message.length > 2_000) {
    return response({ error: { code: 'INVALID_MESSAGE' } }, 400);
  }
  if (!isUuid(payload.idempotencyKey)) return response({ error: { code: 'INVALID_IDEMPOTENCY_KEY' } }, 400);
  if (payload.sessionId != null && !isUuid(payload.sessionId)) return response({ error: { code: 'INVALID_SESSION_ID' } }, 400);
  if (payload.operation != null && payload.operation !== 'reset_account') return response({ error: { code: 'INVALID_OPERATION' } }, 400);

  const userClient = createClient(supabaseUrl, supabaseAnonKey, { global: { headers: { Authorization: authorization } } });
  const { data: userResult, error: userError } = await userClient.auth.getUser();
  if (userError || !userResult.user) return response({ error: { code: 'UNAUTHORIZED' } }, 401);
  const userId = userResult.user.id;
  const admin = createClient(supabaseUrl, serviceRoleKey);

  // Resetting is an explicit, confirmed operation. Active values disappear, but
  // soft-deleted records remain available for an audited recovery process.
  if (payload.operation === 'reset_account') {
    const { data, error } = await admin
      .from('transactions')
      .update({ deleted_at: new Date().toISOString() })
      .eq('user_id', userId)
      .is('deleted_at', null)
      .select('id');
    if (error) return response({ error: { code: 'ACCOUNT_RESET_FAILED' } }, 500);
    return response({ action: { intent: 'reset_account', clearedTransactions: data?.length ?? 0, confidence: 1 }, replayed: false });
  }

  try {
    const queryAction = await directQuery(admin, userId, payload.message);
    if (queryAction) return response({ action: queryAction, replayed: false, source: 'database' });
  } catch {
    return response({ error: { code: 'QUERY_FAILED' } }, 500);
  }

  const { data: previous } = await admin
    .from('ai_actions')
    .select('result_json,status,chat_session_id')
    .eq('user_id', userId)
    .eq('idempotency_key', payload.idempotencyKey)
    .maybeSingle();
  if (previous?.status === 'processed') return response({ sessionId: previous.chat_session_id, action: previous.result_json, replayed: true });

  let sessionId = payload.sessionId as string | undefined;
  if (!sessionId) {
    const { data, error } = await admin.from('chat_sessions').insert({ user_id: userId, title: payload.message.slice(0, 80) }).select('id').single();
    if (error) return response({ error: { code: 'SESSION_CREATION_FAILED' } }, 500);
    sessionId = data.id;
  }

  const { data: userMessage, error: messageError } = await admin
    .from('chat_messages')
    .insert({ user_id: userId, chat_session_id: sessionId, role: 'user', content: { text: payload.message } })
    .select('id')
    .single();
  if (messageError) return response({ error: { code: 'MESSAGE_CREATION_FAILED' } }, 500);

  const { data: action, error: actionError } = await admin
    .from('ai_actions')
    .insert({ user_id: userId, chat_session_id: sessionId, intent: 'pending', input_json: { message: payload.message, message_id: userMessage.id }, idempotency_key: payload.idempotencyKey, status: 'received' })
    .select('id')
    .single();
  if (actionError) return response({ error: { code: 'ACTION_CREATION_FAILED' } }, 500);

  const instruction = 'Você é o parser do Finance AI. Responda exclusivamente um objeto JSON válido, sem markdown e sem texto extra. Intents permitidos: create_expense, create_income, create_investment, create_crypto_purchase, create_crypto_sale, create_crypto_conversion, reset_account e query_*. Use create_income para salário ou dinheiro recebido; use create_expense para gastos e pagamentos. Para cartão, preencha account como Cartão somente quando a pessoa mencionar cartão, fatura ou crédito explicitamente; em qualquer outro gasto, use Conta principal. Se a pessoa pedir para zerar, limpar ou reiniciar a conta, use reset_account sem amount. Extraia intent, amount, currency, category, description, date (YYYY-MM-DD), account, quantity, investment, bank, wallet e confidence (0 a 1). Nunca invente valores.';
  // Listing every model is a second network call on every prompt. A low-latency
  // Lite model is called directly, with a single fallback for free-tier outages.
  const candidateModels = [...new Set([configuredModel ?? 'gemini-3.1-flash-lite', 'gemini-2.5-flash-lite'])];
  let model = candidateModels[0];
  let geminiResponse: Response | undefined;
  for (const candidate of candidateModels) {
    const result = await fetch(`https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(candidate)}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': geminiKey },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: `${instruction}\n\nComando do usuário: ${payload.message}` }]}],
        generationConfig: { temperature: 0.1, maxOutputTokens: 250 },
      }),
    });
    geminiResponse = result;
    model = candidate;
    if (result.ok || (result.status !== 404 && result.status !== 429 && result.status !== 503)) break;
  }
  if (!geminiResponse) return response({ error: { code: 'AI_PROVIDER_UNAVAILABLE' } }, 502);
  if (!geminiResponse.ok) {
    await admin.from('ai_actions').update({ status: 'failed' }).eq('id', action.id);
    const upstream = await geminiResponse.json().catch(() => null) as { error?: { status?: unknown; code?: unknown; message?: unknown } } | null;
    const providerCode = typeof upstream?.error?.status === 'string'
      ? upstream.error.status
      : typeof upstream?.error?.code === 'number' ? `HTTP_${upstream.error.code}` : 'unknown_error';
    console.error('Gemini request rejected', { status: geminiResponse.status, providerCode });
    const providerMessage = typeof upstream?.error?.message === 'string' ? upstream.error.message.slice(0, 280) : undefined;
    return response({ error: { code: 'AI_PROVIDER_UNAVAILABLE', providerStatus: geminiResponse.status, providerCode, providerMessage, providerModels: candidateModels, provider: 'gemini' } }, 502);
  }

  const modelResult = await geminiResponse.json() as { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> };
  const modelText = modelResult.candidates?.[0]?.content?.parts?.map((part) => part.text ?? '').join('') ?? '';
  let parsed: FinanceAction;
  try { parsed = parseModelPayload(modelText); } catch {
    await admin.from('ai_actions').update({ status: 'failed' }).eq('id', action.id);
    return response({ error: { code: 'INVALID_AI_RESPONSE' } }, 502);
  }

  // A model does not know the user's current date. Preserve only a date that
  // was actually mentioned (including today/yesterday), otherwise let the
  // persistence layer use the server timestamp instead of an invented date.
  const occurredDate = explicitOccurredDate(payload.message);
  if (occurredDate) parsed.date = occurredDate;
  else delete parsed.date;

  try {
    const transactionId = await persistFinancialAction(admin, userId, parsed, payload.idempotencyKey);
    if (transactionId) parsed.savedTransactionId = transactionId;
  } catch (error) {
    await admin.from('ai_actions').update({ status: 'failed' }).eq('id', action.id);
    return response({ error: { code: 'ACTION_PERSISTENCE_FAILED' } }, 500);
  }

  await admin.from('chat_messages').insert({ user_id: userId, chat_session_id: sessionId, role: 'assistant', content: parsed, model_name: model });
  await admin.from('ai_actions').update({ intent: parsed.intent, result_json: parsed, status: 'processed', processed_at: new Date().toISOString() }).eq('id', action.id);
  await admin.from('chat_sessions').update({ last_message_at: new Date().toISOString() }).eq('id', sessionId);

  return response({ sessionId, action: parsed, replayed: false });
});
