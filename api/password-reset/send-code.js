const nodemailer = require('nodemailer');
const { createClient } = require('@supabase/supabase-js');

const fallbackSupabaseUrl = 'https://ywfppgarzyksacgbesme.supabase.co';
const fallbackSupabaseAnonKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3ZnBwZ2Fyenlrc2FjZ2Jlc21lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3NzEzMjcsImV4cCI6MjA4NzM0NzMyN30.aX1HIacJsHV8gU-9tGONnDpucE9vePWOrJbgMR4fSzs';

const allowedOrigins = new Set([
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'https://agridirect-app.vercel.app',
]);

function setCors(req, res) {
  const origin = req.headers.origin;
  res.setHeader(
    'Access-Control-Allow-Origin',
    origin && allowedOrigins.has(origin) ? origin : 'https://agridirect-app.vercel.app',
  );
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function cleanEnv(value) {
  return String(value || '').replace(/\\r|\\n/g, '').trim();
}

function looksLikeJwt(value) {
  return value.split('.').length === 3 && value.split('.').every((part) => part.length > 0);
}

function buildResetEmail(code) {
  return `
<!doctype html>
<html>
  <body style="margin:0;padding:0;background:#f3f7f4;font-family:Arial,Helvetica,sans-serif;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="padding:24px 12px;background:#f3f7f4;">
      <tr>
        <td align="center">
          <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;background:#ffffff;border:1px solid #d6e2d9;border-radius:16px;overflow:hidden;">
            <tr><td style="height:6px;background:#16a34a;"></td></tr>
            <tr>
              <td style="padding:28px;text-align:center;">
                <h1 style="margin:0;color:#0f6c34;font-size:28px;font-weight:800;">AgriDirect</h1>
                <p style="margin:8px 0 0;color:#5f6f62;font-size:14px;">Password Reset Code</p>
              </td>
            </tr>
            <tr>
              <td style="padding:0 28px 28px;">
                <div style="background:#eef9f1;border:1px solid #cfe7d5;border-radius:12px;padding:24px;text-align:center;">
                  <p style="margin:0 0 14px;color:#1f3c29;font-size:15px;">Use this code to reset your password.</p>
                  <div style="display:inline-block;padding:12px 18px;border:1px solid #cfe0d1;border-radius:10px;background:#ffffff;color:#0f6c34;font-family:'Courier New',monospace;font-size:32px;font-weight:700;letter-spacing:8px;">${code}</div>
                  <p style="margin:16px 0 0;color:#4e6955;font-size:12px;font-weight:700;">This code expires in 10 minutes.</p>
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:0 28px 26px;color:#6b7c70;font-size:12px;line-height:1.6;">
                If you did not request this, you can safely ignore this email.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

module.exports = async function handler(req, res) {
  setCors(req, res);

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed.' });
  }

  const supabaseUrl = cleanEnv(process.env.SUPABASE_URL) || fallbackSupabaseUrl;
  const configuredKey = cleanEnv(process.env.SUPABASE_SERVICE_ROLE_KEY) || cleanEnv(process.env.SUPABASE_ANON_KEY);
  const supabaseKey = looksLikeJwt(configuredKey) ? configuredKey : fallbackSupabaseAnonKey;
  const gmailUser = cleanEnv(process.env.GMAIL_USER);
  const gmailPass = cleanEnv(process.env.GMAIL_PASS);

  if (!supabaseUrl || !supabaseKey || !gmailUser || !gmailPass) {
    return res.status(500).json({ error: 'Password reset email is not configured.' });
  }

  try {
    const email = normalizeEmail(req.body && req.body.email);
    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'A valid email address is required.' });
    }

    const supabase = createClient(supabaseUrl, supabaseKey);
    const resetCode = await supabase.rpc('request_password_reset_code', {
      p_email: email,
    });

    if (resetCode.error || !resetCode.data || resetCode.data.success !== true) {
      const message = resetCode.error
        ? resetCode.error.message
        : resetCode.data && resetCode.data.message
          ? resetCode.data.message
          : 'Unable to prepare password reset code.';
      return res.status(400).json({ error: message });
    }

    const code = String(resetCode.data.code || '');
    if (!/^\d{6}$/.test(code)) {
      return res.status(500).json({ error: 'Unable to prepare password reset code.' });
    }

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: gmailUser,
        pass: gmailPass,
      },
    });

    await transporter.sendMail({
      from: `"AgriDirect Support" <${gmailUser}>`,
      to: email,
      subject: 'AgriDirect: Password Reset Request',
      html: buildResetEmail(code),
    });

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('[password-reset/send-code] failed', error);
    return res.status(500).json({ error: 'Unable to send password reset email right now.' });
  }
};
