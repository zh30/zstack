const ALLOWED_ROUTES = Object.freeze({
  "reddit|community|cst_smoke_202608": "cold_community",
  "x|social|cst_smoke_202608": "cold_community",
  "indiehackers|community|cst_smoke_202608": "cold_community",
  "support_forum|community|cst_smoke_202608": "cold_community",
  "reddit_ads|cpc|cst_smoke_202608": "cold_paid",
  "warm_email|outreach|cst_smoke_202608": "warm_outreach",
  "warm_dm|outreach|cst_smoke_202608": "warm_outreach"
});

const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff"
};

function reply(status, body) {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function normalize(value, max = 80) {
  return typeof value === "string" ? value.trim().toLowerCase().slice(0, max) : "";
}

function validEmail(value) {
  return typeof value === "string" && value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function parseFragment(raw) {
  const parsed = JSON.parse(raw);
  if (!parsed || Array.isArray(parsed) || typeof parsed !== "object") throw new Error("invalid_fragment");
  return parsed;
}

export async function onRequestPost(context) {
  const { request, env } = context;
  const requestId = crypto.randomUUID();

  if (env.VERIFY_BUTTONDOWN_CONTRACT !== "VERIFIED_BY_OWNER") {
    return reply(503, { ok: false, category: "integration_unverified", request_id: requestId });
  }

  let input;
  try {
    input = await request.json();
  } catch {
    return reply(400, { ok: false, category: "invalid_json", request_id: requestId });
  }

  if (!validEmail(input.email)) {
    return reply(400, { ok: false, category: "invalid_email", request_id: requestId });
  }

  // A honeypot value means likely automation. Do not send it to the provider.
  if (input.company_website) {
    return reply(202, { ok: false, category: "filtered_automation", request_id: requestId });
  }

  const source = normalize(input.utm_source);
  const medium = normalize(input.utm_medium);
  const campaign = normalize(input.utm_campaign);
  const key = `${source}|${medium}|${campaign}`;
  const lane = ALLOWED_ROUTES[key] || "unattributed";

  const required = [
    "BUTTONDOWN_API_ENDPOINT",
    "BUTTONDOWN_AUTH_HEADER_VALUE",
    "BUTTONDOWN_EMAIL_FIELD",
    "BUTTONDOWN_BASE_PAYLOAD_JSON",
    `BUTTONDOWN_ATTRIBUTION_FRAGMENT_${lane.toUpperCase()}`,
    "BUTTONDOWN_ACCEPTED_STATUS_CODES"
  ];
  if (required.some((name) => !env[name])) {
    return reply(503, { ok: false, category: "integration_incomplete", request_id: requestId });
  }

  let providerPayload;
  let attributionFragment;
  try {
    providerPayload = parseFragment(env.BUTTONDOWN_BASE_PAYLOAD_JSON);
    attributionFragment = parseFragment(env[`BUTTONDOWN_ATTRIBUTION_FRAGMENT_${lane.toUpperCase()}`]);
  } catch {
    return reply(503, { ok: false, category: "integration_invalid_config", request_id: requestId });
  }

  Object.assign(providerPayload, attributionFragment);
  // Attribution fragments cannot override the subscriber address.
  providerPayload[env.BUTTONDOWN_EMAIL_FIELD] = input.email.trim();

  let providerResponse;
  try {
    providerResponse = await fetch(env.BUTTONDOWN_API_ENDPOINT, {
      method: "POST",
      headers: {
        "authorization": env.BUTTONDOWN_AUTH_HEADER_VALUE,
        "content-type": "application/json",
        "accept": "application/json"
      },
      body: JSON.stringify(providerPayload)
    });
  } catch {
    // Privacy-safe diagnostic only: category and non-PII request id.
    return reply(502, { ok: false, category: "provider_unreachable", request_id: requestId });
  }

  const accepted = env.BUTTONDOWN_ACCEPTED_STATUS_CODES
    .split(",")
    .map((value) => Number(value.trim()))
    .includes(providerResponse.status);

  if (!accepted) {
    // Never log or return the raw provider body, email, token, or payload.
    return reply(502, {
      ok: false,
      category: "provider_rejected",
      provider_status: providerResponse.status,
      request_id: requestId
    });
  }

  // This response is the server-validated provider acceptance boundary.
  return reply(200, { ok: true, lane, request_id: requestId });
}

export function onRequestGet() {
  return reply(405, { ok: false, category: "method_not_allowed" });
}
