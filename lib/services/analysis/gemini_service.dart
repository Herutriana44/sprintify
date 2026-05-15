import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      throw Exception('GEMINI_API_KEY tidak ditemukan di file .env');
    }
    _model = GenerativeModel(
      model: dotenv.env['GEMINI_MODEL_ID'] ?? 'gemini-1.5-flash',
      apiKey: apiKey,
    );
  }

  Future<String> getAnalysis(String prompt) async {
    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? 'Tidak ada analisis yang dihasilkan.';
  }
}
