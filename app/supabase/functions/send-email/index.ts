// Supabase Auth "Send Email" hook -> delivers auth emails via Mailgun's REST API.
//
// This is what actually USES the Mailgun API key. Supabase Auth calls this
// function whenever it needs to send an email (e.g. the forgot-PIN one-time
// code). We format the message and hand it to Mailgun over HTTPS.
//
// Configure in the dashboard: Authentication -> Hooks -> Send Email -> point it
// at this deployed function and set the shared secret to SEND_EMAIL_HOOK_SECRET.
//
// Secrets are read from the environment (see supabase/functions/.env):
//   MAILGUN_API_KEY, MAILGUN_DOMAIN, MAILGUN_BASE_URL, MAILGUN_SENDER,
//   SEND_EMAIL_HOOK_SECRET
//
// Deploy: supabase functions deploy send-email --no-verify-jwt

import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

interface EmailData {
  token: string;
  token_hash: string;
  redirect_to: string;
  email_action_type: string;
  site_url: string;
}

interface HookPayload {
  user: { email: string };
  email_data: EmailData;
}

const MAILGUN_API_KEY = Deno.env.get("MAILGUN_API_KEY") ?? "";
const MAILGUN_DOMAIN = Deno.env.get("MAILGUN_DOMAIN") ?? "";
const MAILGUN_BASE_URL =
  Deno.env.get("MAILGUN_BASE_URL") ?? "https://api.mailgun.net";
const MAILGUN_SENDER =
  Deno.env.get("MAILGUN_SENDER") ?? "Match Word <no-reply@example.com>";
const HOOK_SECRET = (Deno.env.get("SEND_EMAIL_HOOK_SECRET") ?? "")
  .replace("v1,whsec_", "");

// Human-friendly subject lines per auth action.
function subjectFor(actionType: string): string {
  switch (actionType) {
    case "recovery":
    case "magiclink":
      return "Your Match Word code";
    case "signup":
    case "email_change":
      return "Confirm your Match Word email";
    default:
      return "Match Word";
  }
}

// Large, calm, senior-friendly email body showing the one-time code.
function bodyFor(token: string): { text: string; html: string } {
  const text =
    `Hello,\n\nYour Match Word code is: ${token}\n\n` +
    `Enter this code in the app to continue. It expires shortly.\n\n` +
    `If you did not request this, you can ignore this email.\n\n— Match Word`;
  const html =
    `<div style="font-family:Arial,sans-serif;font-size:20px;color:#222;line-height:1.5">` +
    `<p>Hello,</p>` +
    `<p>Your Match Word code is:</p>` +
    `<p style="font-size:40px;font-weight:bold;letter-spacing:6px;color:#2b6cb0">${token}</p>` +
    `<p>Enter this code in the app to continue. It expires shortly.</p>` +
    `<p style="color:#666">If you did not request this, you can ignore this email.</p>` +
    `<p>— Match Word</p></div>`;
  return { text, html };
}

async function sendViaMailgun(to: string, subject: string, body: {
  text: string;
  html: string;
}): Promise<Response> {
  const form = new FormData();
  form.append("from", MAILGUN_SENDER);
  form.append("to", to);
  form.append("subject", subject);
  form.append("text", body.text);
  form.append("html", body.html);

  const auth = "Basic " + btoa(`api:${MAILGUN_API_KEY}`);
  return await fetch(`${MAILGUN_BASE_URL}/v3/${MAILGUN_DOMAIN}/messages`, {
    method: "POST",
    headers: { Authorization: auth },
    body: form,
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (!MAILGUN_API_KEY || !MAILGUN_DOMAIN) {
    console.error("Mailgun is not configured (missing API key or domain).");
    return new Response(
      JSON.stringify({ error: { message: "Email provider not configured" } }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const raw = await req.text();

  // Verify the payload really came from Supabase Auth.
  let payload: HookPayload;
  try {
    const wh = new Webhook(HOOK_SECRET);
    payload = wh.verify(raw, Object.fromEntries(req.headers)) as HookPayload;
  } catch (err) {
    console.error("Hook signature verification failed:", err);
    return new Response("Invalid signature", { status: 401 });
  }

  const { user, email_data } = payload;
  const subject = subjectFor(email_data.email_action_type);
  const body = bodyFor(email_data.token);

  const res = await sendViaMailgun(user.email, subject, body);
  if (!res.ok) {
    const detail = await res.text();
    console.error(`Mailgun send failed (${res.status}): ${detail}`);
    return new Response(
      JSON.stringify({ error: { message: "Failed to send email" } }),
      { status: 502, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
