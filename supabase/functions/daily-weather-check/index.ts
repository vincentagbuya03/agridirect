import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const OPENWEATHER_API_KEY = Deno.env.get('OPENWEATHER_API_KEY')

serve(async (req: Request) => {
  try {
    const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)

    // 1. Get all farmers (Using the 'farmers' table)
    // We'll also join with the users table to get the full name if needed
    const { data: farmers, error } = await supabase
      .from('farmers')
      .select('user_id, farm_name, birth_date')
      .eq('is_active', true)

    if (error) throw error

    console.log(`Found ${farmers.length} farmers to check...`)

    // NOTE: If your farmers don't have lat/lon in the database yet, 
    // we use San Carlos City as the default test location.
    const defaultLat = 15.9224;
    const defaultLon = 120.3489;

    for (const farmer of farmers) {
      const { user_id, farm_name } = farmer

      // 2. Check weather (Using farmer location or San Carlos City as fallback)
      const weatherUrl = `https://api.openweathermap.org/data/2.5/forecast?lat=${defaultLat}&lon=${defaultLon}&units=metric&appid=${OPENWEATHER_API_KEY}`
      const weatherRes = await fetch(weatherUrl)
      const weatherData = await weatherRes.json()

      if (!weatherRes.ok) continue

      // 3. Scan for any rain
      let rainDetected = false
      const forecastList = weatherData.list || []
      for (let i = 0; i < 8; i++) {
        const id = forecastList[i].weather?.[0]?.id || 0
        if (id >= 500 && id <= 531) {
          rainDetected = true
          break
        }
      }

      // 4. Trigger Push Notification
      if (rainDetected) {
        console.log(`Notifying farmer for farm: ${farm_name}...`)
        await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
          },
          body: JSON.stringify({
            targetUserId: user_id,
            title: "🌦️ Farm Weather Alert",
            body: `Hello from AgriDirect! Rain is expected at ${farm_name} today. Please take necessary precautions.`,
            notificationCode: 'daily_weather'
          })
        }).catch(e => console.error("Push failed:", e))
      }
    }

    return new Response(JSON.stringify({ success: true, checked: farmers.length }), {
      headers: { 'Content-Type': 'application/json' }
    })

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
