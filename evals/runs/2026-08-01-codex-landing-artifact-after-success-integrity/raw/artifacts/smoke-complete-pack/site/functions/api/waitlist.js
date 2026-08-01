const BUTTONDOWN_DEFAULT_API_BASE = "https://api.buttondown.email/v1";

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });

const clean = (value, max = 120) =>
  typeof value === "string" ? value.trim().slice(0, max) : "";

const laneFor = ({ utm_source, utm_medium }) => {
  const source = clean(utm_source, 50).toLowerCase();
  const medium = clean(utm_medium, 50).toLowerCase();
  if (medium === "cpc") return "cold_paid";
  if (medium === "outreach" && source === "founder_dm") return "warm_outreach";
  return "cold_community_social";
};

export async function onRequestPost({ request, env }) {
  if (!env.BUTTONDOWN_API_KEY) {
    return json({ ok: false, error: "service_not_configured" }, 503);
  }

  let input;
  try {
    input = await request.json();
  } catch {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  // Honeypot: acknowledge without creating a subscriber.
  if (clean(input.website, 200)) return json({ ok: true, accepted: false });

  const email = clean(input.email, 254).toLowerCase();
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailPattern.test(email)) {
    return json({ ok: false, error: "invalid_email" }, 400);
  }

  const metadata = {
    source_lane: laneFor(input),
    utm_source: clean(input.utm_source, 50) || "direct",
    utm_medium: clean(input.utm_medium, 50) || "none",
    utm_campaign: clean(input.utm_campaign, 80) || "none",
    utm_content: clean(input.utm_content, 80) || "none",
    use_case: clean(input.use_case, 500),
    captured_at: new Date().toISOString(),
  };

  const apiBase = env.BUTTONDOWN_API_BASE || BUTTONDOWN_DEFAULT_API_BASE;
  const response = await fetch(`${apiBase}/subscribers`, {
    method: "POST",
    headers: {
      Authorization: `Token ${env.BUTTONDOWN_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email_address: email,
      metadata,
    }),
  });

  if (!response.ok) {
    const providerBody = await response.text();
    console.error("Buttondown rejected subscriber", response.status, providerBody.slice(0, 500));
    return json({ ok: false, error: "provider_rejected" }, 502);
  }

  // `ok: true` is returned only after Buttondown accepts the subscriber.
  return json({ ok: true, accepted: true, source_lane: metadata.source_lane });
}

export function onRequestGet() {
  return json({ ok: false, error: "method_not_allowed" }, 405);
}
