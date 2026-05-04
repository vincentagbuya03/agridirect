# Daily Weather Notification - Troubleshooting Guide

## **Issues Found**

### **1. ❌ Missing Cron Job (CRITICAL)**

**Problem:** The PostgreSQL cron schedule has never been created in your Supabase database.

**Location:** `supabase/migrations/20260502194000_setup_daily_weather_cron.sql` (just created)

**Fix Steps:**

1. Open the migration file and replace `<YOUR_SERVICE_ROLE_KEY>` with your actual Supabase service role key:
   - Go to Supabase Dashboard → Settings → API
   - Copy the **Service Role Key** (keep it secret!)
   - Paste it in the migration file
2. Deploy to Supabase:

   ```bash
   npx supabase migration push
   ```

3. Verify it worked:
   ```sql
   SELECT * FROM cron.job WHERE jobname = 'daily-farmer-weather-check';
   ```
   You should see one row with schedule `50 12 * * *`

---

### **2. ❌ Missing Environment Variable: OPENWEATHER_API_KEY**

**Problem:** The `daily-weather-check` Edge Function requires an OpenWeather API key.

**Fix Steps:**

1. Get an API key from [openweathermap.org](https://openweathermap.org/api)
   - Free tier provides 1,000 calls/day (sufficient for daily checks)
2. Set it in Supabase Dashboard:
   - Go to **Edge Functions** → **daily-weather-check** → **Configuration**
   - Add secret: `OPENWEATHER_API_KEY` = `your_key_here`
3. Redeploy the function:
   ```bash
   supabase functions deploy daily-weather-check
   ```

---

### **3. ⚠️ Row-Level Security (RLS) Blocking Notifications**

**Problem:** The function needs `INSERT` permission on `notifications` and `device_tokens` tables.

**Check Permissions:**

```sql
-- View RLS policies on notifications table
SELECT * FROM pg_policies WHERE tablename = 'notifications';

-- Ensure there's a policy allowing inserts for service_role:
-- SELECT * FROM notifications WHERE user_id = auth.uid();
```

**Fix if Needed:**
The `send-push-notification` function authenticates with the service role key, which should bypass RLS. If still failing, check logs:

```bash
supabase functions logs send-push-notification
```

---

### **4. ⚠️ Missing Farmer Coordinates**

**Problem:** If farmers lack `farm_latitude`/`farm_longitude`, the function defaults to coordinates in the Philippines (15.92°N, 120.35°E).

**Check:**

```sql
SELECT user_id, farm_name, farm_latitude, farm_longitude
FROM farmers
WHERE farm_latitude IS NULL OR farm_longitude IS NULL;
```

**Fix:**

- Update farmer profiles to include GPS coordinates
- Or ensure farmers set their location during registration/profile setup

---

## **Testing the Setup**

### **Manual Test 1: Trigger the Function**

```bash
# From your terminal
curl -X POST https://ywfppgarzyksacgbesme.supabase.co/functions/v1/daily-weather-check \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"
```

**Expected Response:**

```json
{ "success": true, "checked": 5 }
```

### **Manual Test 2: Check Function Logs**

```bash
supabase functions logs daily-weather-check
```

Look for entries like:

```
Found 5 farmers to check...
Sending weather_daily_summary to user123 for Green Farm
Push returned 200 for user...
```

### **Manual Test 3: Verify Notifications Saved**

```sql
SELECT * FROM notifications
WHERE created_at > now() - interval '1 hour'
ORDER BY created_at DESC;
```

---

## **Production Checklist**

- [ ] Cron job created and verified (`SELECT * FROM cron.job...`)
- [ ] `OPENWEATHER_API_KEY` secret set on `daily-weather-check` function
- [ ] At least 10 farmers in database with `is_active = true`
- [ ] Farmers have valid `farm_latitude` and `farm_longitude` (or defaults work for your region)
- [ ] `device_tokens` table has entries (users installed the app and enabled notifications)
- [ ] Scheduled time (12:50 UTC) is acceptable or adjusted in migration
- [ ] Run manual test — check logs and notifications table for success

---

## **Common Issues & Solutions**

| Issue                                 | Cause                             | Fix                                         |
| ------------------------------------- | --------------------------------- | ------------------------------------------- |
| Notifications never appear            | Cron job not created              | Deploy migration + replace service key      |
| "API Error" in logs                   | `OPENWEATHER_API_KEY` missing     | Add secret to Edge Function config          |
| "Invalid authorization token"         | Wrong/expired service role key    | Update migration + redeploy                 |
| "404 Not Found"                       | Incorrect Supabase URL            | Check URL in migration matches your project |
| Function timeout (>30s)               | Too many farmers (slow API calls) | Add batching or increase timeout            |
| Notifications saved but not delivered | FCM token invalid/expired         | App needs to refresh device tokens          |

---

## **Next Steps**

1. **Replace service role key** in the migration file
2. **Deploy migration:** `npx supabase migration push`
3. **Set OpenWeather API key** in Edge Function secrets
4. **Run manual test** to verify everything works
5. **Monitor logs** for the first scheduled run (12:50 UTC)
