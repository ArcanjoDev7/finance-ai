import { corsHeaders } from '../_shared/cors.ts';
import { jsonResponse } from '../_shared/http.ts';

Deno.serve((request: Request): Response => {
  const origin = request.headers.get('origin');
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }
  if (request.method !== 'GET') {
    return jsonResponse({ code: 'method_not_allowed' }, { origin, status: 405 });
  }
  return jsonResponse({
    status: 'ok',
    version: '1.0.0',
    environment: Deno.env.get('ENVIRONMENT') ?? 'development',
    timestamp: new Date().toISOString(),
  }, { origin });
});
