import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "npm:@supabase/supabase-js@2"

const OPENWEATHER_API_KEY = Deno.env.get('OPENWEATHER_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const { lat, lon, city, userId, units = 'metric', type = 'current' } = await req.json()

    if (!lat && !lon && !city) {
      return new Response(JSON.stringify({ error: 'Location required' }), { status: 400 })
    }

    // 1. Fetch Weather Data
    const endpoint = type === 'forecast' ? 'forecast' : 'weather'
    let query = `units=${units}&appid=${OPENWEATHER_API_KEY}`
    if (city) query += `&q=${encodeURIComponent(city)}`
    else query += `&lat=${lat}&lon=${lon}`

    const response = await fetch(`https://api.openweathermap.org/data/2.5/${endpoint}?${query}`)
    const data = await response.json()

    if (!response.ok) return new Response(JSON.stringify({ error: 'API Error' }), { status: 400 })

    // 2. Alert Logic
    let isEmergency = false;
    let alertTitle = "Weather Advisory";
    let alertMessage = "";
    let alertCategory = "NORMAL";

    if (type === 'current') {
      const wind = data.wind?.speed || 0;
      const id = data.weather?.[0]?.id || 0;
      if (wind > 32 || id === 781) {
        isEmergency = true;
        alertCategory = "TYPHOON";
        alertTitle = "🌀 Typhoon Emergency";
        alertMessage = "URGENT: Typhoon conditions detected! Secure your farm immediately.";
      } else if (id >= 500 && id <= 531) {
        isEmergency = true;
        alertCategory = "RAIN";
        alertTitle = "🌧️ Rain Warning";
        alertMessage = "Rain detected. Check drainage and protect sensitive crops.";
      }
    } else {
      const forecast = data.list || [];
      const now = Date.now();
      for (let i = 0; i < Math.min(32, forecast.length); i++) {
        const f = forecast[i];
        const fid = f.weather?.[0]?.id || 0;
        const forecastTime = (f.dt || 0) * 1000;
        const hoursUntilForecast = (forecastTime - now) / (1000 * 60 * 60);
        const pop = Number(f.pop || 0);
        const rainVolume = Number(f.rain?.['3h'] || 0);
        const isNearTerm = hoursUntilForecast >= 0 && hoursUntilForecast <= 24;
        const isRainCode = fid >= 500 && fid <= 531;
        const isThunderstormCode = fid >= 200 && fid <= 232;
        const hasSignificantRain =
          rainVolume >= 1 ||
          pop >= 0.6 ||
          (isRainCode && pop >= 0.5) ||
          isThunderstormCode;

        if (isNearTerm && hasSignificantRain) {
          isEmergency = true;
          alertCategory = "ADVANCE_WARNING";
          alertTitle = "⚠️ Preparation Alert";
          alertMessage = `Upcoming rain detected. Plan your farm activities to minimize loss.`;
          break;
        }
      }
    }



    return new Response(
      JSON.stringify({
        ...data,
        agridirect_alerts: { is_emergency: isEmergency, title: alertTitle, message: alertMessage, category: alertCategory }
      }),
      { headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } }
    )
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
