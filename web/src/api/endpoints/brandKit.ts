import { request } from '../client';
import type { BrandKit } from '../types';

/**
 * Brand Kit read/update (PRD §6.8).
 *
 * FLAG — the portal cannot DISCOVER a kit id through the documented API.
 * (backend/docs/OPEN_QUESTIONS.md, brandkit-creation.)
 *
 * The contract exposes only GET and PUT /brand-kits/{id}: there is no create
 * endpoint, no list endpoint, and no "my kit" endpoint. PUT is an
 * owner-scoped upsert at a CLIENT-SUPPLIED id, and a kit owned by someone
 * else returns 404 rather than 403 so ids cannot be enumerated. That leaves a
 * client holding a valid session with no documented way to learn which id its
 * own kit lives at.
 *
 * This module therefore takes the id from the caller and does NOT invent a
 * discovery mechanism. See BrandKitPage for the convention it passes and the
 * divergence risk that carries — the choice is surfaced there, not buried
 * here, and it is not a resolution of the open item.
 */
export const brandKitApi = {
  get: (id: string): Promise<BrandKit> => request<BrandKit>(`/brand-kits/${id}`),

  update: (id: string, kit: BrandKit): Promise<BrandKit> =>
    request<BrandKit>(`/brand-kits/${id}`, { method: 'PUT', body: kit }),
};
