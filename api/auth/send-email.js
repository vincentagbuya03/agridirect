const nodemailer = require('nodemailer');

const fallbackGmailUser = 'noreplyagridirect@gmail.com';

const allowedOrigins = new Set([
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'https://agridirect-app.vercel.app',
  'https://agridirect.site',
  'https://www.agridirect.site',
]);

const emailRateLimits = new Map();

function isRateLimited(email) {
  const now = Date.now();
  const windowMs = 60 * 1000; // 1 minute window
  const maxDispatches = 5;

  const records = (emailRateLimits.get(email) || []).filter((t) => now - t < windowMs);
  if (records.length >= maxDispatches) {
    return true;
  }
  records.push(now);
  emailRateLimits.set(email, records);

  // Clean stale keys
  if (emailRateLimits.size > 2000) {
    for (const [key, timestamps] of emailRateLimits.entries()) {
      if (timestamps.every((t) => now - t >= windowMs)) {
        emailRateLimits.delete(key);
      }
    }
  }
  return false;
}

function escapeHtml(text) {
  return String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function isOriginAllowed(origin) {
  if (!origin) return false;
  try {
    const url = new URL(origin);
    const host = url.hostname.toLowerCase();
    if (allowedOrigins.has(origin)) return true;
    if (host === 'agridirect.site' || host.endsWith('.agridirect.site')) return true;
    if (host.endsWith('.vercel.app')) return true;
    if (host === 'localhost' || host === '127.0.0.1') return true;
  } catch (_) {
    // If not a full URL, fallback check
    if (allowedOrigins.has(origin)) return true;
    if (origin.endsWith('agridirect.site')) return true;
  }
  return false;
}

function setCors(req, res) {
  const origin = req.headers.origin;
  res.setHeader(
    'Access-Control-Allow-Origin',
    origin && isOriginAllowed(origin) ? origin : 'https://www.agridirect.site',
  );
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, Accept, X-Requested-With, Origin, X-AgriDirect-App',
  );
}

function normalizeEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function cleanEnv(value) {
  return String(value || '').replace(/\\r|\\n/g, '').trim();
}

