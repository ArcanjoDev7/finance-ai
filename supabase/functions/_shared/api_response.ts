import { corsHeaders } from './cors.ts';
import type { RequestContext } from './request_context.ts';

export function success(data: unknown, context: RequestContext, origin: string | null, status = 200): Response {
  return Response.json({ success: true, data, meta: { request_id: context.requestId, correlation_id: context.correlationId } }, { status, headers: { ...corsHeaders(origin), 'x-request-id': context.requestId } });
}
export function failure(code: string, message: string, context: RequestContext, origin: string | null, status: number, details?: unknown): Response {
  return Response.json({ success: false, error: { code, message, details }, meta: { request_id: context.requestId, correlation_id: context.correlationId } }, { status, headers: { ...corsHeaders(origin), 'x-request-id': context.requestId } });
}
