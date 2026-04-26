import 'dart:convert';
import 'package:http/http.dart' as http;

class PptService {
  static Future<String?> generatePpt({
    required Map<String, dynamic> slideJson,
    required String basePath,
  }) async {
    final url = Uri.parse("http://127.0.0.1:5000/generate_ppt");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "slides": slideJson["slides"],
        "topic": slideJson["topic"],
        "base_path": basePath,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["file_path"];
    } else {
      throw Exception("PPT generation failed");
    }
  }
}