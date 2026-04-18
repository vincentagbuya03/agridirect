import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type NearbyProductPayload = {
  productId?: string;
  productName?: string;
  farmName?: string;
  farmLocation?: string;
};

type FarmerRow = {
  farmer_id: string;
  user_id: string;
  farm_name: string | null;
  location: string | null;
  residential_address: string | null;
};

type CustomerRow = {
  user_id: string;
};

type GoogleTokenResponse = {
  access_token?: string;
};

type NotificationTypeRow = {
  notification_type_id: number;
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

async function sendPushNotification(
  adminClient: ReturnType<typeof createClient>,
  firebaseProjectId: string,
  targetUserId: string,
  title: string,
  body: string,
  notificationCode: string,
  linkType: string,
  linkId: string,
) {
  await adminClient
    .from("notification_types")
    .upsert(
      {
        code: notificationCode,
        name: title,
        description: `Generated notification type for ${notificationCode}`,
      },
      { onConflict: "code" },
    );

  const notificationTypeResponse = await adminClient
    .from("notification_types")
    .select("notification_type_id")
    .eq("code", notificationCode)
    .single();
  const notificationType =
    notificationTypeResponse.data as NotificationTypeRow | null;
  if (notificationTypeResponse.error || !notificationType) {
    throw new Error(
      `Unable to resolve notification type '${notificationCode}'.`,
    );
  }

  const notificationRow: NotificationInsertRow = {
    user_id: targetUserId,
    notification_type_id: notificationType.notification_type_id,
    title,
    body,
    link_type: linkType ?? null,
    link_id: linkId ?? null,
  };

  const insertResponse = await adminClient
    .from("notifications")
    .insert(notificationRow);
  if (insertResponse.error) {
    throw new Error(
      `Failed to create notification row: ${insertResponse.error.message}`,
    );
  }

  const tokenRowsResponse = await adminClient
    .from("user_device_tokens")
    .select("token_id, fcm_token")
    .eq("user_id", targetUserId)
    .eq("is_active", true);
  const tokenRows = tokenRowsResponse.data as DeviceTokenRow[] | null;
  if (tokenRowsResponse.error) {
    throw new Error(`Failed to load device tokens: ${tokenRowsResponse.error.message}`);
  }

  if (!tokenRows || tokenRows.length === 0) {
    return {
      success: true,
      sent: 0,
      reason: "Notification stored, but user has no active phone tokens.",
    };
  }

  const accessToken = await getGoogleAccessToken();
  const messageData = buildMessageData(linkType, linkId);

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

  return {
    success: true,
    sent: sendResults.filter((result) => result.ok).length,
    total: sendResults.length,
    results: sendResults,
  };
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
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
    }

    if (!firebaseProjectId) {
      throw new Error("Missing FIREBASE_PROJECT_ID edge function secret.");
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey);

    const payload = await request.json() as NearbyProductPayload;
    const productId = payload.productId?.trim() || "";
    const productName = payload.productName?.trim() || "New product";
    const farmName = payload.farmName?.trim() || "A nearby farmer";

    if (!productId) {
      return new Response(
        JSON.stringify({ error: "productId is required." }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const farmerResponse = await adminClient
      .from("products")
      .select("farmer_id")
      .eq("product_id", productId)
      .single();

    if (farmerResponse.error) {
      throw farmerResponse.error;
    }

    const farmerId = (farmerResponse.data as { farmer_id?: string } | null)?.farmer_id;
    if (!farmerId) {
      throw new Error("Unable to resolve farmer for the new product.");
    }

    const farmerDetailsResponse = await adminClient
      .from("farmers")
      .select("farmer_id, user_id, farm_name, location, residential_address")
      .eq("farmer_id", farmerId)
      .single();

    if (farmerDetailsResponse.error) {
      throw farmerDetailsResponse.error;
    }

    const farmer = farmerDetailsResponse.data as FarmerRow;
    const effectiveFarmName = (farmer.farm_name?.trim() || farmName || "Nearby farmer");

    const customersResponse = await adminClient
      .from("customers")
      .select("user_id, is_active");

    if (customersResponse.error) {
      throw customersResponse.error;
    }

    const allCustomers = (customersResponse.data ?? []) as { user_id: string; is_active: boolean }[];
    const matchedUserIds = new Set<string>();

    console.log(`Found ${allCustomers.length} total customers in database.`);

    for (const customer of allCustomers) {
      // Logic: Send to all active customers except the farmer themselves
      if (customer.user_id && customer.user_id !== farmer.user_id) {
        if (customer.is_active) {
          matchedUserIds.add(customer.user_id);
        } else {
          console.log(`Skipping inactive customer: ${customer.user_id}`);
        }
      }
    }

    console.log(`Matched ${matchedUserIds.size} active customers for notification.`);


    if (matchedUserIds.size === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          sent: 0,
          total: 0,
          reason: "No active customers found for broadcast.",
        }),
        {
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const title = `New product from ${effectiveFarmName}`;
    const body = `${productName} is now available from ${effectiveFarmName}. Check it out while it is fresh.`;

    const results = await Promise.all(
      [...matchedUserIds].map(async (targetUserId) => {
        try {
          const pushResult = await sendPushNotification(
            adminClient,
            firebaseProjectId,
            targetUserId,
            title,
            body,
            "system",
            "product",
            productId,
          );

          return {
            targetUserId,
            ok: true,
            pushResult,
          };
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          return {
            targetUserId,
            ok: false,
            error: message,
          };
        }
      }),
    );

    return new Response(
      JSON.stringify({
        success: true,
        sent: results.filter((result) => result.ok).length,
        total: results.length,
        matchedUsers: [...matchedUserIds],
        results,
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
      JSON.stringify({ error: message }),
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