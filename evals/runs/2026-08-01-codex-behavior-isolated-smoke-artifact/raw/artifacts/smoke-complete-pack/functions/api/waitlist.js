const BUTTONDOWN_ENDPOINT = "https://api.buttondown.com/v1/subscribers";

const clean = (value, max = 160) =>
  typeof value === "string" ? value.trim().slice(0, max) : "";

function trafficClass({ utm_source: source, utm_medium: medium }) {
  if (medium === "outreach" && ["warm_email", "warm_linkedin"].includes(source)) {
    return "warm_outreach";
  }
  if (medium === "cpc") return "cold_paid";
  if (medium === "community") return "cold_community";
  if (medium === "social") return "cold_social";
  return "direct_or_unknown";
}

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });

export async function onRequestPost({ request, env }) {
  if (!env.BUTTONDOWN_API_KEY) {
    return json({ ok: false, error: "Waitlist service is not configured." }, 503);
  }

  let input;
  try {
    input = await request.json();
  } catch {
    return json({ ok: false, error: "Invalid request." }, 400);
  }

  // Honeypot: report a neutral response but do not create a subscriber.
  if (clean(input.company_website, 200)) return json({ ok: true, status: "screened" });

  const email = clean(input.email, 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return json({ ok: false, error: "Enter a valid work email." }, 422);
  }

  const attribution = {
    utm_source: clean(input.utm_source, 80) || "direct",
    utm_medium: clean(input.utm_medium, 80) || "none",
    utm_campaign: clean(input.utm_campaign, 100) || "none",
    utm_content: clean(input.utm_content, 120) || "none",
  };
  const cohort = trafficClass(attribution);

  const payload = {
    email_address: email,
    tags: ["clienttabs-early-access", cohort],
    metadata: {
      ...attribution,
      traffic_class: cohort,
      role: clean(input.role, 80),
      team_size: clean(input.team_size, 40),
      pain: clean(input.pain, 500),
      landing_variant: "hero_a",
    },
  };

  let provider;
  try {
    provider = await fetch(BUTTONDOWN_ENDPOINT, {
      method: "POST",
      headers: {
        Authorization: `Token ${env.BUTTONDOWN_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });
  } catch {
    return json({ ok: false, error: "The waitlist is temporarily unavailable. Please try again." }, 502);
  }

  if (!provider.ok) {
    // Do not expose provider details or claim acceptance on duplicates/rejections.
    return json(
      { ok: false, error: "Buttondown did not accept this request. Check the address or try again." },
      provider.status === 429 ? 429 : 400,
    );
  }

  return json({ ok: true, status: "accepted" }, 201);
}

export function onRequest() {
  return json({ ok: false, error: "Method not allowed." }, 405);
}
