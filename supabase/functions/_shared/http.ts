import { corsHeaders } from './cors.ts';

export function jsonResponse(
  body: Record<string, unknown>,
  options: { origin?: string | null; status?: number } = {},
): Response {
  return new Response(JSON.stringify(body), {
    status: options.status ?? 200,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...corsHeaders(options.origin ?? null) },
  });
}
