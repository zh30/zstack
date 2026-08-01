const BUTTONDOWN_ENDPOINT = "https://api.buttondown.com/v1/subscribers";

const ALLOWLIST = Object.freeze({
  "dm|outreach|restore_smoke_202608|support_agent": "warm_dm",
  "reddit|community|restore_smoke_202608|r_customersuccess": "reddit_organic",
  "support_driven|community|restore_smoke_202608|member_post": "support_driven",
  "x|social|restore_smoke_202608|founder_post": "x_organic",
  "reddit_ads|cpc|restore_smoke_202608|support_context_v1": "reddit_ads"
});

const json = (body, status = 200, requestId = "") =>
  new Response(JSON.stringify({ ...body, request_id: requestId }), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff"
    }
  });

const clean = (value, max) =>
  typeof value === "string" ? value.trim().toLowerCase().slice(0, max) : "";

export async function onRequestPost(context) {
  const requestId = crypto.randomUUID();
  let body;

  try {
    body = await context.request.json();
  } catch {
    return json({ ok: false, category: "invalid_json" }, 400, requestId);
  }

  const email = clean(body.email, 254);
  const emailValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  if (!emailValid) {
    return json({ ok: false, category: "invalid_email" }, 400, requestId);
  }

  const source = clean(body.utm_source, 64);
  const medium = clean(body.utm_medium, 64);
  const campaign = clean(body.utm_campaign, 64);
  const content = clean(body.utm_content, 64);
  const lane = ALLOWLIST[`${source}|${medium}|${campaign}|${content}`] || "unattributed";

  let tagMap;
  try {
    tagMap = JSON.parse(context.env.BUTTONDOWN_TAG_MAP_JSON || "{}");
  } catch {
    return json({ ok: false, category: "configuration_error" }, 503, requestId);
  }

  const tagId = tagMap[lane];
  if (!context.env.BUTTONDOWN_API_KEY || typeof tagId !== "string" || !tagId) {
    return json({ ok: false, category: "configuration_error" }, 503, requestId);
  }

  let providerResponse;
  try {
    providerResponse = await fetch(BUTTONDOWN_ENDPOINT, {
      method: "POST",
      headers: {
        authorization: `Token ${context.env.BUTTONDOWN_API_KEY}`,
        "content-type": "application/json"
      },
      body: JSON.stringify({ email_address: email, tags: [tagId] })
    });
  } catch {
    return json({ ok: false, category: "provider_unreachable" }, 502, requestId);
  }

  if (!providerResponse.ok) {
    const category = providerResponse.status === 429
      ? "provider_rate_limited"
      : providerResponse.status >= 500
        ? "provider_error"
        : "provider_rejected";
    return json({ ok: false, category }, 502, requestId);
  }

  // This means Buttondown accepted the request, not that double opt-in is complete.
  // Do not log the email, request body, auth header, or raw provider response.
  return json({ ok: true, lane, category: "provider_accepted" }, 202, requestId);
}
