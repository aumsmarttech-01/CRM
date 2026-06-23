const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function httpError(status, message, details) {
  const error = new Error(message);
  error.status = status;
  if (details) error.details = details;
  return error;
}

export function assertUuid(value, fieldName = "id") {
  if (!value || !UUID_RE.test(String(value))) {
    throw httpError(400, `Invalid ${fieldName}`);
  }
  return String(value);
}

export function validateClientLogin(body = {}) {
  const email = String(body.email || "").trim().toLowerCase();
  const password = String(body.password || "");

  if (!EMAIL_RE.test(email)) throw httpError(400, "Valid email is required");
  if (password.length < 8) throw httpError(400, "Password must be at least 8 characters");

  return { email, password };
}

export function validateClientProfilePatch(body = {}) {
  const data = {};

  if (body.name !== undefined) {
    const name = String(body.name).trim();
    if (name.length > 120) throw httpError(400, "Name is too long");
    data.name = name || null;
  }

  if (body.phone !== undefined) {
    const phone = String(body.phone).trim();
    if (phone.length > 40) throw httpError(400, "Phone is too long");
    data.phone = phone || null;
  }

  return data;
}

export function validateTicketComment(body = {}) {
  const comment = String(body.comment || "").trim();
  if (comment.length < 1) throw httpError(400, "Comment is required");
  if (comment.length > 4000) throw httpError(400, "Comment is too long");
  return { comment };
}

export function validateDocumentUpload(body = {}) {
  const relatedType = body.relatedType ? String(body.relatedType).trim() : null;
  const relatedId = body.relatedId ? assertUuid(body.relatedId, "relatedId") : null;
  const documentType = body.documentType ? String(body.documentType).trim().slice(0, 80) : null;

  const allowedRelatedTypes = new Set([null, "ticket", "service_ticket", "project", "compliance"]);
  if (!allowedRelatedTypes.has(relatedType)) throw httpError(400, "Unsupported relatedType");

  if (relatedType && !relatedId) throw httpError(400, "relatedId is required when relatedType is provided");

  return { relatedType, relatedId, documentType };
}

export const allowedUploadMimeTypes = new Set([
  "application/pdf",
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
]);

export const maxUploadBytes = 10 * 1024 * 1024;
