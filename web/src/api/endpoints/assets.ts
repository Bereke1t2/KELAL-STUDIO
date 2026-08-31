import { request } from '../client';
import type { Asset } from '../types';

/**
 * Asset upload (PRD §6.8).
 *
 * Multipart, field name `file` (backend/api/openapi.yaml). The server decides
 * the type by content, re-encodes, strips metadata, and enforces size / side
 * limits; any rejection is `validation_error` (400). JPEG and PNG only.
 *
 * There is NO GET route — the response carries `{id, width, height, mime_type}`
 * and the portal has no way to read the image back. Callers show those facts,
 * not an <img>.
 */
export const assetsApi = {
  upload(file: File): Promise<Asset> {
    const form = new FormData();
    form.append('file', file);
    return request<Asset>('/assets', { method: 'POST', form });
  },
};
