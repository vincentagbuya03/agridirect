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

async function generateAiWeatherAlert(
  envKeys: {
    geminiKey?: string
    groqKey?: string
    openRouterKey?: string
  },
  farmName: string,
  specialty: string | null | undefined,
  baseAlert: WeatherAlertPayload,
  weatherSummary: {
    temp: number
    condition: string
    rainProb: number
    windSpeed: number
  },
): Promise<WeatherAlertPayload> {
  const cropLabel = specialty && specialty.trim().length > 0 ? specialty.trim() : 'crops & vegetables'
  const rainPct = Math.round(weatherSummary.rainProb * 100)

  const prompt = `You are Kiko, the AI Agricultural & Weather Advisor for AgriDirect (Philippines).
Generate a concise, smart, and dynamic weather push notification tailored specifically for Filipino farmers in "${farmName}".

Live Weather Telemetry:
- Location / Farm: "${farmName}" (Pangasinan, Philippines)
- Target Crop / Produce: "${cropLabel}"
- Current Condition: ${weatherSummary.condition}
- Temperature: ${weatherSummary.temp.toFixed(1)}°C
- Rain Probability: ${rainPct}%
- Wind Speed: ${weatherSummary.windSpeed.toFixed(1)} km/h
- Alert Context: ${baseAlert.notificationCode} (${baseAlert.title})

Requirements:
1. Title format: Must start with "🤖 Weather AI:" or "🌾 Weather AI:" followed by emojis (e.g. "🌾 Weather AI: 🌧️ Rain in 2 hrs", "🤖 Weather AI: 🌀 Bagyo Alert", "🌾 Weather AI: ☀️ High Heat Warning"). Max 45 characters.
2. Body format: 1-2 practical, high-impact sentences for mobile lock screen (Max 140 characters). Mention actual metrics (${rainPct}% rain or ${weatherSummary.temp.toFixed(0)}°C) and clear crop action for ${cropLabel} (e.g., clear field canals, delay spraying, harvest early, irrigate early).
3. Return STRICTLY valid JSON without codeblocks: {"title": "...", "body": "..."}`

  // 1. Primary: OpenRouter AI
  if (envKeys.openRouterKey && envKeys.openRouterKey.trim() !== '') {
    const openRouterModels = [
      'meta-llama/llama-3.3-70b-instruct:free',
      'meta-llama/llama-3.1-8b-instruct:free',
      'google/gemini-2.0-flash-exp:free',
      'deepseek/deepseek-r1:free',
      'qwen/qwen-2.5-72b-instruct:free',
      'mistralai/mistral-7b-instruct:free',
      'openrouter/auto',
    ]

    for (const model of openRouterModels) {
      try {
        const controller = new AbortController()
        const timeoutId = setTimeout(() => controller.abort(), 6000)

        const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${envKeys.openRouterKey.trim()}`,
            'HTTP-Referer': 'https://agridirect.app',
            'X-Title': 'AgriDirect Weather Advisor',
          },
          body: JSON.stringify({
            model,
            messages: [
              { role: 'system', content: 'You are Kiko, an expert AI Agricultural Advisor for Filipino farmers. You always reply strictly in JSON.' },
              { role: 'user', content: prompt },
            ],
            temperature: 0.5,
            max_tokens: 150,
          }),
          signal: controller.signal,
        })
        clearTimeout(timeoutId)

        if (response.ok) {
          const data = await response.json()
          let rawContent = data.choices?.[0]?.message?.content?.trim() || ''
          if (rawContent.startsWith('```json')) {
            rawContent = rawContent.replace(/^```json/, '').replace(/```$/, '').trim()
          } else if (rawContent.startsWith('```')) {
            rawContent = rawContent.replace(/^```/, '').replace(/```$/, '').trim()
          }

          const parsed = JSON.parse(rawContent)
          if (parsed.title && parsed.body) {
            return {
              title: String(parsed.title).trim(),
              body: String(parsed.body).trim(),
              notificationCode: baseAlert.notificationCode,
              severity: baseAlert.severity,
            }
          }
        }
      } catch (err) {
        console.warn(`[OpenRouter (${model})]:`, err)
      }
    }
  }

  // 2. Intelligent AI-Style Template fallback if OpenRouter is unreachable
  const isRain = baseAlert.notificationCode.includes('rain')
  const isStorm = baseAlert.notificationCode.includes('storm') || baseAlert.notificationCode.includes('typhoon')
  const isHeat = baseAlert.notificationCode.includes('heat') || baseAlert.notificationCode.includes('temp')

  if (isStorm) {
    return {
      title: '🤖 Weather AI: 🌀 Bagyo & Storm Alert',
      body: `Storm telemetry detected near ${farmName} (${Math.round(weatherSummary.windSpeed)} km/h winds). Clear canals and secure ${cropLabel} immediately.`,
      notificationCode: baseAlert.notificationCode,
      severity: baseAlert.severity,
    }
  } else if (isRain) {
    return {
      title: '🌾 Weather AI: 🌧️ Rain Advisory',
      body: `AI detects ${rainPct}% rain probability (${weatherSummary.condition}) near ${farmName}. Check drainage and harvest ripe ${cropLabel} early.`,
      notificationCode: baseAlert.notificationCode,
      severity: baseAlert.severity,
    }
  } else if (isHeat) {
    return {
      title: '🌾 Weather AI: ☀️ High Heat Advisory',
      body: `Forecast peaks at ${weatherSummary.temp.toFixed(0)}°C near ${farmName}. Irrigate early morning to prevent heat stress on ${cropLabel}.`,
      notificationCode: baseAlert.notificationCode,
      severity: baseAlert.severity,
    }
  }

  return {
    title: '🌾 Weather AI: Daily Farm Briefing',
    body: `${farmName}: ${weatherSummary.condition}, ${weatherSummary.temp.toFixed(0)}°C with ${rainPct}% rain chance. Good conditions for ${cropLabel} maintenance.`,
    notificationCode: baseAlert.notificationCode,
    severity: baseAlert.severity,
  }
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

  const typhoonCandidate = next72Hours.find((entry) => {
    const weatherId = entry.weather?.[0]?.id || 0
    const windSpeedMps = Number(entry.wind?.speed || 0)
    const windSpeedKmh = windSpeedMps * 3.6
    const desc = (entry.weather?.[0]?.description || '').toLowerCase()
    return (
      desc.includes('typhoon') ||
      desc.includes('cyclone') ||
      desc.includes('tropical storm') ||
      desc.includes('squall') ||
      desc.includes('gale') ||
      (weatherId >= 200 && weatherId <= 232) ||
      windSpeedKmh >= 45 ||
      windSpeedMps >= 12.5
    )
  })

  const rainCandidate = next72Hours.find((entry) => {
    const weatherId = entry.weather?.[0]?.id || 0
    const pop = Number(entry.pop || 0)
    const rainVolume = Number(entry.rain?.['3h'] || 0)
    return (
      rainVolume >= 2 ||
      pop >= 0.60 ||
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

  // Priority 1: Typhoon / Severe Tropical Storm Warning
  if (typhoonCandidate) {
    const windKmh = Math.round(Number(typhoonCandidate.wind?.speed || 0) * 3.6)
    const isTyphoon =
      (typhoonCandidate.weather?.[0]?.description || '').toLowerCase().includes('typhoon') ||
      windKmh >= 60
    return [
      {
        title: isTyphoon ? '🌀 Typhoon Warning' : '⚠️ Severe Storm Warning',
        body: `${isTyphoon ? 'Typhoon alert' : 'Severe storm & strong winds'} (${windKmh} km/h) expected ${getTimeLabel(typhoonCandidate.dt)} near ${farmName}. Secure farm structures, verify drainage, and safeguard ${cropLabel}.`,
        notificationCode: 'weather_storm',
        severity: 0.99,
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
    const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY')
    const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY')
    const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY')

    const aiEnvKeys = {
      geminiKey: GEMINI_API_KEY,
      groqKey: GROQ_API_KEY,
      openRouterKey: OPENROUTER_API_KEY,
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !OPENWEATHER_API_KEY) {
      throw new Error('Missing required weather function environment variables.')
    }

    let reqBody: any = {}
    try {
      reqBody = await request.json()
    } catch (_) {}

    // Direct AI generation endpoint for Admin Push Studio and App preview
    if (reqBody?.mode === 'generate_weather_ai') {
      const summaryMetrics = {
        temp: Number(reqBody.temp ?? 28),
        condition: String(reqBody.condition ?? 'Partly Cloudy'),
        rainProb: Number(reqBody.rainProb ?? 0.2),
        windSpeed: Number(reqBody.windSpeed ?? 10),
      }
      const baseAlert: WeatherAlertPayload = {
        title: reqBody.title ?? '🌾 Weather Advisory',
        body: reqBody.body ?? 'Stay prepared for current farm conditions.',
        notificationCode: reqBody.notificationCode ?? 'weather_daily_summary',
        severity: Number(reqBody.severity ?? 0.6),
      }

      const generated = await generateAiWeatherAlert(
        aiEnvKeys,
        reqBody.farmName ?? 'your farm',
        reqBody.specialty ?? 'High-value crops',
        baseAlert,
        summaryMetrics,
      )

      return new Response(JSON.stringify(generated), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
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

      const rawAlerts = buildWeatherAlerts(
        weatherData.list || [],
        farmName,
        farmer.specialty,
      )

      console.log(`[daily-weather-check] ${rawAlerts.length} raw alerts generated for ${farmName} (user: ${farmer.user_id})`)

      const firstForecast = weatherData.list?.[0] || {}
      const summaryMetrics = {
        temp: Number(firstForecast.main?.temp ?? 28),
        condition: firstForecast.weather?.[0]?.description ?? 'partly cloudy',
        rainProb: Number(firstForecast.pop ?? 0),
        windSpeed: Number(firstForecast.wind?.speed ?? 10),
      }

      for (const baseAlert of rawAlerts) {
        // Enhance with multi-model AI (Gemini, Groq, OpenRouter)
        const alert = await generateAiWeatherAlert(
          aiEnvKeys,
          farmName,
          farmer.specialty,
          baseAlert,
          summaryMetrics,
        )

        let weatherImage = 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=600&auto=format&fit=crop&q=80'
        if (alert.notificationCode?.includes('storm') || alert.notificationCode?.includes('typhoon')) {
          weatherImage = 'https://images.unsplash.com/photo-1527482797697-8795b05a13fe?w=600&auto=format&fit=crop&q=80'
        } else if (alert.notificationCode?.includes('rain')) {
          weatherImage = 'https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?w=600&auto=format&fit=crop&q=80'
        } else if (alert.notificationCode?.includes('heat')) {
          weatherImage = 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=600&auto=format&fit=crop&q=80'
        }

        console.log(`[daily-weather-check] Triggering push: ${alert.notificationCode} -> ${farmer.user_id} | Title: "${alert.title}" | Body: "${alert.body}"`)
        
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
            imageUrl: weatherImage,
            notificationCode: alert.notificationCode,
            linkType: 'weather',
            data: {
              category: 'weather',
              farm_name: farmName,
              specialty: farmer.specialty || '',
              ai_generated: 'openrouter',
              image_url: weatherImage,
            },
          }),
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
