# Supabase Password Reset Configuration

To make password reset work properly, you need to configure your Supabase project settings.

## 1. Configure Site URL

1. Go to your Supabase Dashboard: https://app.supabase.com
2. Select your project
3. Go to **Authentication** → **URL Configuration**
4. Set the **Site URL** to your production URL:
   - Production: `https://yourdomain.vercel.app`
   - Development: `http://localhost:XXXX` (your local port)

## 2. Add Redirect URLs

In the same **URL Configuration** section, add these to **Redirect URLs**:

```
https://yourdomain.vercel.app/reset-password
https://yourdomain.vercel.app/**
http://localhost:*/reset-password
http://localhost:**
```

Replace `yourdomain.vercel.app` with your actual Vercel domain.

## 3. Configure Email Templates

1. Go to **Authentication** → **Email Templates**
2. Select **Reset Password**
3. Make sure the email template includes the correct redirect URL
4. The default template should work, but verify it contains: `{{ .ConfirmationURL }}`

## 4. Test the Flow

1. Click "Forgot Password?" on login screen
2. Enter your email address
3. Check your email for the reset link
4. Click the link (should redirect to `/reset-password`)
5. Enter new password
6. You should be redirected to login

## Common Issues

### "Auth session missing" error
- Make sure you clicked the link from the email
- Check that Site URL and Redirect URLs are configured correctly
- The reset link expires after 1 hour by default

### Link redirects to wrong URL
- Verify Site URL in Supabase dashboard matches your app URL
- Clear browser cache and try again

### Email not received
- Check spam folder
- Verify email provider settings in Supabase
- Check Supabase logs for email delivery errors

## Production Deployment

When deploying to production:
1. Update Site URL to your production domain
2. Add production domain to Redirect URLs
3. Test the full flow on production
4. Consider customizing email templates with your branding
