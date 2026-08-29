/**
 * Client-side password hint only. The server is the source of truth
 * (`password: { minLength: 8 }` in backend/api/openapi.yaml) and rejects a
 * short password with `validation_error`; this just spares the round trip.
 */
export const MIN_PASSWORD_LENGTH = 8;
