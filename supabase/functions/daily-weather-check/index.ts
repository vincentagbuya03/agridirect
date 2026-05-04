import { createClient } from "npm:@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}



type FarmerRow = {
  user_id: string
  farm_name: string | null
  specialty: string | null
  farm_latitude: number | null
  farm_longitude: number | null
}

type WeatherAlertPayload = {
  title: string
  body: string
  notificationCode: string
  severity: number
}

function getCropLabel(specialty?: string | null) {
  const cleaned = specialty?.trim()
  return cleaned && cleaned.length > 0 ? cleaned.toLowerCase() : 'crops'
}

function getTimeLabel(targetDt: number) {
  const diffMs = targetDt * 1000 - Date.now()
  const hours = Math.max(1, Math.round(diffMs / (1000 * 60 * 60)))
  if (hours < 24) return `within ${hours} hours`

  const days = Math.max(1, Math.round(hours / 24))
  return days == 1 ? 'tomorrow' : `in ${days} days`
}

function buildWeatherAlerts(
  forecastList: any[],
  farmName: string,
  specialty?: string | null,
): WeatherAlertPayload[] {
  const alerts: WeatherAlertPayload[] = []
  const cropLabel = getCropLabel(specialty)
  const now = Date.now()
  const next72Hours = forecastList.filter((entry) => {
    const hoursAhead = ((entry.dt || 0) * 1000 - now) / (1000 * 60 * 60)
    return hoursAhead >= 0 && hoursAhead <= 72
  })

  // 1. Daily Summary (Always sent)
  const next24h = next72Hours.filter((entry) => {
    const hoursAhead = ((entry.dt || 0) * 1000 - now) / (1000 * 60 * 60)
    return hoursAhead <= 24
  })

  if (next24h.length > 0) {
    const mainCondition = next24h[0].weather?.[0]?.description || 'clear'
    const highTemp = next24h.reduce((max, e) => Math.max(max, Number(e.main?.temp || -999)), -999)
    const maxPop = Math.max(...next24h.map((e) => Number(e.pop || 0)))

    alerts.push({
      title: 'Daily Weather Update',
      body: `Forecast for ${farmName}: ${mainCondition} with a high of ${highTemp.toFixed(0)}°C. ${
        maxPop > 0.1 ? `Rain chance: ${(maxPop * 100).toFixed(0)}%.` : 'Clear skies expected.'
      } Happy farming!`,
      notificationCode: 'weather_daily_summary',
      severity: 0.5,
    })
  }

  // 2. Severe Alerts
  const rainCandidate = next72Hours.find((entry) => {
    const weatherId = entry.weather?.[0]?.id || 0
    const pop = Number(entry.pop || 0)
    const rainVolume = Number(entry.rain?.['3h'] || 0)
    return rainVolume >= 2 || pop >= 0.65 || ((weatherId >= 500 && weatherId <= 531) && pop >= 0.5)
  })

  if (rainCandidate) {
    alerts.push({
      title: 'Farm Rain Alert',
      body: `Heavy rainfall expected ${getTimeLabel(rainCandidate.dt)} near ${farmName}. Protect your ${cropLabel} and keep drainage clear.`,
      notificationCode: 'weather_rain',
      severity: 0.78,
    })
  }

  const stormCandidate = next72Hours.find((entry) => {
    const weatherId = entry.weather?.[0]?.id || 0
    const windSpeed = Number(entry.wind?.speed || 0)
    return (weatherId >= 200 && weatherId <= 232) || windSpeed >= 35
  })

  if (stormCandidate) {
    alerts.push({
      title: 'Storm Warning',
      body: `Storm conditions expected ${getTimeLabel(stormCandidate.dt)} near ${farmName}. Secure structures, tools, and exposed produce.`,
      notificationCode: 'weather_storm',
      severity: 0.92,
    })
  }

  const maxTemp = next72Hours.reduce(
    (max, entry) => Math.max(max, Number(entry.main?.temp || -999)),
    -999,
  )
  const minTemp = next72Hours.reduce(
    (min, entry) => Math.min(min, Number(entry.main?.temp || 999)),
    999,
  )

  if (maxTemp >= 36) {
    alerts.push({
      title: 'Temperature Monitoring',
      body: `High temperatures up to ${maxTemp.toFixed(1)}C are expected near ${farmName}. Watch for heat stress on your ${cropLabel}.`,
      notificationCode: 'weather_temperature',
      severity: maxTemp >= 39 ? 0.85 : 0.7,
    })
  } else if (minTemp <= 6) {
    alerts.push({
      title: 'Temperature Monitoring',
      body: `Low temperatures near ${minTemp.toFixed(1)}C are expected around ${farmName}. Protect sensitive ${cropLabel} if needed.`,
      notificationCode: 'weather_temperature',
      severity: minTemp <= 3 ? 0.85 : 0.7,
    })
  }

  const harvestRiskCandidate = next72Hours.find((entry) => {
    const weatherId = entry.weather?.[0]?.id || 0
    const pop = Number(entry.pop || 0)
    const rainVolume = Number(entry.rain?.['3h'] || 0)
    const windSpeed = Number(entry.wind?.speed || 0)
    return rainVolume >= 2 || pop >= 0.65 || windSpeed >= 28 || (weatherId >= 200 && weatherId <= 232)
  })

  if (harvestRiskCandidate) {
    alerts.push({
      title: 'Harvest Risk Alert',
      body: `Harvest conditions may worsen ${getTimeLabel(harvestRiskCandidate.dt)} near ${farmName}. Prioritize mature ${cropLabel} first.`,
      notificationCode: 'weather_harvest_risk',
      severity: 0.8,
    })
  }

  const deduped = new Map<string, WeatherAlertPayload>()
  for (const alert of alerts) {
    deduped.set(alert.notificationCode, alert)
  }

  return Array.from(deduped.values()).sort((a, b) => b.severity - a.severity)
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const OPENWEATHER_API_KEY = Deno.env.get('OPENWEATHER_API_KEY')

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !OPENWEATHER_API_KEY) {
      throw new Error('Missing required weather function environment variables.')
    }

    const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)

    const { data: farmers, error } = await supabase
      .from('farmers')
      .select('user_id, farm_name, specialty, farm_latitude, farm_longitude')
      .eq('is_active', true)

    if (error) throw error
    const farmerRows = (farmers ?? []) as FarmerRow[]

    console.log(`[daily-weather-check] Found ${farmerRows.length} active farmers to check...`)

    const defaultLat = 15.9224
    const defaultLon = 120.3489

    let sentCount = 0
    let errorCount = 0

    for (const farmer of farmerRows) {
      const farmName = farmer.farm_name?.trim() || 'your farm'
      const lat = farmer.farm_latitude ?? defaultLat
      const lon = farmer.farm_longitude ?? defaultLon

      const weatherUrl = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&units=metric&appid=${OPENWEATHER_API_KEY}`
      const weatherRes = await fetch(weatherUrl)
      const weatherData = await weatherRes.json()

      if (!weatherRes.ok) {
        console.error(`Weather request failed for ${farmName}:`, weatherData)
        errorCount++
        continue
      }

      const alerts = buildWeatherAlerts(
        weatherData.list || [],
        farmName,
        farmer.specialty,
      )

      console.log(`[daily-weather-check] ${alerts.length} alerts generated for ${farmName} (user: ${farmer.user_id})`)

      for (const alert of alerts) {
        console.log(`[daily-weather-check] Triggering push: ${alert.notificationCode} -> ${farmer.user_id}`)
        
        // Use manual fetch with apikey header to ensure it passes the Supabase Gateway correctly
        const pushResponse = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'apikey': SUPABASE_SERVICE_ROLE_KEY!
          },
          body: JSON.stringify({
            targetUserId: farmer.user_id,
            title: alert.title,
            body: alert.body,
            notificationCode: alert.notificationCode,
            linkType: 'weather',
            data: {
              category: 'weather',
              farm_name: farmName,
            },
          })
        })

        if (!pushResponse.ok) {
          const errorText = await pushResponse.text().catch(() => 'No error body')
          console.error(`[daily-weather-check] Push failed (${pushResponse.status}): ${errorText}`)
          errorCount++
        } else {
          const result = await pushResponse.json().catch(() => ({}))
          console.log(`[daily-weather-check] Push success:`, result)
          sentCount++
        }
      }
    }

    console.log(`[daily-weather-check] Complete. Checked: ${farmerRows.length}, Sent: ${sentCount}, Errors: ${errorCount}`)

    return new Response(JSON.stringify({
      success: true,
      checked: farmerRows.length,
      sent: sentCount,
      errors: errorCount,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error: any) {
    console.error('[daily-weather-check] Fatal error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
