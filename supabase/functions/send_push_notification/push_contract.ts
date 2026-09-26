/** Privacy boundary for FCM: the database inbox is the source of detail. */

export interface StoredNotification {
  id: string;
  user_id: string;
  kind?: string | null;
  title?: string | null;
  body?: string | null;
  data?: Record<string, unknown> | null;
}

export interface SafePushMessage {
  token: string;
  notification: { title: string; body: string };
  data: Record<string, string>;
}

export interface SendStatus {
  ok: boolean;
  status: number;
  unregistered: boolean;
}

const UUID = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
const JOB_ID = /^(?:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|RPR-\d{1,8})$/i;
const FCM_ERROR_TYPE = "type.googleapis.com/google.firebase.fcm.v1.FcmError";

// Match NotificationDeepLink's current route contract. Unknown kinds still
// receive a generic push; a tap opens the app without an untrusted route.
const CHAT_KINDS = new Set(["chat_message_new"]);
const JOB_KINDS = new Set([
  "repair_bid_new", "repair_bid_accepted", "repair_bid_rejected",
  "repair_job_cancelled", "rate_engineer", "rate_hospital",
  "cost_revision_proposed", "cost_revision_approved", "cost_revision_rejected",
  "warranty_covered", "warranty_fee_waived", "escrow_dispute_opened",
  "escrow_engineer_responded", "escrow_dispute_resolved",
  "amc_visit_assigned", "amc_visit_engineer_assigned", "amc_visit_engineer_changed",
  "engineer_payout_processed", "engineer_payout_failed",
]);
const AMC_KINDS = new Set([
  "amc_sla_breach", "amc_visit_pending_assignment", "amc_renewal_due",
]);
const ENGINEER_KINDS = new Set(["amc_loyal_pair_nudge"]);
const NO_ID_KINDS = new Set([
  "kyc_status_changed", "cash_survey", "spot_audit_invited",
  "commission_tier_upgraded", "engineer_auto_suspended",
  "admin_engineer_auto_suspended", "admin_escrow_dispute_opened",
  "amc_admin_escalation_raised", "engineer_suspension_cleared",
  "amc_visit_unassigned",
]);
export const SUPPORTED_KINDS = new Set([
  ...CHAT_KINDS, ...JOB_KINDS, ...AMC_KINDS, ...ENGINEER_KINDS, ...NO_ID_KINDS,
]);

/**
 * Build exactly the payload an installation can receive after its account
 * changes. Title/body are fixed; only a validated route selector is copied.
 * A destination still fetches its content with current authenticated rights.
 */
export function buildSafePushMessage(
  notification: StoredNotification,
  token: string,
): SafePushMessage | null {
  if (!UUID.test(notification.id) || !UUID.test(notification.user_id) || !token) return null;

  const kind = notification.kind ?? "";
  const known = SUPPORTED_KINDS.has(kind);
  const channel = CHAT_KINDS.has(kind) ? "chat" :
    JOB_KINDS.has(kind) || AMC_KINDS.has(kind) ? "jobs" : "account";
  const data: Record<string, string> = {
    user_id: notification.user_id,
    notification_id: notification.id,
    ...(known ? { kind } : {}),
    channel,
    category: channel,
  };
  const source = notification.data ?? {};
  let idKey: string | null = null;
  let validId: RegExp | null = null;
  if (CHAT_KINDS.has(kind)) {
    idKey = "conversation_id";
    validId = UUID;
  } else if (JOB_KINDS.has(kind)) {
    idKey = "repair_job_id";
    validId = JOB_ID;
  } else if (AMC_KINDS.has(kind)) {
    idKey = "amc_contract_id";
    validId = UUID;
  } else if (ENGINEER_KINDS.has(kind)) {
    idKey = "engineer_id";
    validId = UUID;
  }
  const routeId = idKey ? source[idKey] : undefined;
  if (idKey && validId && typeof routeId === "string" && validId.test(routeId)) {
    data[idKey] = routeId;
  }
  return {
    token,
    notification: { title: "EquipSeva", body: "You have a new notification." },
    data,
  };
}

/** Only FCM's structured token error is evidence of an unregistered token. */
export function classifyFcmFailure(status: number, body: string): { unregistered: boolean } {
  if (status !== 404) return { unregistered: false };
  try {
    const payload = JSON.parse(body) as {
      error?: { details?: Array<Record<string, unknown>> };
    };
    const details = payload?.error?.details;
    return {
      unregistered: Array.isArray(details) && details.some((detail) =>
        detail?.["@type"] === FCM_ERROR_TYPE && detail?.errorCode === "UNREGISTERED"
      ),
    };
  } catch {
    return { unregistered: false };
  }
}

/** FCM HTTP v1 boundary; injectable fetch keeps wire assertions offline. */
export async function sendToFcm(
  projectId: string,
  accessToken: string,
  message: SafePushMessage,
  fetchImpl: typeof fetch = fetch,
): Promise<SendStatus> {
  const res = await fetchImpl(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ message }),
      signal: AbortSignal.timeout(8_000),
    },
  );
  return {
    ok: res.ok,
    status: res.status,
    unregistered: res.ok ? false :
      classifyFcmFailure(res.status, await res.text()).unregistered,
  };
}

/** A failed sibling cannot discard a successful send or expose token IDs. */
export async function sendBatch(
  tokens: string[],
  send: (token: string) => Promise<SendStatus>,
): Promise<{ sent: number; failed: number; unregistered: number; transportFailure: boolean }> {
  const results = await Promise.all(tokens.map(async (token) => {
    try {
      return { ...(await send(token)), transportError: false };
    } catch {
      return { ok: false, status: 0, unregistered: false, transportError: true };
    }
  }));
  return {
    sent: results.filter((result) => result.ok).length,
    failed: results.filter((result) => !result.ok).length,
    unregistered: results.filter((result) => result.unregistered).length,
    // Existing completed FCM HTTP responses were acknowledged by this
    // webhook, including 429/5xx. Preserve that response contract until a
    // durable per-token send ledger makes partial retries safe.
    transportFailure: results.some((result) => result.transportError),
  };
}

/**
 * Shared production/test fan-out boundary. It never returns token values, so
 * a stale invalid-token response cannot be repurposed as a DELETE selector.
 */
export function deliverNotification(
  notification: StoredNotification,
  tokens: string[],
  send: (message: SafePushMessage) => Promise<SendStatus>,
): Promise<{ sent: number; failed: number; unregistered: number; transportFailure: boolean }> {
  return sendBatch(tokens, async (token) => {
    const message = buildSafePushMessage(notification, token);
    return message ? await send(message) :
      { ok: false, status: 400, unregistered: false };
  });
}
