import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TcgdexApiClient {
  TcgdexApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  static const String baseUrl = 'https://api.tcgdex.net/v2';

  static const int _maxRequestsPerSecond = 6;
  static const Duration _rateWindow = Duration(seconds: 1);
  static const Map<String, String> _defaultHeaders = <String, String>{
    'Accept': 'application/json',
    'User-Agent': 'tcg-tracker/1.0 (Flutter; local-app)',
  };

  final http.Client _httpClient;
  final Random _random = Random();
  final List<DateTime> _recentRequests = <DateTime>[];
  final Map<String, Future<dynamic>> _inFlightGets = <String, Future<dynamic>>{};

  Future<void> _permitQueue = Future<void>.value();

  Future<dynamic> getJson(
    Uri uri, {
    Duration timeout = const Duration(seconds: 8),
    int maxRetries = 2,
    bool dedupe = true,
  }) {
    if (!dedupe) {
      return _executeWithRetry(uri, timeout: timeout, maxRetries: maxRetries);
    }
    final key = uri.toString();
    final existing = _inFlightGets[key];
    if (existing != null) {
      return existing;
    }
    final future = _executeWithRetry(uri, timeout: timeout, maxRetries: maxRetries);
    _inFlightGets[key] = future;
    future.whenComplete(() {
      final current = _inFlightGets[key];
      if (identical(current, future)) {
        _inFlightGets.remove(key);
      }
    });
    return future;
  }

  Future<dynamic> _executeWithRetry(
    Uri uri, {
    required Duration timeout,
    required int maxRetries,
  }) async {
    http.Response? lastResponse;
    for (var attempt = 0; attempt <= maxRetries; attempt += 1) {
      await _waitForPermit();
      try {
        final response = await _httpClient.get(uri, headers: _defaultHeaders).timeout(timeout);
        if (!_shouldRetryStatus(response.statusCode)) {
          if (response.statusCode != 200) {
            throw HttpException('tcgdex_http_${response.statusCode}', uri: uri);
          }
          return jsonDecode(response.body);
        }
        lastResponse = response;
        if (attempt >= maxRetries) {
          throw HttpException('tcgdex_http_${response.statusCode}', uri: uri);
        }
        final delay = _computeDelay(attempt, retryAfter: _parseRetryAfter(response.headers['retry-after']));
        _logRetry(uri, attempt: attempt + 1, maxRetries: maxRetries, reason: 'HTTP ${response.statusCode}', delay: delay);
        await Future<void>.delayed(delay);
      } on TimeoutException {
        if (attempt >= maxRetries) {
          rethrow;
        }
        final delay = _computeDelay(attempt);
        _logRetry(uri, attempt: attempt + 1, maxRetries: maxRetries, reason: 'timeout', delay: delay);
        await Future<void>.delayed(delay);
      } on SocketException {
        if (attempt >= maxRetries) {
          rethrow;
        }
        final delay = _computeDelay(attempt);
        _logRetry(uri, attempt: attempt + 1, maxRetries: maxRetries, reason: 'network', delay: delay);
        await Future<void>.delayed(delay);
      } on http.ClientException {
        if (attempt >= maxRetries) {
          rethrow;
        }
        final delay = _computeDelay(attempt);
        _logRetry(uri, attempt: attempt + 1, maxRetries: maxRetries, reason: 'client', delay: delay);
        await Future<void>.delayed(delay);
      }
    }
    if (lastResponse != null) {
      throw HttpException('tcgdex_http_${lastResponse.statusCode}', uri: uri);
    }
    throw StateError('Unexpected TCGdex retry state');
  }

  bool _shouldRetryStatus(int statusCode) => statusCode == 429 || (statusCode >= 500 && statusCode < 600);

  Duration _computeDelay(int attempt, {Duration? retryAfter}) {
    if (retryAfter != null && retryAfter > Duration.zero) {
      return retryAfter > const Duration(seconds: 12) ? const Duration(seconds: 12) : retryAfter;
    }
    final expSeconds = min(4, 1 << attempt);
    final base = Duration(milliseconds: 250 * expSeconds);
    final jitter = Duration(milliseconds: 80 + _random.nextInt(220));
    final total = base + jitter;
    return total > const Duration(seconds: 8) ? const Duration(seconds: 8) : total;
  }

  Duration? _parseRetryAfter(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    final seconds = int.tryParse(value);
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds);
    }
    try {
      final target = HttpDate.parse(value).toUtc();
      final now = DateTime.now().toUtc();
      final diff = target.difference(now);
      if (diff > Duration.zero) {
        return diff;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _waitForPermit() {
    final next = _permitQueue.then((_) async {
      while (true) {
        final now = DateTime.now().toUtc();
        _recentRequests.removeWhere((time) => now.difference(time) >= _rateWindow);
        if (_recentRequests.length < _maxRequestsPerSecond) {
          _recentRequests.add(now);
          return;
        }
        final oldest = _recentRequests.first;
        final elapsed = now.difference(oldest);
        final wait = _rateWindow - elapsed + const Duration(milliseconds: 12);
        await Future<void>.delayed(wait > Duration.zero ? wait : const Duration(milliseconds: 12));
      }
    });
    _permitQueue = next.catchError((_) {});
    return next;
  }

  void _logRetry(
    Uri uri, {
    required int attempt,
    required int maxRetries,
    required String reason,
    required Duration delay,
  }) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('TCGdex retry $attempt/$maxRetries for $uri ($reason), waiting ${delay.inMilliseconds}ms');
  }
}
