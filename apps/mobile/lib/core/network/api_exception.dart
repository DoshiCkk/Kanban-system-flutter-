import 'package:dio/dio.dart';

/// Error categories the UI can react to. Server codes come from the API's
/// `{ statusCode, code, message }` error body.
enum ApiErrorCode {
  validationFailed,
  emailTaken,
  invalidCredentials,
  invalidRefreshToken,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  inviteInvalid,
  ownerRoleLocked,
  rateLimited,
  network,
  server,
  unknown,
}

const _serverCodes = <String, ApiErrorCode>{
  'VALIDATION_FAILED': ApiErrorCode.validationFailed,
  'EMAIL_TAKEN': ApiErrorCode.emailTaken,
  'INVALID_CREDENTIALS': ApiErrorCode.invalidCredentials,
  'INVALID_REFRESH_TOKEN': ApiErrorCode.invalidRefreshToken,
  'FORBIDDEN': ApiErrorCode.forbidden,
  'NOT_FOUND': ApiErrorCode.notFound,
  'CONFLICT': ApiErrorCode.conflict,
  'INVITE_INVALID': ApiErrorCode.inviteInvalid,
  'OWNER_ROLE_LOCKED': ApiErrorCode.ownerRoleLocked,
};

class ApiException implements Exception {
  const ApiException(this.code, {this.statusCode, this.message});

  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return ApiException(ApiErrorCode.network, message: error.message);
      case DioExceptionType.badResponse:
        return ApiException._fromResponse(error.response);
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        // SocketException on some platforms surfaces as `unknown`.
        if (error.response == null) {
          return ApiException(ApiErrorCode.network, message: error.message);
        }
        return ApiException._fromResponse(error.response);
    }
  }

  factory ApiException._fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    final data = response?.data;
    final serverCode = data is Map ? data['code'] : null;
    final message = data is Map ? data['message']?.toString() : null;

    final code =
        _serverCodes[serverCode] ??
        switch (status) {
          401 => ApiErrorCode.unauthorized,
          403 => ApiErrorCode.forbidden,
          404 => ApiErrorCode.notFound,
          409 => ApiErrorCode.conflict,
          429 => ApiErrorCode.rateLimited,
          final int s when s >= 500 => ApiErrorCode.server,
          _ => ApiErrorCode.unknown,
        };
    return ApiException(code, statusCode: status, message: message);
  }

  final ApiErrorCode code;
  final int? statusCode;
  final String? message;

  @override
  String toString() => 'ApiException($code, $statusCode, $message)';
}

/// Runs an API call and converts transport errors into [ApiException].
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (error) {
    throw ApiException.fromDio(error);
  }
}
