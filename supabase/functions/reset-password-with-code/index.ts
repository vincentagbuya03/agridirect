import { createClient } from "npm:@supabase/supabase-js@2";

type ResetPayload = {
  email?: string;
  code?: string;
  newPassword?: string;
};

type VerificationRow = {
  code_id: string;
  verification_code: string;
  verification_type: string;
  used_at: string | null;
  expires_at: string;
  created_at?: string;
};

type RateLimitRow = {
  rate_key: string;
  attempt_count: number;
  window_started_at: string;
  blocked_until: string | null;
};

const RATE_LIMIT_ACTION = "reset_password_with_code";
const IP_WINDOW_MINUTES = 15;
const IP_MAX_ATTEMPTS = 20;
const IP_BLOCK_MINUTES = 30;
const EMAIL_WINDOW_MINUTES = 15;
const EMAIL_MAX_ATTEMPTS = 5;
const EMAIL_BLOCK_MINUTES = 30;

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function getClientIp(request: Request): string {
  const forwardedFor = request.headers.get("x-forwarded-for");
  if (forwardedFor && forwardedFor.trim().length > 0) {
    return forwardedFor.split(",")[0].trim();
  }

  const realIp = request.headers.get("x-real-ip");
  if (realIp && realIp.trim().length > 0) {
    return realIp.trim();
  }

  return "unknown";
}

function getAllowedOrigins(): string[] {
  const raw = Deno.env.get("ALLOWED_ORIGINS") ?? "";
  return raw
    .split(",")
    .map((x) => x.trim())
    .filter((x) => x.length > 0);
}

function buildCorsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get("origin");
  const allowedOrigins = getAllowedOrigins();

  const allowOrigin = !origin || origin.trim().length === 0
    ? "*"
    : allowedOrigins.length === 0
    ? origin
    : allowedOrigins.includes(origin)
    ? origin
    : "null";

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

async function applyRateLimit(params: {
  adminClient: ReturnType<typeof createClient>;
  rateKey: string;
  maxAttempts: number;
  windowMinutes: number;
  blockMinutes: number;
}): Promise<{ allowed: boolean; retryAfterSeconds?: number }> {
  const {
    adminClient,
    rateKey,
    maxAttempts,
    windowMinutes,
    blockMinutes,
  } = params;

  const now = Date.now();
  const windowMs = windowMinutes * 60 * 1000;
  const blockMs = blockMinutes * 60 * 1000;

  const lookup = await adminClient
    .from("security_rate_limits")
    .select("rate_key, attempt_count, window_started_at, blocked_until")
    .eq("rate_key", rateKey)
    .maybeSingle();

  if (lookup.error) {
    throw new Error(`Rate limit lookup failed: ${lookup.error.message}`);
  }

  const row = lookup.data as RateLimitRow | null;

  if (row == null) {
    const insert = await adminClient
      .from("security_rate_limits")
      .insert({
        rate_key: rateKey,
        action: RATE_LIMIT_ACTION,
        attempt_count: 1,
        window_started_at: new Date(now).toISOString(),
        blocked_until: null,
        last_attempt_at: new Date(now).toISOString(),
      });

    if (insert.error) {
      throw new Error(`Rate limit insert failed: ${insert.error.message}`);
    }

    return { allowed: true };
  }

  const blockedUntilMs = row.blocked_until ? new Date(row.blocked_until).getTime() : 0;
  if (blockedUntilMs > now) {
    return {
      allowed: false,
      retryAfterSeconds: Math.max(1, Math.ceil((blockedUntilMs - now) / 1000)),
    };
  }

  const windowStartMs = new Date(row.window_started_at).getTime();
  const withinWindow = now - windowStartMs < windowMs;
  const nextAttemptCount = withinWindow ? row.attempt_count + 1 : 1;
  const nextWindowStartedAt = withinWindow
    ? row.window_started_at
    : new Date(now).toISOString();

  const shouldBlock = withinWindow && nextAttemptCount > maxAttempts;
  const nextBlockedUntil = shouldBlock
    ? new Date(now + blockMs).toISOString()
    : null;

  const update = await adminClient
    .from("security_rate_limits")
    .update({
      attempt_count: nextAttemptCount,
      window_started_at: nextWindowStartedAt,
      blocked_until: nextBlockedUntil,
      last_attempt_at: new Date(now).toISOString(),
      updated_at: new Date(now).toISOString(),
    })
    .eq("rate_key", rateKey);

  if (update.error) {
    throw new Error(`Rate limit update failed: ${update.error.message}`);
  }

  if (shouldBlock) {
    return {
      allowed: false,
      retryAfterSeconds: Math.max(1, Math.ceil(blockMs / 1000)),
    };
  }

  return { allowed: true };
}

