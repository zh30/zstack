const MAX_BODY_BYTES = 4096;
const UPSTREAM_TIMEOUT_MS = 6000;
const ERROR_CATEGORIES = new Set([
  "bad_media_type", "body_too_large", "body_stream_error", "malformed_json",
  "invalid_root", "invalid_email", "bot_suspected", "invalid_attribution",
  "integration_unverified", "provider_timeout", "provider_network",
  "provider_rejected", "method_not_allowed"
]);

const REGISTERED = new Map([
  ["linkedin|social|contextdeck_smoke_2026_08|founder_post|a", ["cold_social", "linkedin_founder", "a"]],
  ["reddit|community|contextdeck_smoke_2026_08|r_customersuccess|a", ["cold_community", "reddit_customersuccess", "a"]],
  ["indiehackers|community|contextdeck_smoke_2026_08|milestone|a", ["cold_community", "ih_milestone", "a"]],
  ["google|cpc|contextdeck_smoke_2026_08|search_context_restore|a", ["cold_paid", "google_search", "a"]],
  ["linkedin|cpc|contextdeck_smoke_2026_08|support_agents|a", ["cold_paid", "linkedin_ad", "a"]],
  ["warm_email|outreach|contextdeck_smoke_2026_08|personal_note|a", ["warm_outreach", "warm_email", "a"]]
]);

function json(status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {"content-type": "application/json; charset=utf-8", "cache-control": "no-store"}
  });
}

function failure(status, category, requestId) {
  const safe = ERROR_CATEGORIES.has(category) ? category : "provider_rejected";
  console.log(JSON.stringify({request_id: requestId, category: safe, http_status: status}));
  return json(status, {ok: false, category: safe, request_id: requestId});
}

async function readBoundedBody(request) {
  if (!request.body) return new Uint8Array();
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > MAX_BODY_BYTES) {
        await reader.cancel();
        return {error: "body_too_large"};
      }
      chunks.push(value);
    }
  } catch (_) {
    return {error: "body_stream_error"};
  }
  const body = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.byteLength; }
  return {body};
}

function canonicalAttribution(input) {
  const bounded = ["source", "medium", "campaign", "content", "variant"].map(key =>
    typeof input[key] === "string" && input[key].length <= 80 ? input[key] : ""
  );
  return REGISTERED.get(bounded.join("|")) || ["unattributed", "unattributed", "a"];
}

function validEmail(value) {
  return typeof value === "string" && value.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

export async function onRequestPost(context) {
  const requestId = crypto.randomUUID();
  const type = (context.request.headers.get("content-type") || "").split(";", 1)[0].trim().toLowerCase();
  if (type !== "application/json") return failure(415, "bad_media_type", requestId);

  const read = await readBoundedBody(context.request);
  if (read.error) return failure(read.error === "body_too_large" ? 413 : 400, read.error, requestId);
  let input;
  try { input = JSON.parse(new TextDecoder("utf-8", {fatal: true}).decode(read.body)); }
  catch (_) { return failure(400, "malformed_json", requestId); }
  if (input === null || Array.isArray(input) || typeof input !== "object") return failure(400, "invalid_root", requestId);
  if (typeof input.company_site === "string" && input.company_site !== "") return failure(400, "bot_suspected", requestId);
  if (!validEmail(input.email)) return failure(400, "invalid_email", requestId);

  const [decisionLane, placement, variant] = canonicalAttribution(input);

  /* LAUNCH BLOCKER: web access was unavailable on 2026-08-01. Verify current
     Buttondown official docs, then replace every VERIFY_* value below with the
     documented endpoint/auth/payload/status contract. The code intentionally
     performs no provider request while any item is unresolved. */
  const contract = {
    endpoint: "VERIFY_BUTTONDOWN_SUBSCRIBER_ENDPOINT",
    authHeader: "VERIFY_BUTTONDOWN_AUTH_HEADER",
    authPrefix: "VERIFY_BUTTONDOWN_AUTH_PREFIX",
    emailField: "VERIFY_BUTTONDOWN_EMAIL_FIELD",
    metadataField: "VERIFY_BUTTONDOWN_METADATA_FIELD",
    acceptedStatuses: "VERIFY_BUTTONDOWN_ACCEPTED_STATUSES"
  };
  if (Object.values(contract).some(value => value.startsWith("VERIFY_")) || !context.env.BUTTONDOWN_API_KEY) {
    return failure(503, "integration_unverified", requestId);
  }

  // Replace this payload adapter only after official semantics are verified.
  const providerPayload = {
    [contract.emailField]: input.email,
    [contract.metadataField]: {decision_lane: decisionLane, placement, variant, request_id: requestId}
  };
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
  let response;
  try {
    response = await fetch(contract.endpoint, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        [contract.authHeader]: `${contract.authPrefix}${context.env.BUTTONDOWN_API_KEY}`
      },
      body: JSON.stringify(providerPayload),
      signal: controller.signal
    });
  } catch (error) {
    clearTimeout(timer);
    return failure(502, error instanceof DOMException && error.name === "AbortError" ? "provider_timeout" : "provider_network", requestId);
  }
  clearTimeout(timer);
  const accepted = contract.acceptedStatuses.split(",").map(Number).includes(response.status);
  if (!accepted) return failure(502, "provider_rejected", requestId);

  console.log(JSON.stringify({request_id: requestId, category: "accepted", http_status: response.status, decision_lane: decisionLane, placement, variant}));
  return json(200, {ok: true, request_id: requestId});
}

export function onRequest(context) {
  if (context.request.method === "POST") return onRequestPost(context);
  return failure(405, "method_not_allowed", crypto.randomUUID());
}
