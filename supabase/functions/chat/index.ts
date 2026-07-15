import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

type ChatRequest = { message?: unknown; sessionId?: unknown; idempotencyKey?: unknown };

type FinanceAction = {
  intent: string;
  amount?: number;
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

  return {
    ...candidate,
    intent: candidate.intent.trim(),
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
    case 'create_crypto_conversion': return 'crypto_conversion';
    default: return null;
  }
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
    metadata: { source: 'ai', category: action.category, investment: action.investment, quantity: action.quantity },
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
  const openAiKey = Deno.env.get('OPENAI_API_KEY');
  const model = Deno.env.get('OPENAI_MODEL');
  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey || !openAiKey || !model) {
    return response({ error: { code: 'AI_CONFIGURATION_REQUIRED' } }, 503);
  }

  let payload: ChatRequest;
  try { payload = await request.json() as ChatRequest; } catch { return response({ error: { code: 'INVALID_JSON' } }, 400); }
  if (typeof payload.message !== 'string' || !payload.message.trim() || payload.message.length > 2_000) {
    return response({ error: { code: 'INVALID_MESSAGE' } }, 400);
  }
  if (!isUuid(payload.idempotencyKey)) return response({ error: { code: 'INVALID_IDEMPOTENCY_KEY' } }, 400);
  if (payload.sessionId != null && !isUuid(payload.sessionId)) return response({ error: { code: 'INVALID_SESSION_ID' } }, 400);

  const userClient = createClient(supabaseUrl, supabaseAnonKey, { global: { headers: { Authorization: authorization } } });
  const { data: userResult, error: userError } = await userClient.auth.getUser();
  if (userError || !userResult.user) return response({ error: { code: 'UNAUTHORIZED' } }, 401);
  const userId = userResult.user.id;
  const admin = createClient(supabaseUrl, serviceRoleKey);

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

  const instruction = 'Você é o parser do Finance AI. Responda exclusivamente um objeto JSON válido, sem markdown e sem texto extra. Extraia intent, amount, currency, category, description, date (YYYY-MM-DD), account, quantity, investment, bank, wallet e confidence (0 a 1). Para perguntas, use um intent query_*. Nunca invente valores.';
  const openAiResponse = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: { Authorization: `Bearer ${openAiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model, input: [{ role: 'system', content: instruction }, { role: 'user', content: payload.message }], text: { format: { type: 'json_object' } } }),
  });
  if (!openAiResponse.ok) {
    await admin.from('ai_actions').update({ status: 'failed' }).eq('id', action.id);
    const upstream = await openAiResponse.json().catch(() => null) as { error?: { code?: unknown; type?: unknown } } | null;
    const providerCode = typeof upstream?.error?.code === 'string'
      ? upstream.error.code
      : typeof upstream?.error?.type === 'string' ? upstream.error.type : 'unknown_error';
    console.error('OpenAI request rejected', { status: openAiResponse.status, providerCode });
    return response({ error: { code: 'AI_PROVIDER_UNAVAILABLE', providerStatus: openAiResponse.status, providerCode } }, 502);
  }

  const modelResult = await openAiResponse.json() as { output_text?: string };
  let parsed: FinanceAction;
  try { parsed = parseModelPayload(modelResult.output_text ?? ''); } catch {
    await admin.from('ai_actions').update({ status: 'failed' }).eq('id', action.id);
    return response({ error: { code: 'INVALID_AI_RESPONSE' } }, 502);
  }

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
