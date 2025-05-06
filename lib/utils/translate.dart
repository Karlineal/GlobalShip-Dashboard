// File: lib/utils/translate.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async'; // Import for TimeoutException and Future.timeout

/// 通过 DeepSeek API 翻译文本
Future<String> translateText(String text, String targetLang) async {
  // 如果目标语言是英语或者文本为空，则无需翻译
  if (targetLang.toLowerCase() == 'en' || text.trim().isEmpty) {
    return text;
  }

  const endpoint = 'https://api.deepseek.com/chat/completions';
  // 请确保您的 API Key 是有效且安全的
  const apiKey = 'sk-2cfbc7609fa649c5b35d116af1f002a2'; // 警告：硬编码的API密钥，仅供演示，生产环境应安全存储

  // 优化提示，使其更倾向于直接翻译词语或短语
  // final prompt = 'Translate the following text into $targetLang: "$text"';
  final prompt = 'Translate the following phrase into $targetLang and return only the translated phrase: "$text"';


  try {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json; charset=utf-8', // 明确指定请求体编码
        // 'Accept-Charset': 'utf-8', // 通常 'Content-Type' 中的 charset 足够
      },
      body: jsonEncode({
        'model': 'deepseek-chat', // 确保模型支持您的需求
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a precise translator. For the given phrase, provide only the direct translation in the target language, without any additional explanations, comments, or conversational text. Ensure the output is properly UTF-8 encoded.',
          },
          {'role': 'user', 'content': prompt},
        ],
        'stream': false,
        // 'temperature': 0.2, // 可以尝试调整 temperature 以获得更确定的输出
      }),
    ).timeout(const Duration(seconds: 15)); // 为API调用设置15秒超时

    if (response.statusCode == 200) {
      // 尝试显式使用 utf8.decode 来处理响应体，以确保正确的UTF-8解码
      final responseBody = utf8.decode(response.bodyBytes);
      final decoded = jsonDecode(responseBody);

      if (decoded['choices'] != null &&
          decoded['choices'] is List &&
          (decoded['choices'] as List).isNotEmpty &&
          decoded['choices'][0]['message'] != null &&
          decoded['choices'][0]['message']['content'] != null) {
        String translatedText = decoded['choices'][0]['message']['content'].trim();
        
        // 移除可能的API返回的额外引号 (如果API倾向于用引号包裹翻译结果)
        if (translatedText.startsWith('"') && translatedText.endsWith('"') && translatedText.length > 1) {
          translatedText = translatedText.substring(1, translatedText.length - 1);
        }
        return translatedText;
      } else {
        print('[DeepSeek API Error] Unexpected response structure: $responseBody');
        return text; // Fallback to original text
      }
    } else {
      // 同样，使用 utf8.decode 来查看错误信息
      final errorBody = utf8.decode(response.bodyBytes);
      print('[DeepSeek API Error ${response.statusCode}]: $errorBody');
      return text; // Fallback to original text
    }
  } on TimeoutException catch (e) {
    print('[DeepSeek API Timeout]: Failed to translate "$text" to $targetLang after 15 seconds. $e');
    return text; // Fallback
  } catch (e) {
    print('[DeepSeek API Exception]: Error translating "$text" to $targetLang: $e');
    return text; // Fallback
  }
}
