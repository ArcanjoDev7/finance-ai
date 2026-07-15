import { corsHeaders } from '../_shared/cors.ts';
import { downloadUrl } from '../_shared/download_url.ts';
import { jsonResponse } from '../_shared/http.ts';

Deno.serve((request: Request): Response => {
  const origin = request.headers.get('origin');
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: corsHeaders(origin) });
  if (request.method !== 'GET') return jsonResponse({ code: 'method_not_allowed' }, { origin, status: 405 });
  const url = downloadUrl();
  if (url === null) return jsonResponse({ code: 'download_unavailable' }, { origin, status: 503 });
  return Response.redirect(url, 302);
});
