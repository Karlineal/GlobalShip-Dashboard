import 'dart:convert';
import 'package:http/http.dart' as http;

/// 通过 DeepSeek API 翻译文本
Future<String> translateText(String text, String targetLang) async {
  const endpoint = 'https://api.deepseek.com/chat/completions';
  const apiKey = 'sk-2cfbc7609fa649c5b35d116af1f002a2'; // 请妥善保管此密钥

  final prompt = 'Translate the following text into $targetLang: "$text"';

  final response = await http.post(
    Uri.parse(endpoint),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept-Charset': 'utf-8',
    },
    body: jsonEncode({
      'model': 'deepseek-chat',
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a helpful translator. Always return text in proper unicode encoding.',
        },
        {'role': 'user', 'content': prompt},
      ],
      'stream': false,
    }),
  );

  if (response.statusCode == 200) {
    final decoded = jsonDecode(response.body);
    final content = decoded['choices'][0]['message']['content'];
    return content.trim();
  } else {
    print('[DeepSeek Error ${response.statusCode}]: ${response.body}');
    return text; // fallback
  }
}
