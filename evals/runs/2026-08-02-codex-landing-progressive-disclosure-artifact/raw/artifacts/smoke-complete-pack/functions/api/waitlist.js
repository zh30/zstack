// Cloudflare Pages Function. This file is intentionally network-off until every
// VERIFY_* contract value is replaced from dated, official Buttondown docs.
const MAX_BYTES = 2048;
const PROVIDER_TIMEOUT_MS = 5000;
const VERIFY_BUTTONDOWN_CONTRACT = "VERIFY_BUTTONDOWN_CONTRACT";
const VERIFY_BUTTONDOWN_ENDPOINT = "VERIFY_BUTTONDOWN_ENDPOINT";
const VERIFY_BUTTONDOWN_AUTH_SCHEME = "VERIFY_BUTTONDOWN_AUTH_SCHEME";
const VERIFY_BUTTONDOWN_EMAIL_FIELD = "VERIFY_BUTTONDOWN_EMAIL_FIELD";
const VERIFY_BUTTONDOWN_ATTRIBUTION_FIELD = "VERIFY_BUTTONDOWN_ATTRIBUTION_FIELD";
const VERIFY_BUTTONDOWN_ACCEPTED_STATUS = "VERIFY_BUTTONDOWN_ACCEPTED_STATUS";

const ROLE = new Set(["support_agent", "support_lead", "customer_success", "other"]);
const FREQUENCY = new Set(["1_2", "3_5", "6_plus"]);
const VARIANT = new Set(["hero_a"]);
const LANES = [
  { source: "linkedin", medium: "paid_social", campaign: "restore_tabs_v1", content: "support_agent_static_a", lane: "cold_paid" },
  { source: "reddit", medium: "community", campaign: "restore_tabs_v1", content: "r_customersuccess_problem", lane: "cold_reddit" },
  { source: "support_driven", medium: "community", campaign: "restore_tabs_v1", content: "support_driven_feedback", lane: "cold_community" },
  { source: "x", medium: "organic_social", campaign: "restore_tabs_v1", content: "founder_problem_story", lane: "cold_social" },
  { source: "founder", medium: "warm_outreach", campaign: "restore_tabs_v1", content: "personal_note", lane: "warm_outreach" }
];

function json(status, category, requestId) {
  return new Response(JSON.stringify({ category, request_id: requestId }), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" }
  });
}

async function readBounded(request) {
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      total += part.value.byteLength;
      if (total > MAX_BYTES) {
        await reader.cancel();
        return null;
      }
      chunks.push(part.value);
    }
  } catch (_ignored) {
    return undefined;
  }
  const joined = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { joined.set(chunk, offset); offset += chunk.byteLength; }
  return joined;
}

function cleanText(value, max) {
  return typeof value === "string" && value.length <= max ? value : null;
}

function validEmail(value) {
  return typeof value === "string" && value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function deriveAttribution(input) {
  const source = cleanText(input.utm_source, 32);
  const medium = cleanText(input.utm_medium, 32);
  const campaign = cleanText(input.utm_campaign, 32);
  const content = cleanText(input.utm_content, 48);
  if ([source, medium, campaign, content].some(value => value === null)) return null;
  const match = LANES.find(item => item.source === source && item.medium === medium && item.campaign === campaign && item.content === content);
  return match ? { lane: match.lane, placement: match.content, variant: "hero_a" } : { lane: "unattributed", placement: "unknown", variant: "hero_a" };
}

function contractReady(env) {
  const fixed = [
    VERIFY_BUTTONDOWN_CONTRACT,
    VERIFY_BUTTONDOWN_ENDPOINT,
    VERIFY_BUTTONDOWN_AUTH_SCHEME,
    VERIFY_BUTTONDOWN_EMAIL_FIELD,
    VERIFY_BUTTONDOWN_ATTRIBUTION_FIELD,
    VERIFY_BUTTONDOWN_ACCEPTED_STATUS
  ];
  return fixed.every(value => !value.startsWith("VERIFY_")) && typeof env.BUTTONDOWN_API_KEY === "string" && env.BUTTONDOWN_API_KEY.length > 0;
}

function providerPayload(email, role, frequency, attribution) {
  // Verify from official docs that the attribution field accepts this object
  // and persists it on the provider-confirmed subscriber before replacing gates.
  return {
    [VERIFY_BUTTONDOWN_EMAIL_FIELD]: email,
    [VERIFY_BUTTONDOWN_ATTRIBUTION_FIELD]: {
      decision_lane: attribution.lane,
      placement: attribution.placement,
      variant: attribution.variant,
      role,
      frequency
    }
  };
}

export async function onRequestPost(context) {
  const requestId = crypto.randomUUID();
  if ((context.request.headers.get("content-type") || "").trim().toLowerCase() !== "application/json") return json(415, "invalid_media_type", requestId);

  const bytes = await readBounded(context.request);
  if (bytes === null) return json(413, "body_too_large", requestId);
  if (bytes === undefined) return json(400, "invalid_body", requestId);

  let input;
  try { input = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)); }
  catch (_ignored) { return json(400, "invalid_json", requestId); }
  if (input === null || Array.isArray(input) || typeof input !== "object" || Object.getPrototypeOf(input) !== Object.prototype) return json(400, "invalid_root", requestId);

  const email = typeof input.email === "string" ? input.email.trim().toLowerCase() : "";
  const role = cleanText(input.role, 32);
  const frequency = cleanText(input.frequency, 16);
  const variant = cleanText(input.variant, 16);
  const attribution = deriveAttribution(input);
  if (!validEmail(email) || !ROLE.has(role) || !FREQUENCY.has(frequency) || !VARIANT.has(variant) || input.consent !== true || !attribution) return json(400, "invalid_input", requestId);
  if (!contractReady(context.env)) return json(503, "not_configured", requestId);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);
  let response;
  try {
    response = await fetch(VERIFY_BUTTONDOWN_ENDPOINT, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "authorization": `${VERIFY_BUTTONDOWN_AUTH_SCHEME} ${context.env.BUTTONDOWN_API_KEY}`
      },
      body: JSON.stringify(providerPayload(email, role, frequency, attribution)),
      signal: controller.signal
    });
  } catch (_ignored) {
    clearTimeout(timer);
    return json(503, controller.signal.aborted ? "provider_timeout" : "provider_unavailable", requestId);
  }
  clearTimeout(timer);

  const accepted = VERIFY_BUTTONDOWN_ACCEPTED_STATUS.split(",").map(value => Number(value.trim())).filter(Number.isInteger);
  if (!accepted.includes(response.status)) return json(502, "provider_rejected", requestId);
  // Do not parse, return, or log the provider body. Provider export/record is the
  // conversion source of truth; this response permits only neutral local copy.
  return json(202, "provider_accepted", requestId);
}

function rejectMethod(context) {
  return json(405, "method_not_allowed", crypto.randomUUID());
}

export const onRequestGet = rejectMethod;
export const onRequestPut = rejectMethod;
export const onRequestPatch = rejectMethod;
export const onRequestDelete = rejectMethod;
