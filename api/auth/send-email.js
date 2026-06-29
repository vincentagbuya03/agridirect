const nodemailer = require('nodemailer');

const fallbackGmailUser = 'noreplyagridirect@gmail.com';
const fallbackGmailPass = 'snoe apvj svld cank';

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

function buildHtmlTemplate(code, action) {
  const cleanCode = code.trim();
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

function buildPasswordChangedTemplate() {
  return `
<!doctype html>
<html>
  <body style="margin:0; padding:0; background:#edf3ee; font-family:Arial, Helvetica, sans-serif;">
    <div style="display:none; max-height:0; overflow:hidden; opacity:0; mso-hide:all;">Your AgriDirect password was changed.</div>
    <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f3f7f4; padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="width:100%; max-width:600px; background:#ffffff; border:1px solid #d6e2d9; border-radius:16px; overflow:hidden;">
            <tr>
              <td style="height:6px; background:linear-gradient(90deg,#0f6c34,#2aa85a);"></td>
            </tr>
            <tr>
              <td style="padding:26px 28px 12px 28px; text-align:center;">
                <div style="font-size:34px; line-height:34px;">🔒</div>
                <h1 style="margin:10px 0 0 0; color:#0f6c34; font-size:28px; font-weight:800; line-height:1.2;">Password Updated</h1>
                <p style="margin:8px 0 0 0; color:#5f6f62; font-size:14px; line-height:1.5;">Your AgriDirect password was successfully changed.</p>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 28px 0 28px;">
                <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#eef9f1; border:1px solid #cfe7d5; border-radius:12px;">
                  <tr>
                    <td style="padding:18px 20px; text-align:left;">
                      <p style="margin:0; color:#1f3c29; font-size:14px; line-height:1.6;">If this was you, no action is needed.</p>
                      <p style="margin:8px 0 0 0; color:#1f3c29; font-size:14px; line-height:1.6;">If this was not you, reset your password immediately and contact support.</p>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding:16px 28px 10px 28px;">
                <p style="margin:0; color:#6b7c70; font-size:12px; line-height:1.6;">This is an automated security alert from AgriDirect.</p>
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

  const gmailUser = cleanEnv(process.env.GMAIL_USER) || fallbackGmailUser;
  const gmailPass = cleanEnv(process.env.GMAIL_PASS) || fallbackGmailPass;

  try {
    const email = normalizeEmail(req.body && req.body.email);
    const type = req.body && req.body.type; // 'otp' or 'alert'
    const otpCode = req.body && req.body.otpCode;

    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'A valid email address is required.' });
    }

    if (type !== 'otp' && type !== 'alert') {
      return res.status(400).json({ error: 'Invalid email type requested.' });
    }

    if (type === 'otp' && (!otpCode || otpCode.length < 4)) {
      return res.status(400).json({ error: 'A valid OTP code is required.' });
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

    if (type === 'otp') {
      subject = 'AgriDirect: Account Verification Code';
      html = buildHtmlTemplate(otpCode, 'verify your account');
    } else {
      subject = 'AgriDirect: Your Password Was Changed';
      html = buildPasswordChangedTemplate();
    }

    await transporter.sendMail({
      from: `"AgriDirect Support" <${gmailUser}>`,
      to: email,
      subject: subject,
      html: html,
    });

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('[auth/send-email] failed', error);
    return res.status(500).json({ error: 'Unable to send email right now.' });
  }
};
