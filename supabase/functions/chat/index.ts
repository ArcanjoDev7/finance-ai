import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

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
};

const jsonHeaders = { ...corsHeaders, 'Content-Type': 'application/json; charset=utf-8' };

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

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
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
  if (previous?.status === 'success') return response({ sessionId: previous.chat_session_id, action: previous.result_json, replayed: true });

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
    .insert({ user_id: userId, chat_session_id: sessionId, message_id: userMessage.id, intent: 'pending', input_json: { message: payload.message }, idempotency_key: payload.idempotencyKey, status: 'processing' })
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
    await admin.from('ai_actions').update({ status: 'failed', error_message: 'OPENAI_REQUEST_FAILED' }).eq('id', action.id);
    return response({ error: { code: 'AI_PROVIDER_UNAVAILABLE' } }, 502);
  }

  const modelResult = await openAiResponse.json() as { output_text?: string };
  let parsed: FinanceAction;
  try { parsed = parseModelPayload(modelResult.output_text ?? ''); } catch {
    await admin.from('ai_actions').update({ status: 'failed', error_message: 'INVALID_AI_RESPONSE' }).eq('id', action.id);
    return response({ error: { code: 'INVALID_AI_RESPONSE' } }, 502);
  }

  await admin.from('chat_messages').insert({ user_id: userId, chat_session_id: sessionId, role: 'assistant', content: parsed, structured_data: parsed, model_name: model });
  await admin.from('ai_actions').update({ intent: parsed.intent, result_json: parsed, validated_payload: parsed, confidence: parsed.confidence, status: 'success', processed_at: new Date().toISOString() }).eq('id', action.id);
  await admin.from('chat_sessions').update({ last_message_at: new Date().toISOString() }).eq('id', sessionId);

  return response({ sessionId, action: parsed, replayed: false });
});
