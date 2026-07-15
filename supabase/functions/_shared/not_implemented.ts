import { jsonResponse } from './http.ts';

export function notImplemented(origin: string | null): Response {
  return jsonResponse(
    { code: 'not_implemented', message: 'This endpoint is reserved for a later delivery phase.' },
    { origin, status: 501 },
  );
}