function buildHtmlTemplate(code, action) {
  const cleanCode = escapeHtml(code.trim());
  const splitDigits = cleanCode.split('');
  const useDigitBoxes = splitDigits.length === 6;
  const isPasswordReset = action.toLowerCase().includes('reset');

  const actionLabel = isPasswordReset ? 'Password Reset Code' : 'Verification Code';
  const helpLine = isPasswordReset
      ? 'Enter this code in AgriDirect to continue resetting your password.'
      : 'Enter this code in AgriDirect to finish verifying your account.';

  const codeContent = useDigitBoxes
      ? splitDigits
            .map(
              (digit) =>
                  `<td style="width:42px; height:50px; border:1px solid #cfe0d1; border-radius:10px; background:#ffffff; text-align:center; font-family:'Courier New', Courier, monospace; font-size:28px; font-weight:700; color:#0f6c34;">${digit}</td>`
            )
            .join('<td style="width:8px;"></td>')
      : `<td style="border:1px solid #cfe0d1; border-radius:10px; background:#ffffff; text-align:center; font-family:'Courier New', Courier, monospace; font-size:34px; font-weight:700; color:#0f6c34; letter-spacing:8px; padding:10px 16px;">${cleanCode}</td>`;

  return `
<!doctype html>
<html>
  <body style="margin:0; padding:0; background:#edf3ee; font-family:Arial, Helvetica, sans-serif;">
    <div style="display:none; max-height:0; overflow:hidden; opacity:0; mso-hide:all;">${actionLabel} for your AgriDirect account.</div>
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f3f7f4; padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="width:100%; max-width:600px; background:#ffffff; border:1px solid #d6e2d9; border-radius:16px; overflow:hidden;">
            <tr>
              <td style="height:6px; background:linear-gradient(90deg,#0f6c34,#2aa85a);"></td>
            </tr>
            <tr>
              <td style="padding:26px 28px 12px 28px; text-align:center;">
                <div style="font-size:34px; line-height:34px;">🌱</div>
                <h1 style="margin:10px 0 0 0; color:#0f6c34; font-size:30px; font-weight:800; line-height:1.2;">AgriDirect</h1>
                <p style="margin:6px 0 0 0; color:#5f6f62; font-size:14px; line-height:1.5;">Secure account access</p>
              </td>
            </tr>

            <tr>
              <td style="padding:0 28px 4px 28px; text-align:center;">
                <p style="margin:0; color:#153b24; font-size:20px; font-weight:700; line-height:1.4;">${actionLabel}</p>
              </td>
            </tr>

            <tr>
              <td style="padding:8px 28px 0 28px;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#eef9f1; border:1px solid #cfe7d5; border-radius:12px;">
                  <tr>
                    <td style="padding:24px; text-align:center;">
                      <p style="margin:0 0 10px 0; color:#1f3c29; font-size:16px; line-height:1.5;">Use this code to ${action}.</p>
                      <p style="margin:0 0 16px 0; color:#476450; font-size:13px; line-height:1.5;">${helpLine}</p>
                      <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin:0 auto; border-collapse:separate; border-spacing:0;">
                        <tr>
                          ${codeContent}
                        </tr>
                      </table>
                      <p style="margin:14px 0 0 0; color:#4e6955; font-size:12px; line-height:1.5; font-weight:700;">This code expires in 10 minutes.</p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>

            <tr>
              <td style="padding:18px 28px 6px 28px;">
                <p style="margin:0; color:#5f6f62; font-size:13px; line-height:1.6;">For your security, do not share this code with anyone. AgriDirect support will never ask for this code.</p>
              </td>
            </tr>

            <tr>
              <td style="padding:8px 28px 8px 28px;">
                <p style="margin:0; color:#6b7c70; font-size:12px; line-height:1.6;">If you did not request this, you can safely ignore this email.</p>
              </td>
            </tr>

            <tr>
              <td style="padding:18px 28px 26px 28px; border-top:1px solid #edf2ee; text-align:center;">
                <p style="margin:0; color:#8a978d; font-size:12px; line-height:1.6;">Need help? Contact AgriDirect Support</p>
                <p style="margin:4px 0 0 0; color:#8a978d; font-size:11px; line-height:1.6;">© 2026 AgriDirect. All rights reserved.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
  `;
}

function buildSupportResolutionTemplate(name, subject, text) {
  const safeName = escapeHtml(name);
  const safeSubject = escapeHtml(subject);
  const safeText = escapeHtml(text);

  return `
<!doctype html>
<html>
  <body style="margin:0; padding:0; background:#edf3ee; font-family:Arial, Helvetica, sans-serif;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f3f7f4; padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="width:100%; max-width:600px; background:#ffffff; border:1px solid #d6e2d9; border-radius:16px; overflow:hidden;">
            <tr>
              <td style="height:6px; background:linear-gradient(90deg,#0f6c34,#2aa85a);"></td>
            </tr>
            <tr>
              <td style="padding:26px 28px 12px 28px; text-align:center;">
                <div style="font-size:34px; line-height:34px;">✅</div>
                <h1 style="margin:10px 0 0 0; color:#0f6c34; font-size:28px; font-weight:800; line-height:1.2;">Support Ticket Resolved</h1>
                <p style="margin:8px 0 0 0; color:#5f6f62; font-size:14px; line-height:1.5;">Hi ${safeName}, our support team has responded to your ticket.</p>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 28px 0 28px;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#eef9f1; border:1px solid #cfe7d5; border-radius:12px; font-size:14px; color:#1f3c29; line-height:1.6;">
                  <tr>
                    <td style="padding:18px 20px;">
                      <p style="margin:0 0 8px 0;"><strong>Ticket Subject:</strong> ${safeSubject}</p>
                      <hr style="border:0; border-top:1px solid #cfe7d5; margin:14px 0;" />
                      <p style="margin:0;"><strong>Support Team Response:</strong></p>
                      <p style="margin:6px 0 0 0; white-space:pre-wrap; background:#ffffff; padding:12px; border:1px solid #cfe7d5; border-radius:8px;">${safeText}</p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 28px 10px 28px; text-align:center;">
                <p style="margin:0; color:#5f6f62; font-size:12px; line-height:1.6;">If you have any further questions, please feel free to submit another request in the app.</p>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 28px 24px 28px; border-top:1px solid #edf2ee; text-align:center;">
                <p style="margin:0; color:#8a978d; font-size:11px; line-height:1.6;">© 2026 AgriDirect. All rights reserved.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
  `;
}

