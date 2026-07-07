/// Token-bucket rate limiter untuk Gemini API.
///
/// Maksimal 5 panggilan per 60 detik, dengan jeda minimal 12 detik antar
/// panggilan. Menggunakan algoritma token bucket sederhana.
class RateLimiter {
  final int _maxTokens;
  final Duration _refillInterval;
  final Duration _minCallGap;

  int _tokens;
  DateTime? _lastCallTime;
  DateTime _bucketRefillTime;

  RateLimiter({
    int maxCallsPerMinute = 5,
    Duration? minCallGap,
  })  : _maxTokens = maxCallsPerMinute,
        _refillInterval = const Duration(seconds: 60),
        _minCallGap = minCallGap ?? const Duration(seconds: 12),
        _tokens = maxCallsPerMinute,
        _bucketRefillTime = DateTime.now().add(const Duration(seconds: 60));

  /// Tunggu hingga token tersedia. Melempar [RateLimitExceededException]
  /// bila tidak ada token dan caller tidak ingin menunggu.
  Future<void> acquire() async {
    _refillIfNeeded();

    if (_tokens <= 0) {
      final waitMs = _bucketRefillTime.difference(DateTime.now()).inMilliseconds;
      if (waitMs > 0) {
        throw RateLimitExceededException(
          'Rate limit tercapai. Coba lagi dalam ${waitMs ~/ 1000} detik.',
          retryAfterMs: waitMs,
        );
      }
      // Harusnya tidak sampai sini karena _refillIfNeeded sudah refill
      _refillIfNeeded();
    }

    // Enforce minimum gap antar panggilan
    if (_lastCallTime != null) {
      final gap = DateTime.now().difference(_lastCallTime!);
      if (gap < _minCallGap) {
        final waitMs = _minCallGap.inMilliseconds - gap.inMilliseconds;
        throw RateLimitExceededException(
          'Terlalu cepat. Coba lagi dalam ${waitMs ~/ 1000} detik.',
          retryAfterMs: waitMs,
        );
      }
    }

    _tokens--;
    _lastCallTime = DateTime.now();
  }

  void _refillIfNeeded() {
    if (DateTime.now().isAfter(_bucketRefillTime)) {
      _tokens = _maxTokens;
      _bucketRefillTime = DateTime.now().add(_refillInterval);
    }
  }

  int get availableTokens {
    _refillIfNeeded();
    return _tokens;
  }
}

class RateLimitExceededException implements Exception {
  final String message;
  final int retryAfterMs;

  const RateLimitExceededException(this.message, {this.retryAfterMs = 0});

  @override
  String toString() => message;
}
