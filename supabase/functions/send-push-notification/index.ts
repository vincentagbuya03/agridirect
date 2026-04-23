import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type SendPushPayload = {
  targetUserId?: string;
  title?: string;
  body?: string;
  notificationCode?: string;
  linkType?: string;
  linkId?: string | null;
  data?: Record<string, string>;
};

type GoogleTokenResponse = {
  access_token?: string;
};

type NotificationTypeRow = {
  notification_type_id: number;
  code?: string;
};

type DeviceTokenRow = {
  token_id: string;
  fcm_token: string;
};

type NotificationInsertRow = {
  user_id: string;
  notification_type_id: number;
  title: string;
  body: string;
  link_type: string | null;
  link_id: string | null;
};

function normalizePrivateKey(privateKey: string): string {
  return privateKey.replace(/\\n/g, "\n");
}

function base64UrlEncode(input: Uint8Array): string {
  let binary = "";
  for (const byte of input) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function stringToUint8Array(value: string): Uint8Array {
  return new TextEncoder().encode(value);
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const clean = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getGoogleAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY");

  if (!clientEmail || !privateKey) {
    throw new Error(
      "Missing FIREBASE_CLIENT_EMAIL or FIREBASE_PRIVATE_KEY edge function secrets.",
    );
  }

  const now = Math.floor(Date.now() / 1000);
  const jwtHeader = {
    alg: "RS256",
    typ: "JWT",
  };

  const jwtClaimSet = {
    iss: clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(
    stringToUint8Array(JSON.stringify(jwtHeader)),
  );
  const encodedClaimSet = base64UrlEncode(
    stringToUint8Array(JSON.stringify(jwtClaimSet)),
  );
  const signingInput = `${encodedHeader}.${encodedClaimSet}`;

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(normalizePrivateKey(privateKey)),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    stringToUint8Array(signingInput) as BufferSource,
  );

  const assertion = `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(`Failed to get Google access token: ${errorText}`);
  }

  const tokenJson = await tokenResponse.json() as GoogleTokenResponse;
  if (!tokenJson.access_token) {
    throw new Error("Google OAuth response did not include an access_token.");
  }

  return tokenJson.access_token as string;
}

function buildMessageData(
  linkType?: string,
  linkId?: string | null,
  extraData?: Record<string, string>,
): Record<string, string> {
  return {
    link_type: linkType ?? "",
    link_id: linkId ?? "",
    ...(extraData ?? {}),
  };
}

async function resolveNotificationTypeId(
  adminClient: ReturnType<typeof createClient>,
  notificationCode: string,
  fallbackName: string,
): Promise<number> {
  const existingTypeResponse = await adminClient
    .from("notification_types")
    .select("notification_type_id")
    .eq("code", notificationCode)
    .limit(1)
    .maybeSingle();

  if (existingTypeResponse.error) {
    throw new Error(
      `Failed to read notification type '${notificationCode}': ${existingTypeResponse.error.message}`,
    );
  }

  const existingType = existingTypeResponse.data as NotificationTypeRow | null;
  if (existingType?.notification_type_id != null) {
    return existingType.notification_type_id;
  }

  const maxIdResponse = await adminClient
    .from("notification_types")
    .select("notification_type_id")
    .order("notification_type_id", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (maxIdResponse.error) {
    throw new Error(
      `Failed to determine next notification type id: ${maxIdResponse.error.message}`,
    );
  }

  const maxIdRow = maxIdResponse.data as NotificationTypeRow | null;
  const nextId = (maxIdRow?.notification_type_id ?? 0) + 1;

  const insertResponse = await adminClient
    .from("notification_types")
    .insert({
      notification_type_id: nextId,
      code: notificationCode,
      name: fallbackName,
      description: `Generated notification type for ${notificationCode}`,
    });

  if (!insertResponse.error) {
    return nextId;
  }

  const retryTypeResponse = await adminClient
    .from("notification_types")
    .select("notification_type_id")
    .eq("code", notificationCode)
    .limit(1)
    .maybeSingle();

  if (retryTypeResponse.error || !retryTypeResponse.data) {
    throw new Error(
      `Unable to resolve notification type '${notificationCode}': ${insertResponse.error.message}`,
    );
  }

  const retryType = retryTypeResponse.data as NotificationTypeRow;
  return retryType.notification_type_id;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID");

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      throw new Error(
        "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.",
      );
    }

    if (!firebaseProjectId) {
      throw new Error("Missing FIREBASE_PROJECT_ID edge function secret.");
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);

    const payload = await request.json() as SendPushPayload;
    const targetUserId = payload.targetUserId?.trim();
    const title = payload.title?.trim();
    const body = payload.body?.trim();
    const notificationCode = payload.notificationCode?.trim() || "general";

    console.log(`--- NEW NOTIFICATION REQUEST ---`);
    console.log(`Target User: ${targetUserId}`);
    console.log(`Title: ${title}`);

    if (!targetUserId || !title || !body) {
      return new Response(
        JSON.stringify({
          error: "targetUserId, title, and body are required.",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const notificationTypeId = await resolveNotificationTypeId(
      adminClient,
      notificationCode,
      title,
    );

    const messageData = buildMessageData(
      payload.linkType,
      payload.linkId,
      payload.data,
    );

    const notificationRow: NotificationInsertRow = {
      user_id: targetUserId,
      notification_type_id: notificationTypeId,
      title,
      body,
      link_type: payload.linkType ?? null,
      link_id: payload.linkId ?? null,
    };

    const insertResponse = await adminClient
      .from("notifications")
      .insert(notificationRow);
    const insertError = insertResponse.error;

    if (insertError) {
      throw new Error(`Failed to create notification row: ${insertError.message}`);
    }

    const tokenRowsResponse = await adminClient
      .from("user_device_tokens")
      .select("token_id, fcm_token")
      .eq("user_id", targetUserId)
      .eq("is_active", true);
    const tokenRows = tokenRowsResponse.data as DeviceTokenRow[] | null;
    const tokenError = tokenRowsResponse.error;

    if (tokenError) {
      throw new Error(`Failed to load device tokens: ${tokenError.message}`);
    }

    if (!tokenRows || tokenRows.length === 0) {
      console.log(`[!] No active tokens found for user ${targetUserId}`);
      return new Response(
        JSON.stringify({
          success: true,
          sent: 0,
          reason: "Notification stored, but user has no active phone tokens.",
        }),
        {
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    console.log(`[+] Found ${tokenRows.length} active tokens. Attempting FCM send...`);
    const accessToken = await getGoogleAccessToken();
    const sendResults = await Promise.all(
      tokenRows.map(async (tokenRow) => {
        const fcmResponse = await fetch(
          `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token: tokenRow.fcm_token,
                notification: {
                  title,
                  body,
                },
                data: messageData,
                android: {
                  priority: "high",
                  notification: {
                    channel_id: "agridirect_channel",
                    sound: "default",
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      sound: "default",
                    },
                  },
                },
              },
            }),
          },
        );

        const responseText = await fcmResponse.text();
        const ok = fcmResponse.ok;

        console.log(`FCM Result for ${tokenRow.token_id}: OK=${ok}, Response=${responseText}`);

        if (!ok && responseText.includes("UNREGISTERED")) {
          await adminClient
            .from("user_device_tokens")
            .update({ is_active: false, updated_at: new Date().toISOString() })
            .eq("token_id", tokenRow.token_id);
        }

        return {
          tokenId: tokenRow.token_id,
          ok,
          responseText,
        };
      }),
    );

    return new Response(
      JSON.stringify({
        success: true,
        sent: sendResults.filter((result) => result.ok).length,
        total: sendResults.length,
        results: sendResults,
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    return new Response(
      JSON.stringify({
        error: message,
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});
