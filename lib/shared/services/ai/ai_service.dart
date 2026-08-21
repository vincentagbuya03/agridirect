import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/supabase_config.dart';

enum AiProvider { groq, openRouter }

/// AI Service for AgriDirect powered by Groq & OpenRouter free-tier vision & text models.
class AiService {
  static const String _defaultOpenRouterKey = '';

  static const String groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');

  static String runtimeOpenRouterKey = '';
  static String runtimeGroqKey = '';

  static String get effectiveOpenRouterKey {
    if (runtimeOpenRouterKey.isNotEmpty) return runtimeOpenRouterKey;
    if (openRouterApiKey.isNotEmpty) return openRouterApiKey;
    final envVal = dotenv.env['OPENROUTER_API_KEY'];
    if (envVal != null && envVal.trim().isNotEmpty) return envVal.trim();
    return _defaultOpenRouterKey;
  }

  static String get effectiveGroqKey =>
      runtimeGroqKey.isNotEmpty
          ? runtimeGroqKey
          : (groqApiKey.isNotEmpty
              ? groqApiKey
              : (dotenv.env['GROQ_API_KEY'] ?? ''));

  static String get effectiveGeminiKey =>
      dotenv.env['GEMINI_API_KEY'] ??
      const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  final AiProvider provider;
  final String apiKey;

  AiService({AiProvider? provider, String? apiKey})
      : provider = provider ??
            (apiKey?.startsWith('sk-or-') == true || effectiveOpenRouterKey.isNotEmpty
                ? AiProvider.openRouter
                : AiProvider.groq),
        apiKey = apiKey ??
            ((provider == AiProvider.openRouter)
                ? effectiveOpenRouterKey
                : effectiveGroqKey);

  /// System prompt tailored for AgriDirect agricultural context.
  static const String _systemPrompt = '''
You are Kiko, the friendly and knowledgeable Carabao AI Agricultural Advisor for AgriDirect (an agricultural marketplace in the Philippines connecting local farmers directly with consumers).

Your responsibilities:
1. When given an image of a crop, grain, leaf, pest, or vegetable:
   - Accurately identify what is shown in the image (e.g. rice grains, tomato leaf, eggplant, cabbage, fertilizer, pest, cooked rice, seed).
   - Diagnose any visible diseases, pests, fungal infections, nutrient deficiencies, or cooking/storage condition.
   - Provide clear, actionable organic and conventional solutions suitable for Filipino farmers and home growers.
2. Provide practical farming advice (soil conditioning, organic fertilizers like vermicast/neem oil, planting schedules, irrigation).
3. Keep answers concise, helpful, friendly, and structured with bullet points.
4. Use friendly carabao emojis (🐮, 🌾, 🌱) and natural Taglish (Tagalog/English) when appropriate.
''';

