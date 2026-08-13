// One free trial per device ID and per IP (silent abuse prevention).
//
// Called from the app after sign-up with the user JWT.
// IP is read from the request — never from the client body.
//
// Deploy: supabase functions deploy claim-trial

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function clientIp(req: Request): string | null {
  const forwarded = req.headers.get("x-forwarded-for");
  if (forwarded) {
    const first = forwarded.split(",")[0]?.trim() ?? "";
    if (first) return first.replace(/:\d+$/, "");
  }
  const cf = req.headers.get("cf-connecting-ip")?.trim();
  if (cf) return cf;
  const real = req.headers.get("x-real-ip")?.trim();
  if (real) return real;
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.toLowerCase().startsWith("bearer ")) {
    return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), {
      status: 401,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  let body: { device_id?: string } = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const deviceId = (body.device_id ?? "").trim();
  if (!deviceId) {
    return new Response(
      JSON.stringify({ ok: false, granted: false, error: "device_id required" }),
      { status: 400, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!supabaseUrl || !serviceKey) {
    return new Response(JSON.stringify({ ok: false, error: "misconfigured" }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) {
    return new Response(JSON.stringify({ ok: false, error: "unauthorized" }), {
      status: 401,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }

  const admin = createClient(supabaseUrl, serviceKey);
  const ip = clientIp(req);

  const { data: byDevice } = await admin
    .from("device_trials")
    .select("device_id")
    .eq("device_id", deviceId)
    .maybeSingle();
  if (byDevice) {
    return new Response(
      JSON.stringify({ ok: true, granted: false, reason: "device" }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  }

  if (ip) {
    const { data: byIp } = await admin
      .from("device_trials")
      .select("device_id")
      .eq("ip_address", ip)
      .maybeSingle();
    if (byIp) {
      return new Response(
        JSON.stringify({ ok: true, granted: false, reason: "ip" }),
        { headers: { ...cors, "Content-Type": "application/json" } },
      );
    }
  }

  const { error: insertErr } = await admin.from("device_trials").insert({
    device_id: deviceId,
    ip_address: ip,
  });
  if (insertErr) {
    return new Response(
      JSON.stringify({ ok: true, granted: false, reason: "device" }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify({ ok: true, granted: true }), {
    headers: { ...cors, "Content-Type": "application/json" },
  });
});