module.exports = async function handler(req, res) {
  setCors(req, res);

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed.' });
  }

  const origin = req.headers.origin || req.headers.referer;
  const appHeader = req.headers['x-agridirect-app'];

  // Block unauthorized origins
  if (origin && !isOriginAllowed(origin)) {
    return res.status(403).json({ error: 'Origin not allowed.' });
  }

  // Non-browser client check
  if (!origin && appHeader !== 'agridirect-client') {
    return res.status(403).json({ error: 'Unauthorized request client.' });
  }

  const email = normalizeEmail(req.body && req.body.email);
  if (!email || !email.includes('@')) {
    return res.status(400).json({ error: 'A valid email address is required.' });
  }

  // Enforce sliding window rate limit
  if (isRateLimited(email)) {
    return res.status(429).json({ error: 'Too many email requests for this address. Please wait a minute.' });
  }

  const gmailUser = cleanEnv(process.env.GMAIL_USER) || fallbackGmailUser;
  const gmailPass = cleanEnv(process.env.GMAIL_PASS);

  if (!gmailPass) {
    return res.status(500).json({ error: 'Email service password is not configured in server environment.' });
  }

  try {
    const type = req.body && req.body.type; // 'otp', 'alert' or 'resolution'
    const otpCode = req.body && req.body.otpCode;
    const userName = req.body && req.body.userName;
    const subjectLine = req.body && req.body.subject;
    const messageText = req.body && req.body.messageText;

    if (
      type !== 'otp' &&
      type !== 'password_reset' &&
      type !== 'alert' &&
      type !== 'resolution'
    ) {
      return res.status(400).json({ error: 'Invalid email type requested.' });
    }

    if ((type === 'otp' || type === 'password_reset') && (!otpCode || otpCode.length < 4)) {
      return res.status(400).json({ error: 'A valid OTP code is required.' });
    }

    if (type === 'resolution' && (!userName || !subjectLine || !messageText)) {
      return res.status(400).json({ error: 'Resolution email requires userName, subject, and messageText.' });
    }

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: gmailUser,
        pass: gmailPass,
      },
    });

    let subject = '';
    let html = '';
    let toEmail = email;
    let replyTo = undefined;

    const isReset =
      type === 'password_reset' ||
      (subjectLine && subjectLine.toLowerCase().includes('reset'));

    if (type === 'otp' || type === 'password_reset') {
      subject = isReset
          ? 'AgriDirect: Password Reset Request'
          : 'AgriDirect: Account Verification Code';
      html = buildHtmlTemplate(
        otpCode,
        isReset ? 'reset your password' : 'verify your account',
      );
    } else if (type === 'alert') {
      subject = 'AgriDirect: Your Password Was Changed';
      html = buildPasswordChangedTemplate();
    } else if (type === 'resolution') {
      subject = `AgriDirect Support: Update on "${subjectLine}"`;
      html = buildSupportResolutionTemplate(userName, subjectLine, messageText);
      toEmail = email; // Send directly to user
    }

    await transporter.sendMail({
      from: `"AgriDirect Support" <${gmailUser}>`,
      to: toEmail,
      replyTo: replyTo,
      subject: subject,
      html: html,
    });

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('[auth/send-email] failed', error);
    return res.status(500).json({ error: 'Unable to send email right now.' });
  }
};
