// deno-lint-ignore-file no-explicit-any
import nodemailer from 'npm:nodemailer@6.9.9';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function buildEmailHtml(otpCode: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>AgriDirect Verification Code</title>
</head>
<body style="margin:0;padding:0;background-color:#F0FDF4;font-family:'DM Sans',Arial,sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#F0FDF4;padding:40px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" style="max-width:520px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(21,128,61,0.10);">

          <!-- Header -->
          <tr>
            <td style="background:#15803D;padding:32px 40px;text-align:center;">
              <p style="margin:0 0 4px 0;font-size:11px;font-weight:600;letter-spacing:3px;text-transform:uppercase;color:#86EFAC;">AGRIDIRECT</p>
              <h1 style="margin:0;font-size:26px;font-weight:700;color:#ffffff;letter-spacing:-0.5px;">Email Verification</h1>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:40px 40px 32px;">
              <p style="margin:0 0 8px;font-size:16px;font-weight:600;color:#14532D;">Hello there,</p>
              <p style="margin:0 0 28px;font-size:15px;line-height:1.6;color:#166534;">
                Use the verification code below to confirm your AgriDirect account.
                This code expires in <strong style="color:#14532D;">10 minutes</strong>.
              </p>

              <!-- OTP Box -->
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-bottom:28px;">
                <tr>
                  <td align="center" style="background:#F0FDF4;border:2px solid #22C55E;border-radius:12px;padding:28px 24px;">
                    <p style="margin:0 0 6px;font-size:11px;font-weight:600;letter-spacing:2px;text-transform:uppercase;color:#15803D;">Your verification code</p>
                    <span style="font-size:42px;font-weight:700;letter-spacing:12px;color:#CA8A04;font-family:'DM Sans',Arial,sans-serif;">${otpCode}</span>
                  </td>
                </tr>
              </table>

              <!-- Security note -->
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-bottom:24px;">
                <tr>
                  <td style="background:#FEF9C3;border-left:4px solid #CA8A04;border-radius:0 8px 8px 0;padding:14px 16px;">
                    <p style="margin:0;font-size:13px;line-height:1.5;color:#713F12;">
                      <strong>Security tip:</strong> AgriDirect will never ask for this code by phone or message. Do not share it with anyone.
                    </p>
                  </td>
                </tr>
              </table>

              <p style="margin:0;font-size:14px;line-height:1.6;color:#4B7A5A;">
                If you did not request this code, you can safely ignore this email. Your account remains secure.
              </p>
            </td>
          </tr>

          <!-- Divider -->
          <tr>
            <td style="padding:0 40px;">
              <hr style="border:none;border-top:1px solid #DCFCE7;margin:0;" />
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:24px 40px;text-align:center;">
              <p style="margin:0 0 4px;font-size:12px;color:#86EFAC;font-weight:600;letter-spacing:1px;text-transform:uppercase;">AgriDirect</p>
              <p style="margin:0;font-size:12px;color:#A3C4A8;line-height:1.5;">
                Connecting farmers and consumers across the Philippines.<br/>
                This is an automated message — please do not reply.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { to, otpCode } = await req.json() as { to: string; otpCode: string };

    if (!to || !otpCode) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: to, otpCode' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const gmailUser = Deno.env.get('GMAIL_USER');
    const gmailAppPassword = Deno.env.get('GMAIL_APP_PASSWORD');

    if (!gmailUser || !gmailAppPassword) {
      return new Response(
        JSON.stringify({ error: 'Gmail credentials not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const transporter = nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 465,
      secure: true,
      auth: {
        user: gmailUser,
        pass: gmailAppPassword,
      },
    });

    await transporter.sendMail({
      from: `"AgriDirect" <${gmailUser}>`,
      to,
      subject: `${otpCode} is your AgriDirect verification code`,
      text: `Your AgriDirect verification code is: ${otpCode}\n\nThis code expires in 10 minutes.\n\nIf you did not request this code, please ignore this email.`,
      html: buildEmailHtml(otpCode),
    });

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    console.error('[send-email] Error:', error);
    return new Response(
      JSON.stringify({ error: 'Failed to send email' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
