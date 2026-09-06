import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OpenWAService {
  final Dio _dio;
  bool _isConnected = false;
  bool _circuitOpen = false;
  DateTime _lastFailure = DateTime.now();
  String? _sessionId;
  static const _circuitResetDuration = Duration(seconds: 30);

  OpenWAService(this._dio);

  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  Future<void> initialize() async {
    _dio.options.baseUrl = 'http://localhost:3001';
  }

  Future<bool> checkHealth() async {
    if (_circuitOpen) {
      if (DateTime.now().difference(_lastFailure) < _circuitResetDuration) {
        return false;
      }
      _circuitOpen = false;
    }

    try {
      final response = await _dio.get('/health');
      _isConnected = response.statusCode == 200;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      _circuitOpen = true;
      _lastFailure = DateTime.now();
      return false;
    }
  }

  /// Start a WhatsApp session by providing a phone number.
  /// The server sends a pairing code or OTP to the phone.
  Future<Map<String, dynamic>> startSession({required String phone}) async {
    try {
      final response = await _dio.post('/start-session', data: {'phone': phone});
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        _sessionId = data['session_id'] as String?;
        return data;
      }
      throw Exception('Failed to start session: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception('Session start failed: ${e.message}');
    }
  }

  /// Check if the session is connected and active
  Future<bool> isSessionActive() async {
    try {
      final response = await _dio.get('/session');
      return response.statusCode == 200 && response.data['status'] == 'connected';
    } catch (e) {
      return false;
    }
  }

  Future<bool> sendMessage({
    required String phone,
    required String message,
  }) async {
    try {
      final response = await _dio.post('/send-message', data: {
        'phone': phone,
        'message': message,
      });
      return response.statusCode == 200;
    } catch (e) {
      _circuitOpen = true;
      _lastFailure = DateTime.now();
      return false;
    }
  }

  Future<bool> sendImage({
    required String phone,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final response = await _dio.post('/send-image', data: {
        'phone': phone,
        'message': caption ?? '',
        'image': imageUrl,
      });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _dio.post('/logout');
    } catch (_) {}
    _isConnected = false;
    _sessionId = null;
  }

  bool get isConnected => _isConnected;
  bool get isCircuitOpen => _circuitOpen;
  String? get sessionId => _sessionId;
}

final openwaServiceProvider = Provider<OpenWAService>((ref) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3001'));
  return OpenWAService(dio);
});

final openwaSessionStatusProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(openwaServiceProvider);
  return await service.isSessionActive();
});

final openwaServerUrlProvider = StateProvider<String>((ref) => 'http://localhost:3001');