  Map<String, String> _buildHeaders({bool forceOpenRouter = false}) {
    final useOpenRouter = forceOpenRouter || provider == AiProvider.openRouter;
    final activeKey = useOpenRouter
        ? effectiveOpenRouterKey
        : (apiKey.isNotEmpty ? apiKey : effectiveGroqKey);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $activeKey',
    };
    if (useOpenRouter) {
      headers['HTTP-Referer'] = 'https://agridirect.app';
      headers['X-Title'] = 'AgriDirect';
    }
    return headers;
  }

  /// General chat with automatic model fallback cascade.
  Future<String> getChatResponse({
    required List<Map<String, String>> conversationHistory,
    String? userPrompt,
    String? model,
    double temperature = 0.7,
  }) async {
    final List<Map<String, dynamic>> messages = [
      {'role': 'system', 'content': _systemPrompt},
      ...conversationHistory,
    ];

    if (userPrompt != null && userPrompt.trim().isNotEmpty) {
      messages.add({'role': 'user', 'content': userPrompt.trim()});
    }

    // 1. Try Groq fast chat models first
    final groqModels = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];
    for (final currentModel in groqModels) {
      try {
        final response = await http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $groqApiKey',
          },
          body: jsonEncode({
            'model': currentModel,
            'messages': messages,
            'temperature': temperature,
            'max_tokens': 1024,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final content = data['choices']?[0]?['message']?['content'] as String?;
          if (content != null && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      } catch (e) {
        debugPrint('Groq chat error on $currentModel: $e');
      }
    }

    // 2. Try OpenRouter free models fallback
    final openRouterModels = [
      'nvidia/nemotron-nano-12b-v2-vl:free',
      'google/gemma-4-26b-a4b-it:free',
      'google/gemma-4-31b-it:free',
      'openai/gpt-oss-20b:free',
    ];

    for (final currentModel in openRouterModels) {
      try {
        final response = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: _buildHeaders(forceOpenRouter: true),
          body: jsonEncode({
            'model': currentModel,
            'messages': messages,
            'temperature': temperature,
            'max_tokens': 1024,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final content = data['choices']?[0]?['message']?['content'] as String?;
          if (content != null && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      } catch (e) {
        debugPrint('OpenRouter chat error on $currentModel: $e');
      }
    }

    return 'Moo! 🌾 Paumanhin, medyo mabagal ang koneksyon ngayon. Maaari mong subukang muli o pumili ng isa sa mga quick topics sa ibaba!';
  }

  /// One-shot quick agricultural question.
  Future<String> askQuickQuestion(String question, {String? model}) async {
    return getChatResponse(
      conversationHistory: [],
      userPrompt: question,
      model: model,
    );
  }

  /// Analyze a crop, leaf, grain, or pest image using Vision AI.
  Future<String> diagnoseCropImage({
    required Uint8List imageBytes,
    String? additionalNotes,
    String? model,
  }) async {
    final base64Image = base64Encode(imageBytes);
    final promptText = additionalNotes != null && additionalNotes.trim().isNotEmpty
        ? 'Please analyze this agricultural image and diagnose the crop, plant, grain, or pest shown. User notes: $additionalNotes'
        : 'Please examine this agricultural image. Identify the crop/plant/grain shown, detect any disease, pest, deficiency, or quality issue, and provide practical organic & farming recommendations for Filipino farmers.';

    // OpenRouter Free Vision Models currently active
    final openRouterVisionModels = model != null
        ? [model]
        : [
            'nvidia/nemotron-nano-12b-v2-vl:free',
          ];

    for (final visionModel in openRouterVisionModels) {
      try {
        final response = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: _buildHeaders(forceOpenRouter: true),
          body: jsonEncode({
            'model': visionModel,
            'messages': [
              {'role': 'system', 'content': _systemPrompt},
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': promptText},
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/jpeg;base64,$base64Image',
                    },
                  },
                ],
              },
            ],
            'temperature': 0.4,
            'max_tokens': 1024,
          }),
        );

        debugPrint('Vision API response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final content = data['choices']?[0]?['message']?['content'] as String?;
          if (content != null && content.trim().isNotEmpty) {
            return content.trim();
          }
        } else {
          debugPrint('Vision API error body: ${response.body}');
        }
      } catch (e) {
        debugPrint('Error calling vision model $visionModel: $e');
      }
    }

    return 'Moo! 🌾 Hindi ma-proseso ang larawan sa kasalukuyan. Siguraduhing malinaw ang kuha ng dahon o pananim at subukang muli!';
  }

  /// Generate a smart agronomic weather push notification description via OpenRouter AI.
  Future<Map<String, String>> generateWeatherPush({
    required String farmName,
    String? specialty,
    required String condition,
    required double temperature,
    required double rainProbability,
    required double windSpeed,
    String? alertType,
    String? targetAudience,
  }) => generateWeatherPushDescription(
    farmName: farmName,
    specialty: specialty,
    condition: condition,
    temperature: temperature,
    rainProbability: rainProbability,
    windSpeed: windSpeed,
    alertType: alertType,
  );

  /// Generate a smart agronomic weather push notification description via OpenRouter AI.
  Future<Map<String, String>> generateWeatherPushDescription({
    required String farmName,
    String? specialty,
    required String condition,
    required double temperature,
    required double rainProbability,
    required double windSpeed,
    String? alertType,
  }) async {
    final prompt = '''
You are Kiko, the AI Agricultural & Weather Advisor for AgriDirect (Philippines).
Generate a highly engaging, dynamic, and realistic weather push notification tailored specifically for Filipino farmers in $farmName.

Live Weather Telemetry:
- Location: $farmName (Pangasinan)
- Target Crop: "${specialty ?? 'High-value crops & vegetables'}"
- Live Forecast Condition: $condition
- Temperature: ${temperature.toStringAsFixed(1)}°C
- Rain Probability: ${(rainProbability * 100).toStringAsFixed(0)}%
- Wind Speed: ${windSpeed.toStringAsFixed(1)} km/h
- Alert Level: ${alertType ?? 'general'}

Dynamic Guidelines:
1. TYPHOON & STORM IDENTIFICATION: If a typhoon, tropical storm, or strong gale is detected in the forecast (or winds > 40 km/h), explicitly mention the storm or typhoon advisory (e.g. "Bagyo Warning", "Typhoon Alert", or include the storm name if available in the condition text). Provide urgent advice on canal drainage, staking tall crops (bananas/corn), and securing storage.
2. DYNAMIC & NATURAL VARIETY: Make the message sound fresh, smart, and realistic with the real numbers (${temperature.toStringAsFixed(0)}°C, ${(rainProbability * 100).toStringAsFixed(0)}% rain). Do NOT use generic canned lines. Use natural English or Taglish.
3. "title": Must start with "🤖 Weather AI:" or "🌾 Weather AI:" followed by emojis (e.g. "🤖 Weather AI: 🌀 Bagyo Alert & Storm Prep", "🌾 Weather AI: 🌧️ Heavy Rain Advisory", "🌾 Weather AI: ☀️ Sunny Harvest Weather", max 45 chars).
4. "body": 1-2 concise, high-impact sentences for a mobile lock screen (max 150 chars). State the weather and a specific crop action.
5. Return ONLY valid JSON format: {"title": "...", "body": "..."} without markdown fences.
''';

    // 1. Try Groq fast models if key is present
    if (groqApiKey.isNotEmpty) {
      final groqModels = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];
      for (final currentModel in groqModels) {
        try {
          final response = await http.post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $groqApiKey',
            },
            body: jsonEncode({
              'model': currentModel,
              'messages': [
                {
                  'role': 'system',
                  'content': 'You are Kiko, an expert AI Agricultural Advisor for Filipino farmers. You respond strictly in JSON.',
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.5,
              'max_tokens': 160,
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            String? content = data['choices']?[0]?['message']?['content'] as String?;
            if (content != null && content.trim().isNotEmpty) {
              content = content.trim();
              if (content.startsWith('```json')) {
                content = content.replaceAll('```json', '').replaceAll('```', '').trim();
              } else if (content.startsWith('```')) {
                content = content.replaceAll('```', '').trim();
              }
              try {
                final parsed = jsonDecode(content);
                if (parsed is Map && parsed['title'] != null && parsed['body'] != null) {
                  return {
                    'title': parsed['title'].toString().trim(),
                    'body': parsed['body'].toString().trim(),
                  };
                }
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('Groq weather description error on $currentModel: $e');
        }
      }
    }

    // 2. Try OpenRouter free models
    final openRouterModels = [
      'meta-llama/llama-3.3-70b-instruct:free',
      'google/gemma-4-31b-it:free',
      'google/gemma-4-26b-a4b-it:free',
      'nvidia/nemotron-nano-12b-v2-vl:free',
      'openai/gpt-oss-20b:free',
    ];

    for (final currentModel in openRouterModels) {
      try {
        final response = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: _buildHeaders(forceOpenRouter: true),
          body: jsonEncode({
            'model': currentModel,
            'messages': [
              {
                'role': 'system',
                'content': 'You are Kiko, an expert AI Agricultural Advisor for Filipino farmers. You respond strictly in JSON.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.5,
            'max_tokens': 160,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          String? content = data['choices']?[0]?['message']?['content'] as String?;
          if (content != null && content.trim().isNotEmpty) {
            content = content.trim();
            if (content.startsWith('```json')) {
              content = content.replaceAll('```json', '').replaceAll('```', '').trim();
            } else if (content.startsWith('```')) {
              content = content.replaceAll('```', '').trim();
            }
            try {
              final parsed = jsonDecode(content);
              if (parsed is Map && parsed['title'] != null && parsed['body'] != null) {
                return {
                  'title': parsed['title'].toString().trim(),
                  'body': parsed['body'].toString().trim(),
                };
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('OpenRouter weather description error on $currentModel: $e');
      }
    }

    // 3. Try Gemini AI (using GEMINI_API_KEY from .env)
    if (effectiveGeminiKey.isNotEmpty) {
      try {
        final geminiUrl = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$effectiveGeminiKey',
        );
        final response = await http.post(
          geminiUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {
                    'text':
                        'You are Kiko, an expert AI Agricultural Advisor for Filipino farmers. Respond in JSON format only without markdown blocks.\n\n$prompt'
                  }
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.5,
              'maxOutputTokens': 200,
            }
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          String? text =
              data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
          if (text != null && text.trim().isNotEmpty) {
            text = text.trim();
            if (text.startsWith('```json')) {
              text = text.replaceAll('```json', '').replaceAll('```', '').trim();
            } else if (text.startsWith('```')) {
              text = text.replaceAll('```', '').trim();
            }
            final parsed = jsonDecode(text);
            if (parsed is Map && parsed['title'] != null && parsed['body'] != null) {
              return {
                'title': parsed['title'].toString().trim(),
                'body': parsed['body'].toString().trim(),
              };
            }
          }
        }
      } catch (e) {
        debugPrint('Gemini weather description error: $e');
      }
    }

    // 4. Try Supabase Edge Function (uses cloud OPENROUTER_API_KEY secret)
    try {
      final edgeRes = await SupabaseConfig.client.functions.invoke(
        'daily-weather-check',
        body: {
          'mode': 'generate_weather_ai',
          'farmName': farmName,
          'specialty': specialty,
          'condition': condition,
          'temp': temperature,
          'rainProb': rainProbability,
          'windSpeed': windSpeed,
          'alertType': alertType,
        },
      ).timeout(const Duration(seconds: 8));

      if (edgeRes.status == 200 && edgeRes.data is Map) {
        final data = edgeRes.data as Map;
        if (data['title'] != null && data['body'] != null) {
          return {
            'title': data['title'].toString().trim(),
            'body': data['body'].toString().trim(),
          };
        }
      }
    } catch (e) {
      debugPrint('Supabase Edge Function AI weather error: $e');
    }

    // Fallback if OpenRouter is unavailable
    final popPercent = (rainProbability * 100).toStringAsFixed(0);
    return {
      'title': rainProbability >= 0.5 ? '🌧️ Farm Rain Advisory' : '🌾 Daily Weather Update',
      'body': rainProbability >= 0.5
          ? 'Expect $condition ($popPercent% rain) near $farmName. Check field drainage and safeguard ${specialty ?? 'crops'}.'
          : 'Forecast for $farmName: $condition, ${temperature.toStringAsFixed(0)}°C. Have a fruitful farming day!',
    };
  }

  /// Generate dynamic marketing or official advisory push campaigns via AI
  Future<Map<String, String>> generateCampaignPush({
    required String campaignType, // 'rain_promo', 'flash_harvest', 'market_demand', 'da_advisory'
    String? location,
  }) async {
    final loc = location ?? 'San Carlos City, Pangasinan';
    String rolePrompt = '';

    if (campaignType == 'rain_promo') {
      rolePrompt = 'Create a warm, enticing rainy-day consumer promo push notification offering 10-15% OFF farm-fresh soup vegetables, root crops, or organic produce from local farms in $loc.';
    } else if (campaignType == 'flash_harvest') {
      rolePrompt = 'Create an exciting flash harvest drop push notification for consumers announcing freshly harvested crops (pick a random crop like Sweet Corn, Native Tomatoes, Eggplants, or Carabao Mangoes) from $loc farms with limited-time early pre-order.';
    } else if (campaignType == 'market_demand') {
      rolePrompt = 'Create a real-time market alert push notification for local farmers in $loc informing them that wholesale/retail buyer demand has surged for a specific vegetable/crop and urging them to update their harvest inventory.';
    } else {
      rolePrompt = 'Create an official Department of Agriculture (DA) & AgriDirect policy or support advisory push notification for farmers in $loc regarding seed distribution, fertilizer aid, or climate resilience.';
    }

    final prompt = '''
You are Kiko, the AI Agricultural & Marketing Advisor for AgriDirect (Philippines).
$rolePrompt

Rules:
1. "title": Catchy, mobile notification title with relevant emojis (max 45 chars).
2. "body": 1-2 concise, engaging sentences for a mobile lock screen (max 145 chars). Include emojis.
3. Return ONLY valid JSON: {"title": "...", "body": "..."} without markdown fences.
''';

    final openRouterModels = [
      'meta-llama/llama-3.3-70b-instruct:free',
      'google/gemma-4-31b-it:free',
      'google/gemma-4-26b-a4b-it:free',
      'nvidia/nemotron-nano-12b-v2-vl:free',
      'openai/gpt-oss-20b:free',
    ];

    if (effectiveOpenRouterKey.isNotEmpty) {
      for (final currentModel in openRouterModels) {
        try {
          final response = await http.post(
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $effectiveOpenRouterKey',
              'HTTP-Referer': 'https://agridirect.app',
              'X-Title': 'AgriDirect Push Advisor',
            },
            body: jsonEncode({
              'model': currentModel,
              'messages': [
                {
                  'role': 'system',
                  'content': 'You are Kiko, the AI Marketing & Agriculture Advisor for AgriDirect. You always respond strictly in JSON.',
                },
                {
                  'role': 'user',
                  'content': prompt,
                },
              ],
              'temperature': 0.7,
              'max_tokens': 160,
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            String? content = data['choices']?[0]?['message']?['content'] as String?;
            if (content != null && content.trim().isNotEmpty) {
              content = content.trim();
              if (content.startsWith('```json')) {
                content = content.replaceAll('```json', '').replaceAll('```', '').trim();
              } else if (content.startsWith('```')) {
                content = content.replaceAll('```', '').trim();
              }
              final parsed = jsonDecode(content);
              if (parsed is Map && parsed['title'] != null && parsed['body'] != null) {
                return {
                  'title': parsed['title'].toString().trim(),
                  'body': parsed['body'].toString().trim(),
                };
              }
            }
          }
        } catch (e) {
          debugPrint('OpenRouter campaign error on $currentModel: $e');
        }
      }
    }

    // Dynamic fallback
    if (campaignType == 'rain_promo') {
      return {
        'title': 'Stay cozy with fresh farm soup veggies! 🍲🌧️',
        'body': '15% OFF hearty stew & root vegetable baskets today! 💚 Direct from local Pangasinan farms. Tap to check harvest! 📲',
      };
    } else if (campaignType == 'flash_harvest') {
      return {
        'title': 'Fresh harvest alert! Sweet corn just arrived 🌽🚜',
        'body': 'Pangasinan sweet corn is freshly harvested! 15% off for early bird pre-orders today. Tap to reserve a basket!',
      };
    } else if (campaignType == 'market_demand') {
      return {
        'title': 'High buyer demand for Fresh Vegetables! 🍅📈',
        'body': 'Buyer inquiries in Pangasinan have surged today. Tap to update your harvest inventory and fulfill orders.',
      };
    } else {
      return {
        'title': '🌾 DA Agricultural Program Notice',
        'body': 'New climate-resilient seed and fertilizer distribution is now open. Tap to check participating LGU centers in Pangasinan.',
      };
    }
  }
}