Deno.serve(async (request: Request) => {
  const corsHeaders = buildCorsHeaders(request);

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed." }),
      {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const payload = await request.json() as ResetPayload;
    const email = normalizeEmail(payload.email ?? "");
    const code = (payload.code ?? "").trim();
    const newPassword = (payload.newPassword ?? "").trim();
    const clientIp = getClientIp(request);

    if (!email || !code || !newPassword) {
      return new Response(
        JSON.stringify({ error: "email, code, and newPassword are required." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    if (!/^\d{6}$/.test(code)) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired code." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const emailHash = await sha256Hex(email);

    const ipLimit = await applyRateLimit({
      adminClient,
      rateKey: `${RATE_LIMIT_ACTION}:ip:${clientIp}`,
      maxAttempts: IP_MAX_ATTEMPTS,
      windowMinutes: IP_WINDOW_MINUTES,
      blockMinutes: IP_BLOCK_MINUTES,
    });

    if (!ipLimit.allowed) {
      return new Response(
        JSON.stringify({
          error: "Too many reset attempts from this network. Please try again later.",
          retry_after_seconds: ipLimit.retryAfterSeconds,
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": String(ipLimit.retryAfterSeconds ?? 60),
          },
        },
      );
    }

    const emailLimit = await applyRateLimit({
      adminClient,
      rateKey: `${RATE_LIMIT_ACTION}:email:${emailHash}`,
      maxAttempts: EMAIL_MAX_ATTEMPTS,
      windowMinutes: EMAIL_WINDOW_MINUTES,
      blockMinutes: EMAIL_BLOCK_MINUTES,
    });

    if (!emailLimit.allowed) {
      return new Response(
        JSON.stringify({
          error: "Too many reset attempts for this account. Please try again later.",
          retry_after_seconds: emailLimit.retryAfterSeconds,
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
            "Retry-After": String(emailLimit.retryAfterSeconds ?? 60),
          },
        },
      );
    }

    if (newPassword.length < 6) {
      return new Response(
        JSON.stringify({ error: "Password must be at least 6 characters." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Collect all candidate user IDs that match the identifier (email or phone variants).
    const candidateUserIds: string[] = [];

    // 1. Check users table by email
    const usersByEmail = await adminClient
      .from("users")
      .select("user_id")
      .ilike("email", email)
      .order("created_at", { ascending: false })
      .limit(5);

    if (usersByEmail.data) {
      for (const row of usersByEmail.data) {
        if (row.user_id && !candidateUserIds.includes(String(row.user_id))) {
          candidateUserIds.push(String(row.user_id));
        }
      }
    }

    // 2. Check v_users_with_roles view by email
    if (candidateUserIds.length === 0) {
      const viewByEmail = await adminClient
        .from("v_users_with_roles")
        .select("user_id")
        .ilike("email", email)
        .order("created_at", { ascending: false })
        .limit(5);

      if (viewByEmail.data) {
        for (const row of viewByEmail.data) {
          if (row.user_id && !candidateUserIds.includes(String(row.user_id))) {
            candidateUserIds.push(String(row.user_id));
          }
        }
      }
    }

    // 3. Check users table by phone variants or synthetic email
    const digits = email.replace(/[^\d]/g, "");
    if (digits.length >= 10) {
      const tenDigits = digits.slice(-10);
      const usersByPhone = await adminClient
        .from("users")
        .select("user_id")
        .or(`phone.eq.+63${tenDigits},phone.eq.63${tenDigits},phone.eq.0${tenDigits},phone.eq.${tenDigits},phone.ilike.%${tenDigits},email.eq.63${tenDigits}@phone.agridirect.ph`)
        .order("created_at", { ascending: false })
        .limit(5);

      if (usersByPhone.data) {
        for (const row of usersByPhone.data) {
          if (row.user_id && !candidateUserIds.includes(String(row.user_id))) {
            candidateUserIds.push(String(row.user_id));
          }
        }
      }
    }

    if (candidateUserIds.length === 0) {
      console.warn(`[reset-password] No user found for identifier: ${email}`);
      return new Response(
        JSON.stringify({ error: "Invalid or expired code." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 4. Resolve exact userId by checking which candidate user has a matching verification code
    let resolvedUserId: string | null = null;
    let matchingCodeRow: VerificationRow | null = null;

    const codesQuery = await adminClient
      .from("verification_codes")
      .select("code_id, user_id, verification_code, verification_type, used_at, expires_at, created_at")
      .in("user_id", candidateUserIds)
      .eq("verification_code", code)
      .order("created_at", { ascending: false })
      .limit(1);

    if (codesQuery.data && codesQuery.data.length > 0) {
      const foundRow = codesQuery.data[0] as unknown as VerificationRow & { user_id: string };
      resolvedUserId = String(foundRow.user_id);
      matchingCodeRow = foundRow;
    } else {
      // Fallback: pick the first candidate if no matching code row found immediately
      resolvedUserId = candidateUserIds[0];
    }

    const userId = resolvedUserId;

    // 5. Verify the code
    let isVerified = false;

    // First attempt normal verification via RPC (works if code is still unused)
    const verifyRes = await adminClient.rpc("verify_user_code", {
      p_user_id: userId,
      p_code: code,
    });

    if (Boolean((verifyRes.data as { success?: boolean } | null)?.success)) {
      isVerified = true;
    } else {
      // Fallback: code may have already been consumed during the explicit "Verify Code" step
      if (matchingCodeRow) {
        const now = Date.now();
        const usedAt = matchingCodeRow.used_at ? new Date(matchingCodeRow.used_at).getTime() : null;
        const expiresAt = matchingCodeRow.expires_at ? new Date(matchingCodeRow.expires_at).getTime() : null;

        // Valid if:
        // a) Unused and not expired
        // b) Used within the last 15 minutes as part of the current verification flow
        if (usedAt == null && expiresAt != null && expiresAt > now) {
          isVerified = true;
        } else if (usedAt != null && now - usedAt <= 15 * 60 * 1000) {
          isVerified = true;
        }
      }
    }

    if (!isVerified) {
      console.warn(`[reset-password] Verification failed for user: ${userId}, code: ${code}`);
      return new Response(
        JSON.stringify({ error: "Invalid or expired code." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Ensure the code is marked as used
    if (matchingCodeRow?.code_id && !matchingCodeRow.used_at) {
      await adminClient
        .from("verification_codes")
        .update({ used_at: new Date().toISOString() })
        .eq("code_id", matchingCodeRow.code_id);
    }

    const updateRes = await adminClient.auth.admin.updateUserById(userId, {
      password: newPassword,
    });

    if (updateRes.error) {
      return new Response(
        JSON.stringify({ error: `Password update failed: ${updateRes.error.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (e) {
    console.error("reset-password-with-code failed", e);
    return new Response(
      JSON.stringify({ error: "Unable to process password reset right now." }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
