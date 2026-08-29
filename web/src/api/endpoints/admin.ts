import { request } from '../client';
import type {
  AdminUsage,
  ModerationFlag,
  ModerationFlagList,
  SetUserLimitsRequest,
  UserLimits,
} from '../types';

/**
 * Admin operations (PRD §6.13). All require the admin role — the server gates
 * with AuthRequired + AdminOnly and returns 403 otherwise. The two mutating
 * calls each write an append-only AdminAuditLog row in the same transaction as
 * the change (structurally enforced server-side).
 */
export const adminApi = {
  usage: (): Promise<AdminUsage> => request<AdminUsage>('/admin/usage'),

  /** `pending` returns only unreviewed flags; omit for all, newest first. */
  async listFlags(status?: 'pending'): Promise<ModerationFlag[]> {
    const q = status ? '?status=pending' : '';
    const res = await request<ModerationFlagList>(`/admin/flags${q}`);
    return res.flags ?? [];
  },

  /** Bodyless. Marks the flag reviewed by the calling admin; re-review → 409. */
  reviewFlag: (id: string): Promise<ModerationFlag> =>
    request<ModerationFlag>(`/admin/flags/${id}/review`, { method: 'POST' }),

  /** Always sends both fields. null = clear override, 0 = block all. */
  setUserLimits: (
    id: string,
    limits: SetUserLimitsRequest,
  ): Promise<UserLimits> =>
    request<UserLimits>(`/admin/users/${id}/limits`, {
      method: 'PUT',
      body: limits,
    }),
};
