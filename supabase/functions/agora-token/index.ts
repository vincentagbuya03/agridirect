import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import agoraAccessToken from "npm:agora-access-token@2.0.4";

const { RtcTokenBuilder, RtcRole } = agoraAccessToken;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const appId = Deno.env.get("AGORA_APP_ID")?.trim();
    const appCert = Deno.env.get("AGORA_APP_CERT")?.trim();
    if (!appId || !appCert) {
      throw new Error("AGORA_APP_ID and AGORA_APP_CERT must be set");
    }

    const {
      channelName,
      uid,
      role = "publisher",
      expiresIn = 3600,
    } = await req.json();
    if (!channelName) throw new Error("channelName is required");

    const numericUid = Number(uid);
    if (!Number.isInteger(numericUid) || numericUid <= 0) {
      throw new Error("uid must be a positive integer");
    }

    const expireSeconds = Math.max(60, Number(expiresIn) || 3600);
    const privilegeExpiredTs =
      Math.floor(Date.now() / 1000) + expireSeconds;
    const rtcRole =
      role === "subscriber" ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCert,
      String(channelName),
      numericUid,
      rtcRole,
      privilegeExpiredTs,
    );

    console.log(
      `Token OK: channel=${channelName} uid=${numericUid} role=${role} expire=${expireSeconds}s`,
    );

    return new Response(
      JSON.stringify({
        token,
        uid: numericUid,
        channelName,
        expiresIn: expireSeconds,
        appId,
      }),
      { status: 200, headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Error:", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...cors, "Content-Type": "application/json" } },
    );
  }
});
