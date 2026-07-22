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

function indexedIdempotencyKey(value: string, index: number) {
  if (index === 0) return value;
  const prefix = value.slice(0, -12);
  const suffix = value.slice(-12);
  const next = (BigInt(`0x${suffix}`) + BigInt(index)) & BigInt('0xffffffffffff');
  return `${prefix}${next.toString(16).padStart(12, '0')}`;
}

function parseFinanceAction(value: unknown): FinanceAction {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('A IA não retornou uma ação válida.');
  }
  const candidate = value as Partial<FinanceAction>;
  if (typeof candidate.intent !== 'string' || !candidate.intent.trim()) {
    throw new Error('A IA não retornou um intent válido.');
  }

  const aliases: Record<string, string> = {
    income: 'create_income',
    expense: 'create_expense',
    investment: 'create_investment',
    savings: 'create_investment',
    saving: 'create_investment',
    crypto_purchase: 'create_crypto_purchase',
    crypto_buy: 'create_crypto_purchase',
    crypto_sale: 'create_crypto_sale',
    crypto_sell: 'create_crypto_sale',
    reset: 'reset_account',
    zero_account: 'reset_account',
    clear_account: 'reset_account',
  };
  const rawIntent = candidate.intent.trim().toLowerCase();
  const intent = aliases[rawIntent] ?? rawIntent;
  const allowedIntents = new Set([
    'create_expense',
    'create_income',
    'create_investment',
    'create_crypto_purchase',
    'create_crypto_sale',
    'create_crypto_conversion',
    'reset_account',
    'financial_guidance',
    'needs_clarification',
  ]);
  if (!allowedIntents.has(intent)) throw new Error('Intent não permitido.');

  const amount = typeof candidate.amount === 'number' &&
      Number.isFinite(candidate.amount) && candidate.amount > 0
    ? candidate.amount
    : undefined;
  const confidence = typeof candidate.confidence === 'number' && Number.isFinite(candidate.confidence)
    ? Math.max(0, Math.min(1, candidate.confidence))
    : 0;
  return { ...candidate, intent, amount, confidence } as FinanceAction;
}

function parseModelPayload(content: string): FinanceAction[] {
  const json = content
    .trim()
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/, '');
  const parsed = JSON.parse(json) as unknown;
  const candidates = Array.isArray(parsed)
    ? parsed
    : parsed != null && typeof parsed === 'object' && Array.isArray((parsed as { actions?: unknown }).actions)
      ? (parsed as { actions: unknown[] }).actions
      : [parsed];
  if (candidates.length === 0 || candidates.length > 10) {
    throw new Error('Quantidade de ações inválida.');
  }
  return candidates.map(parseFinanceAction);
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

function parseBrlAmount(value: string) {
  const matches = [...value.matchAll(/(?:r\$\s*)?(\d[\d.,]*)/gi)];
  if (matches.length === 0) return undefined;
  const preferred = [...matches].reverse().find((match) => /r\$/i.test(match[0])) ?? matches.at(-1);
  const raw = preferred?.[1];
  if (!raw) return undefined;
  const hasDot = raw.includes('.');
  const hasComma = raw.includes(',');
  let normalized = raw;
  if (hasDot && hasComma) {
    const decimalSeparator = raw.lastIndexOf('.') > raw.lastIndexOf(',') ? '.' : ',';
    normalized = raw
      .replaceAll(decimalSeparator === '.' ? ',' : '.', '')
      .replace(decimalSeparator, '.');
  } else if (hasDot || hasComma) {
    const separator = hasDot ? '.' : ',';
    const fractionSize = raw.length - raw.lastIndexOf(separator) - 1;
    normalized = fractionSize === 3 ? raw.replaceAll(separator, '') : raw.replace(separator, '.');
  }
  const amount = Number(normalized);
  return Number.isFinite(amount) && amount > 0 ? amount : undefined;
}

