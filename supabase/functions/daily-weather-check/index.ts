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

function getCropLabel(specialty?: string | null): string {
  const cleaned = specialty?.trim()?.toLowerCase()
  if (!cleaned) return 'crops'
  if (
    cleaned.includes('crop') ||
    cleaned.includes('produce') ||
    cleaned.includes('plant') ||
    cleaned.includes('vegetable')
  ) {
    return cleaned
  }
  if (cleaned === 'organic') {
    return 'organic crops'
  }
  return `${cleaned} crops`
}

function getTimeLabel(targetDt: number): string {
  const diffMs = targetDt * 1000 - Date.now()
  const hours = Math.max(1, Math.round(diffMs / (1000 * 60 * 60)))
  if (hours <= 1) return 'within the next hour'
  if (hours < 24) return `in ${hours} hours`

  const days = Math.max(1, Math.round(hours / 24))
  return days === 1 ? 'tomorrow' : `in ${days} days`
}

function buildWeatherAlerts(
  forecastList: any[],
  farmName: string,
  specialty?: string | null,
): WeatherAlertPayload[] {
  const cropLabel = getCropLabel(specialty)
  const now = Date.now()
  const next72Hours = forecastList.filter((entry) => {
    const hoursAhead = ((entry.dt || 0) * 1000 - now) / (1000 * 60 * 60)
    return hoursAhead >= 0 && hoursAhead <= 72
  })

  if (next72Hours.length === 0) return []

  const next24h = next72Hours.filter((entry) => {
    const hoursAhead = ((entry.dt || 0) * 1000 - now) / (1000 * 60 * 60)
    return hoursAhead <= 24
  })

  const stormCandidate = next72Hours.find((entry) => {
    const weatherId = entry.weather?.[0]?.id || 0
    const windSpeed = Number(entry.wind?.speed || 0)
    return (weatherId >= 200 && weatherId <= 232) || windSpeed >= 35
  })

  const rainCandidate = next72Hours.find((entry) => {
    const weatherId = entry.weather?.[0]?.id || 0
    const pop = Number(entry.pop || 0)
    const rainVolume = Number(entry.rain?.['3h'] || 0)
    return (
      rainVolume >= 2 ||
      pop >= 0.65 ||
      ((weatherId >= 500 && weatherId <= 531) && pop >= 0.5)
    )
  })

  const maxTemp = next72Hours.reduce(
    (max, entry) => Math.max(max, Number(entry.main?.temp || -999)),
    -999,
  )
  const minTemp = next72Hours.reduce(
    (min, entry) => Math.min(min, Number(entry.main?.temp || 999)),
    999,
  )

  // Priority 1: Severe Storm Warning
  if (stormCandidate) {
    return [
      {
        title: '⚠️ Storm Warning',
        body: `Storm conditions expected ${getTimeLabel(stormCandidate.dt)} near ${farmName}. Secure loose farm structures, equipment, and protect mature ${cropLabel}.`,
        notificationCode: 'weather_storm',
        severity: 0.95,
      },
    ]
  }

  // Priority 2: Consolidated Rain & Harvest Advisory
  if (rainCandidate) {
    const popPercent = Math.round(Number(rainCandidate.pop || 0) * 100)
    const rainDesc = rainCandidate.weather?.[0]?.description || 'heavy rain'
    return [
      {
        title: '🌧️ Farm Rain Advisory',
        body: `Expect ${rainDesc} (${popPercent}% chance) ${getTimeLabel(rainCandidate.dt)} near ${farmName}. Check field drainage and harvest ripe ${cropLabel} early.`,
        notificationCode: 'weather_rain',
        severity: 0.85,
      },
    ]
  }

  // Priority 3: Extreme Heat / Cold Advisory
  if (maxTemp >= 36) {
    return [
      {
        title: '☀️ Heat Advisory',
        body: `High temperatures up to ${maxTemp.toFixed(0)}°C expected near ${farmName}. Water early and monitor ${cropLabel} for heat stress.`,
        notificationCode: 'weather_temperature',
        severity: 0.75,
      },
    ]
  } else if (minTemp <= 10) {
    return [
      {
        title: '❄️ Low Temperature Advisory',
        body: `Temperatures dropping near ${minTemp.toFixed(0)}°C expected around ${farmName}. Protect sensitive ${cropLabel} against cold shock.`,
        notificationCode: 'weather_temperature',
        severity: 0.75,
      },
    ]
  }

  // Priority 4: Standard Daily Weather Briefing
  if (next24h.length > 0) {
    const mainCondition = next24h[0].weather?.[0]?.description || 'clear skies'
    const highTemp = next24h.reduce(
      (max, e) => Math.max(max, Number(e.main?.temp || -999)),
      -999,
    )
    const maxPop = Math.max(...next24h.map((e) => Number(e.pop || 0)))
    const rainText =
      maxPop > 0.2
        ? `${Math.round(maxPop * 100)}% rain chance`
        : 'clear conditions'

    return [
      {
        title: '🌾 Daily Weather Update',
        body: `Forecast for ${farmName}: ${mainCondition} with a high of ${highTemp.toFixed(0)}°C (${rainText}). Wishing you a productive farming day!`,
        notificationCode: 'weather_daily_summary',
        severity: 0.5,
      },
    ]
  }

  return []
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
