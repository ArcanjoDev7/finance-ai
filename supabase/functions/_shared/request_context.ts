export interface RequestContext { requestId: string; correlationId: string; startedAt: number; }

export function requestContext(request: Request): RequestContext {
  const requestId = crypto.randomUUID();
  return { requestId, correlationId: request.headers.get('x-correlation-id') ?? requestId, startedAt: Date.now() };
}