function directCompletedPurchase(message: string): FinanceAction | null {
  const text = normalizeText(message);
  if (!/\b(comprei|adquiri|gastei|paguei)\b/.test(text)) return null;
  if (/\b(quanto|como|posso|devo|vou|quero|pretendo)\b/.test(text) || text.includes('?')) return null;
  if (/\b(bitcoin|btc|ethereum|eth|cripto|cdb|lci|lca|tesouro|acao|acoes|etf|fii|fundo)\b/.test(text)) {
    return null;
  }
  const amount = parseBrlAmount(message);
  if (!amount) return null;
  const category = /\b(mercado|supermercado|comida|lanche|restaurante)\b/.test(text)
    ? 'Alimentação'
    : /\b(farmacia|remedio|consulta|medico)\b/.test(text)
      ? 'Saúde'
      : /\b(uber|onibus|combustivel|gasolina|transporte)\b/.test(text)
        ? 'Transporte'
        : /\b(roupa|calcado|sapato|shopping)\b/.test(text)
          ? 'Compras'
          : 'Outros';
  return {
    intent: 'create_expense',
    amount,
    currency: 'BRL',
    category,
    description: message.trim(),
    account: /\b(cartao|credito|fatura)\b/.test(text) ? 'Cartão' : 'Conta principal',
    confidence: 1,
  };
}

