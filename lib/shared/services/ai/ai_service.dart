import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum AiProvider { groq, openRouter }

/// AI Service for AgriDirect powered by Groq & OpenRouter free-tier vision & text models.
class AiService {
  static const String groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');

  final AiProvider provider;
  final String apiKey;

  AiService({AiProvider? provider, String? apiKey})
      : provider = provider ??
            (apiKey?.startsWith('sk-or-') == true
                ? AiProvider.openRouter
                : AiProvider.groq),
        apiKey = apiKey ??
            ((provider == AiProvider.openRouter)
                ? openRouterApiKey
                : groqApiKey);

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
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${useOpenRouter ? openRouterApiKey : apiKey}',
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
}
