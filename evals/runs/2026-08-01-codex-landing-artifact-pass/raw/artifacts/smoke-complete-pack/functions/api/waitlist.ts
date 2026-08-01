interface Env {
  BUTTONDOWN_API_KEY: string;
  BUTTONDOWN_SUBSCRIBERS_ENDPOINT: string;
  ALLOWED_ORIGIN: string;
}

interface Attribution {
  utm_source: string;
  utm_medium: string;
  utm_campaign: string;
  utm_content: string;
  utm_term: string;
  variant: string;
  traffic_class: string;
}

interface WaitlistRequest {
  email?: unknown;
  pain?: unknown;
  consent?: unknown;
  website?: unknown;
  attribution?: Partial<Attribution>;
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const ATTRIBUTION_KEYS: Array<keyof Attribution> = [
  "utm_source",
  "utm_medium",
  "utm_campaign",
  "utm_content",
  "utm_term",
  "variant",
  "traffic_class",
];

function json(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

function clean(value: unknown, maxLength: number): string {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function cleanAttribution(input: WaitlistRequest["attribution"]): Attribution {
  const values = Object.fromEntries(
    ATTRIBUTION_KEYS.map((key) => [key, clean(input?.[key], 100) || "none"]),
  ) as unknown as Attribution;
  return values;
}

export const onRequestPost: PagesFunction<Env> = async (context) => {
  const origin = context.request.headers.get("Origin");
  if (!origin || origin !== context.env.ALLOWED_ORIGIN) {
    return json({ accepted: false, error: "Origin not allowed." }, 403);
  }

  if (!context.request.headers.get("Content-Type")?.includes("application/json")) {
    return json({ accepted: false, error: "Expected JSON." }, 415);
  }

  let input: WaitlistRequest;
  try {
    input = await context.request.json<WaitlistRequest>();
  } catch {
    return json({ accepted: false, error: "Invalid JSON." }, 400);
  }

  if (clean(input.website, 200)) {
    return json({ accepted: false, error: "Invalid submission." }, 400);
  }

  const email = clean(input.email, 254).toLowerCase();
  const pain = clean(input.pain, 500);
  if (!EMAIL_PATTERN.test(email) || input.consent !== true) {
    return json({ accepted: false, error: "A valid email and consent are required." }, 400);
  }

  if (!context.env.BUTTONDOWN_API_KEY || !context.env.BUTTONDOWN_SUBSCRIBERS_ENDPOINT) {
    return json({ accepted: false, error: "Waitlist provider is not configured." }, 503);
  }

  const attribution = cleanAttribution(input.attribution);
  const providerResponse = await fetch(context.env.BUTTONDOWN_SUBSCRIBERS_ENDPOINT, {
    method: "POST",
    headers: {
      "Authorization": `Token ${context.env.BUTTONDOWN_API_KEY}`,
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: JSON.stringify({
      email_address: email,
      metadata: {
        ...attribution,
        biggest_pain: pain || "not_provided",
        consent_source: "landing_form",
      },
    }),
  });

  if (!providerResponse.ok) {
    // Do not return provider details: they can leak account configuration or PII.
    return json({ accepted: false, error: "Buttondown did not accept this signup." }, 502);
  }

  // This success means Buttondown accepted the subscriber record. It does not
  // claim the person opened or confirmed an email.
  return json({ accepted: true }, 201);
};
