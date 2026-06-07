import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  GenerativeModel? _model;
  String? _initError;

  GeminiService() {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        _initError = 'GEMINI_API_KEY tidak ditemukan di file .env';
        return;
      }
      _model = GenerativeModel(
        model: dotenv.env['GEMINI_MODEL_ID'] ?? 'gemini-1.5-flash',
        apiKey: apiKey,
      );
    } catch (e) {
      _initError = 'Gagal inisialisasi Gemini: $e';
    }
  }

  /// Kirim teks saja ke Gemini.
  Future<String> getAnalysis(String prompt) async {
    if (_model == null) {
      return 'Analisis AI tidak tersedia: $_initError';
    }
    final response = await _model!.generateContent([Content.text(prompt)]);
    return response.text ?? 'Tidak ada analisis yang dihasilkan.';
  }

  /// Kirim gambar + teks ke Gemini (multimodal).
  ///
  /// [imageFiles] berisi file gambar frame terbaik (bersedia & berlari).
  /// [textPrompt] adalah konteks penilaian yang disertakan.
  Future<String> getAnalysisWithImages({
    required List<File> imageFiles,
    required String textPrompt,
  }) async {
    if (_model == null) {
      return 'Analisis AI tidak tersedia: $_initError';
    }

    if (imageFiles.isEmpty) {
      // Fallback ke text-only jika tidak ada gambar
      return getAnalysis(textPrompt);
    }

    final List<Part> parts = [];

    // Tambahkan gambar sebagai inline data
    for (final file in imageFiles) {
      final bytes = await file.readAsBytes();
      parts.add(DataPart('image/jpeg', bytes));
    }

    // Tambahkan prompt teks
    parts.add(TextPart(textPrompt));

    final response = await _model!.generateContent([Content.multi(parts)]);
    return response.text ?? 'Tidak ada analisis yang dihasilkan.';
  }
}
