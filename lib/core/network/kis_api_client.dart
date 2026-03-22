import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'kis_access_token.dart';
import 'kis_api_config.dart';
import 'kis_api_exception.dart';

class KisApiClient {
  KisApiClient(this._config);

  static const _tokenStorageKey = 'kis_access_token_v1';
  static const _approvalKeyStorageKey = 'kis_approval_key_v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final KisApiConfig _config;
  final HttpClient _httpClient = HttpClient();

  KisAccessToken? _cachedToken;
  String? _cachedApprovalKey;

  bool get isConfigured => _config.isConfigured;
  bool get useMockServer => _config.useMockServer;

  Future<Map<String, dynamic>> get({
    required String path,
    required String trId,
    required Map<String, String> queryParameters,
  }) async {
    final token = await _getAccessToken();
    final request = await _httpClient.getUrl(
      _config.resolve(path, queryParameters),
    );

    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.headers.set(HttpHeaders.authorizationHeader, '${token.tokenType} ${token.value}');
    request.headers.set('appkey', _config.appKey);
    request.headers.set('appsecret', _config.appSecret);
    request.headers.set('tr_id', trId);
    request.headers.set('custtype', 'P');

    return _send(request);
  }

  Future<Map<String, dynamic>> post({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final request = await _httpClient.postUrl(_config.resolve(path));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.write(jsonEncode(body));
    return _send(request);
  }

  Future<Map<String, dynamic>> postAuthenticated({
    required String path,
    required String trId,
    required Map<String, dynamic> body,
    bool includeHashKey = false,
  }) async {
    final token = await _getAccessToken();
    final request = await _httpClient.postUrl(_config.resolve(path));

    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.headers.set(HttpHeaders.authorizationHeader, '${token.tokenType} ${token.value}');
    request.headers.set('appkey', _config.appKey);
    request.headers.set('appsecret', _config.appSecret);
    request.headers.set('tr_id', trId);
    request.headers.set('custtype', 'P');

    if (includeHashKey) {
      final hashKey = await _createHashKey(body);
      if (hashKey.isNotEmpty) {
        request.headers.set('hashkey', hashKey);
      }
    }

    request.write(jsonEncode(body));
    return _send(request);
  }

  Future<String> getApprovalKey() async {
    if (!isConfigured) {
      throw const KisApiException('KIS API 설정이 없습니다.');
    }

    final cachedApprovalKey = _cachedApprovalKey ?? await _secureStorage.read(key: _approvalKeyStorageKey);
    if (cachedApprovalKey != null && cachedApprovalKey.isNotEmpty) {
      _cachedApprovalKey = cachedApprovalKey;
      return cachedApprovalKey;
    }

    final response = await post(
      path: '/oauth2/Approval',
      body: {
        'grant_type': 'client_credentials',
        'appkey': _config.appKey,
        'secretkey': _config.appSecret,
      },
    );

    final approvalKey = response['approval_key'] as String? ?? '';
    if (approvalKey.isEmpty) {
      throw const KisApiException('실시간 시세 접속키 발급에 실패했습니다.');
    }

    _cachedApprovalKey = approvalKey;
    await _secureStorage.write(key: _approvalKeyStorageKey, value: approvalKey);
    return approvalKey;
  }

  Future<void> ensureAccessToken() async {
    await _getAccessToken();
  }

  Future<KisAccessToken> _getAccessToken() async {
    if (!isConfigured) {
      throw const KisApiException('KIS API 설정이 없습니다.');
    }

    final cachedToken = _cachedToken;
    if (cachedToken != null && !cachedToken.isExpired) {
      return cachedToken;
    }

    final storedToken = await _readStoredToken();
    if (storedToken != null && !storedToken.isExpired) {
      _cachedToken = storedToken;
      return storedToken;
    }

    final response = await post(
      path: '/oauth2/tokenP',
      body: {
        'grant_type': 'client_credentials',
        'appkey': _config.appKey,
        'appsecret': _config.appSecret,
      },
    );

    final token = KisAccessToken.fromJson(response);
    _cachedToken = token;
    await _secureStorage.write(
      key: _tokenStorageKey,
      value: jsonEncode(token.toJson()),
    );
    return token;
  }

  Future<String> _createHashKey(Map<String, dynamic> body) async {
    final request = await _httpClient.postUrl(_config.resolve('/uapi/hashkey'));
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
    request.headers.set('appkey', _config.appKey);
    request.headers.set('appsecret', _config.appSecret);
    request.write(jsonEncode(body));

    final response = await _send(request);
    return response['HASH'] as String? ?? response['hash'] as String? ?? '';
  }

  Future<Map<String, dynamic>> _send(HttpClientRequest request) async {
    final response = await request.close();
    final rawBody = await response.transform(utf8.decoder).join();
    final decodedBody = rawBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawBody) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw KisApiException(
        decodedBody['msg1'] as String? ?? '서버 요청에 실패했습니다.',
        statusCode: response.statusCode,
        apiCode: decodedBody['msg_cd'] as String?,
      );
    }

    final resultCode = decodedBody['rt_cd'] as String?;
    if (resultCode != null && resultCode != '0') {
      throw KisApiException(
        decodedBody['msg1'] as String? ?? 'KIS OpenAPI 응답이 실패했습니다.',
        statusCode: response.statusCode,
        apiCode: decodedBody['msg_cd'] as String?,
      );
    }

    return decodedBody;
  }

  Future<KisAccessToken?> _readStoredToken() async {
    final raw = await _secureStorage.read(key: _tokenStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return KisAccessToken.fromJson(decoded);
    } catch (_) {
      await _secureStorage.delete(key: _tokenStorageKey);
      return null;
    }
  }
}
