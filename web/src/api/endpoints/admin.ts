import { request } from '../client';
import type { AdminUsage, ModerationFlag } from '../types';

/**
 * Admin operations (PRD §6.13).
 *
 * FLAG — every operation here is a server-side STUB returning
 * not_implemented (501), and none declares a response schema in
 * backend/api/openapi.yaml. The types these resolve to are this client's
 * proposal (see api/types.ts), not an agreed contract.
 *
 * The calls are wired anyway so the portal integrates against real error
 * bodies today — the same reason the backend shipped the stubs — and so
 * turning a slice on requires no client change beyond reconciling shapes.
 *
 * Both mutating operations MUST write an AdminAuditLog row server-side; an
 * audit log administrators can silently modify is not an audit log (§6.13).
 */
export const adminApi = {
  usage: (): Promise<AdminUsage> => request<AdminUsage>('/admin/usage'),

  listFlags: (): Promise<ModerationFlag[]> =>
    request<ModerationFlag[]>('/admin/flags'),

  reviewFlag: (id: string, decision: string, note: string): Promise<void> =>
    request<void>(`/admin/flags/${id}/review`, {
      method: 'POST',
      body: { decision, note },
    }),

  setUserLimits: (
    id: string,
    limits: { text_calls_limit: number; image_calls_limit: number },
  ): Promise<void> =>
    request<void>(`/admin/users/${id}/limits`, { method: 'PUT', body: limits }),
};
