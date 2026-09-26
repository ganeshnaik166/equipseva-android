import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import {
  buildSafePushMessage,
  classifyFcmFailure,
  sendBatch,
} from "./push_contract.ts";

const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";
const NOTIFICATION = "33333333-3333-4333-8333-333333333333";
const CONVERSATION = "44444444-4444-4444-8444-444444444444";
const JOB = "55555555-5555-4555-8555-555555555555";

function row(overrides = {}) {
  return {
    id: NOTIFICATION,
    user_id: A,
    title: "Dr Shah: ventilator failed",
    body: "Patient R's emergency repair costs ₹4,000",
    kind: "chat_message_new",
    data: { conversation_id: CONVERSATION },
    ...overrides,
  };
}

test("fetched owner wins over spoofed data and sensitive visible/data fields", () => {
  const message = buildSafePushMessage(row({
    data: {
      conversation_id: CONVERSATION,
      user_id: B,
      kind: "admin_engineer_auto_suspended",
      notification_id: B,
      title: "private title",
      body: "patient and payout details",
      patient_name: "Patient R",
      hospital_name: "Private Hospital",
      amount_rupees: 4000,
      payout_utr: "private UTR",
      channel: "other",
      category: "other",
    },
  }), "installation-token");

  assert.deepEqual(message, {
    token: "installation-token",
    notification: { title: "EquipSeva", body: "You have a new notification." },
    data: {
      user_id: A,
      notification_id: NOTIFICATION,
      kind: "chat_message_new",
      conversation_id: CONVERSATION,
      channel: "chat",
      category: "chat",
    },
  });
  const wire = JSON.stringify(message);
  for (const secret of ["Patient R", "Dr Shah", "Private Hospital", "4000", "private UTR"]) {
    assert.equal(wire.includes(secret), false, `outbound FCM contained ${secret}`);
  }
});

test("valid job and AMC navigation IDs survive in only the matching kind", () => {
  const jobMessage = buildSafePushMessage(row({
    kind: "repair_bid_accepted",
    data: { repair_job_id: "RPR-12345678", conversation_id: CONVERSATION, amc_contract_id: JOB },
  }), "t");
  assert.equal(jobMessage.data.repair_job_id, "RPR-12345678");
  assert.equal("conversation_id" in jobMessage.data, false);
  assert.equal("amc_contract_id" in jobMessage.data, false);
  assert.equal(jobMessage.data.channel, "jobs");

  const amcMessage = buildSafePushMessage(row({
    kind: "amc_sla_breach",
    data: { amc_contract_id: JOB, repair_job_id: JOB },
  }), "t");
  assert.equal(amcMessage.data.amc_contract_id, JOB);
  assert.equal("repair_job_id" in amcMessage.data, false);
});

test("malformed routing IDs and unknown kinds fall back without echoing data", () => {
  const malformed = buildSafePushMessage(row({
    data: { conversation_id: `${CONVERSATION}%2Ffounder`, deep_link: "founder/payments", user_id: B },
  }), "t");
  assert.equal("conversation_id" in malformed.data, false);
  assert.equal("deep_link" in malformed.data, false);
  assert.equal(malformed.data.user_id, A);

  const unknown = buildSafePushMessage(row({
    kind: "patient_hiv_alert",
    data: { repair_job_id: JOB, body: "secret" },
  }), "t");
  assert.deepEqual(unknown.data, {
    user_id: A,
    notification_id: NOTIFICATION,
    channel: "account",
    category: "account",
  });
});

test("a push selected before A to B transfer remains generic and tagged for A", () => {
  const message = buildSafePushMessage(row({
    kind: "engineer_payout_failed",
    data: { repair_job_id: JOB, payout_utr: "private UTR" },
  }), "token-now-on-B-device");
  assert.deepEqual(message.notification, {
    title: "EquipSeva",
    body: "You have a new notification.",
  });
  assert.equal(message.data.user_id, A);
  assert.equal(message.data.repair_job_id, JOB);
  assert.equal(JSON.stringify(message).includes("private UTR"), false);
});

test("only a structured token-specific FCM 404 counts as unregistered", () => {
  const tokenError = {
    error: {
      code: 404,
      status: "NOT_FOUND",
      details: [{
        "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
        errorCode: "UNREGISTERED",
      }],
    },
  };
  assert.equal(classifyFcmFailure(404, JSON.stringify(tokenError)).unregistered, true);
  assert.equal(classifyFcmFailure(404, JSON.stringify({ error: { status: "NOT_FOUND" } })).unregistered, false);
  assert.equal(classifyFcmFailure(404, "project UNREGISTERED but no token detail").unregistered, false);
  assert.equal(classifyFcmFailure(400, JSON.stringify({
    error: { details: [{
      "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
      errorCode: "INVALID_ARGUMENT",
    }] },
  })).unregistered, false);
  assert.equal(classifyFcmFailure(503, JSON.stringify(tokenError)).unregistered, false);
});

test("a failed token send does not lose a successful sibling or expose token IDs", async () => {
  const outcome = await sendBatch(["good-token", "timeout-token", "dead-token"], async (token) => {
    if (token === "timeout-token") throw new Error("network timeout with token");
    if (token === "dead-token") return { ok: false, status: 404, unregistered: true };
    return { ok: true, status: 200, unregistered: false };
  });
  assert.deepEqual(outcome, { sent: 1, failed: 2, unregistered: 1 });
  assert.equal(JSON.stringify(outcome).includes("token"), false);
});

test("sender never reaps by token or logs token suffixes before versioned claims exist", () => {
  const source = readFileSync(new URL("./index.ts", import.meta.url), "utf8");
  assert.doesNotMatch(source, /\.delete\(\)\s*\.in\(["']token["']/);
  assert.doesNotMatch(source, /token_suffixes|\.token\.slice\(-8\)/);
  assert.doesNotMatch(source, /notif\.title,\s*notif\.body,\s*data/);
});