function directTaggedCommand(message: string): FinanceAction | null {
  const text = normalizeText(message).trim();
  const match = text.match(/^@(cripto|crypto|despesa|dispesa|gasto|saida|cartao|receita|entrada|salario|investimento|investir)\b\s*(.*)$/);
  if (!match) return null;

  const [, rawTag, details] = match;
  const amount = parseBrlAmount(details);
  if (!amount) {
    return {
      intent: 'needs_clarification',
      answer: `Informe o valor no mesmo comando. Exemplo: @${rawTag} Bitcoin 100`,
      confidence: 1,
    };
  }

  const description = details
    .replace(/(?:r\$\s*)?\d[\d.,]*/gi, '')
    .replace(/\b(por|de|em|no|na|do|da|comprei|compra|vendi|venda|recebi|gastei|paguei|investi)\b/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const common = {
    amount,
    currency: 'BRL',
    description: description || message.trim(),
    confidence: 1,
  };

  if (['despesa', 'dispesa', 'gasto', 'saida', 'cartao'].includes(rawTag)) {
    const category = /\b(mercado|supermercado|comida|lanche|restaurante)\b/.test(details)
      ? 'Alimentação'
      : /\b(farmacia|remedio|consulta|medico)\b/.test(details)
        ? 'Saúde'
        : /\b(uber|onibus|combustivel|gasolina|transporte)\b/.test(details)
          ? 'Transporte'
          : 'Outros';
    return {
      ...common,
      intent: 'create_expense',
      category,
      account: rawTag === 'cartao' || /\b(cartao|credito|fatura)\b/.test(details)
        ? 'Cartão'
        : 'Conta principal',
    };
  }

  if (['receita', 'entrada', 'salario'].includes(rawTag)) {
    return { ...common, intent: 'create_income', category: 'Receitas' };
  }

  if (rawTag === 'investimento' || rawTag === 'investir') {
    return {
      ...common,
      intent: 'create_investment',
      investment: description || 'Investimento',
      bank: 'Carteira principal',
    };
  }

  const investment = /\b(ethereum|eth)\b/.test(details)
    ? 'Ethereum'
    : /\b(bitcoin|btc)\b/.test(details)
      ? 'Bitcoin'
      : description || 'Cripto';
  const intent = /\b(vendi|venda|saquei|resgatei)\b/.test(details)
    ? 'create_crypto_sale'
    : /\b(converti|conversao|troquei)\b/.test(details)
      ? 'create_crypto_conversion'
      : 'create_crypto_purchase';
  return { ...common, intent, investment };
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
  if (!transactionType || !action.amount || action.amount <= 0 || action.confidence < 0.65) return null;

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
  } else {
    const { data: ownedSession, error } = await admin
      .from('chat_sessions')
      .select('id')
      .eq('id', sessionId)
      .eq('user_id', userId)
      .is('deleted_at', null)
      .maybeSingle();
    if (error || !ownedSession) {
      return response({ error: { code: 'SESSION_NOT_FOUND' } }, 404);
    }
  }

  const { data: recentMessages } = await admin
    .from('chat_messages')
    .select('role,content')
    .eq('user_id', userId)
    .eq('chat_session_id', sessionId)
    .is('deleted_at', null)
    .order('created_at', { ascending: false })
    .limit(8);
  const conversationHistory = (recentMessages ?? [])
    .reverse()
    .map((item) => {
      const content = item.content as Record<string, unknown> | null;
      const value = content?.text ?? content?.answer ?? content?.description ?? content?.intent;
      return typeof value === 'string' ? `${item.role}: ${value}` : null;
    })
    .filter((item): item is string => item != null)
    .join('\n');

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

  const directAction = directTaggedCommand(payload.message) ?? directCompletedPurchase(payload.message);
  if (directAction) {
    const occurredDate = explicitOccurredDate(payload.message);
    if (occurredDate) directAction.date = occurredDate;
    try {
      const transactionId = await persistFinancialAction(
        admin,
        userId,
        directAction,
        payload.idempotencyKey,
      );
      if (transactionTypeFor(directAction.intent) && !transactionId) {
        throw new Error('TRANSACTION_CREATION_FAILED');
      }
      if (transactionId) directAction.savedTransactionId = transactionId;
    } catch {
      await admin.from('ai_actions').update({ status: 'failed' }).eq('id', action.id);
      return response({ error: { code: 'ACTION_PERSISTENCE_FAILED' } }, 500);
    }
    await admin.from('chat_messages').insert({
      user_id: userId,
      chat_session_id: sessionId,
      role: 'assistant',
      content: directAction,
      model_name: 'deterministic-command-parser',
    });
    await admin.from('ai_actions').update({
      intent: directAction.intent,
      result_json: directAction,
      status: 'processed',
      processed_at: new Date().toISOString(),
    }).eq('id', action.id);
    await admin.from('chat_sessions').update({ last_message_at: new Date().toISOString() }).eq('id', sessionId);
    return response({ sessionId, action: directAction, replayed: false, source: 'deterministic' });
  }

  const instruction = `Você é o assistente financeiro do Finance AI para usuários brasileiros.
Responda exclusivamente com um objeto JSON válido, sem markdown ou texto fora do JSON.

Intents permitidos:
- create_expense: gasto, compra, pagamento ou conta que o usuário afirma que realizou.
- create_income: salário, venda, reembolso ou dinheiro que o usuário afirma que recebeu.
- create_investment: aporte em renda fixa, ações, ETF, FII, fundos ou previdência.
- create_crypto_purchase, create_crypto_sale ou create_crypto_conversion.
- reset_account: somente pedido explícito para zerar, limpar ou reiniciar a conta.
- financial_guidance: pergunta, explicação, comparação, planejamento ou orientação financeira geral.
- needs_clarification: falta informação essencial ou a frase é ambígua.

Regras:
1. Perguntas nunca criam lançamentos. Use financial_guidance e escreva a resposta em answer.
2. Para criar um lançamento, o fato deve estar concluído e o valor precisa ter sido informado. Se faltar valor, use needs_clarification e pergunte em answer.
3. Não transforme planos futuros, exemplos ou hipóteses em lançamentos.
4. Entenda linguagem informal, abreviações, erros de digitação e valores brasileiros como "1.250,90", "50 conto" e "2k".
5. Para cartão, use account="Cartão" apenas se houver menção explícita a cartão, crédito ou fatura; caso contrário use "Conta principal".
6. Responda em português claro. Em orientações, seja educativo, prudente e não prometa retornos. Se a pergunta exigir dados atuais não fornecidos, explique essa limitação.
7. Use o histórico apenas para resolver referências como "isso" ou "e ontem". Nunca reutilize silenciosamente um valor antigo em um novo lançamento.
8. Extraia quando aplicável: intent, amount numérico em reais, currency, category, description, date (YYYY-MM-DD), account, quantity, investment, bank, wallet, answer e confidence (0 a 1). Nunca invente valores.
9. Se a mensagem contiver duas ou mais movimentações, devolva {"actions":[...]} com uma ação separada para cada movimentação. Nunca some valores nem descarte uma delas.
10. "Guardar", "poupar", "separar para reserva" ou colocar dinheiro em cofrinho/caixinha é create_investment; use o nome do destino em investment.

Formato para uma ação: {"intent":"...","amount":0,"description":"...","confidence":0.0}.
Formato para várias: {"actions":[{"intent":"..."},{"intent":"..."}]}.

Data atual do servidor: ${new Date().toISOString()}.
Histórico recente da mesma conta e conversa:
${conversationHistory || '(sem histórico)'}

Mensagem atual: ${payload.message}`;
  // Use the current structured-data model first, retaining stable fallbacks for
  // environments whose API key has not received the newest model yet.
  const candidateModels = [...new Set([
    configuredModel ?? 'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash-lite',
  ])];
  let model = candidateModels[0];
  let geminiResponse: Response | undefined;
  for (const candidate of candidateModels) {
    const result = await fetch(`https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(candidate)}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': geminiKey },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: instruction }]}],
        generationConfig: {
          responseMimeType: 'application/json',
          maxOutputTokens: 700,
        },
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
  let parsedActions: FinanceAction[];
  try { parsedActions = parseModelPayload(modelText); } catch {
    await admin.from('ai_actions').update({ status: 'failed' }).eq('id', action.id);
    return response({ error: { code: 'INVALID_AI_RESPONSE' } }, 502);
  }

  // A model does not know the user's current date. Preserve only a date that
  // was actually mentioned (including today/yesterday), otherwise let the
  // persistence layer use the server timestamp instead of an invented date.
  const occurredDate = explicitOccurredDate(payload.message);
  parsedActions = parsedActions.map((parsed) => {
    if (occurredDate) parsed.date = occurredDate;
    else delete parsed.date;
    if (transactionTypeFor(parsed.intent) && (!parsed.amount || parsed.confidence < 0.65)) {
      return {
        intent: 'needs_clarification',
        answer: !parsed.amount
          ? 'Qual foi o valor dessa movimentação?'
          : 'Não entendi a movimentação com segurança. Pode descrevê-la de outra forma?',
        confidence: parsed.confidence,
      };
    }
    return parsed;
  });

  try {
    for (let index = 0; index < parsedActions.length; index += 1) {
      const parsed = parsedActions[index];
      const transactionId = await persistFinancialAction(
        admin,
        userId,
        parsed,
        indexedIdempotencyKey(payload.idempotencyKey, index),
      );
      if (transactionId) parsed.savedTransactionId = transactionId;
    }
  } catch (error) {
    await admin.from('ai_actions').update({ status: 'failed' }).eq('id', action.id);
    return response({ error: { code: 'ACTION_PERSISTENCE_FAILED' } }, 500);
  }

  const result = parsedActions.length === 1
    ? parsedActions[0]
    : {
      intent: 'multiple_actions',
      actions: parsedActions,
      confidence: Math.min(...parsedActions.map((item) => item.confidence)),
    };
  await admin.from('chat_messages').insert({ user_id: userId, chat_session_id: sessionId, role: 'assistant', content: result, model_name: model });
  await admin.from('ai_actions').update({ intent: result.intent, result_json: result, status: 'processed', processed_at: new Date().toISOString() }).eq('id', action.id);
  await admin.from('chat_sessions').update({ last_message_at: new Date().toISOString() }).eq('id', sessionId);

  return response({ sessionId, action: result, replayed: false });
});
