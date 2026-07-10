import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'rate_limiter.dart';

class GeminiService {
  GenerativeModel? _model;
  String? _initError;
  final RateLimiter _rateLimiter = RateLimiter();

  GeminiService() {
    try {
      // Pastikan dotenv sudah diinisialisasi
      if (!dotenv.isInitialized) {
        _initError = 'Environment variables (.env) belum diinisialisasi';
        return;
      }
      final apiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
      if (apiKey.isEmpty) {
        _initError = 'GEMINI_API_KEY tidak ditemukan di file .env';
        return;
      }
      final modelId = dotenv.get('GEMINI_MODEL_ID', fallback: 'gemini-1.5-flash');
      _model = GenerativeModel(
        model: modelId,
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
    await _rateLimiter.acquire();
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

    await _rateLimiter.acquire();

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
