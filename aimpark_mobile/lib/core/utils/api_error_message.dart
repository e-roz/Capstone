import 'package:dio/dio.dart';

/// A failed request, in words worth showing someone.
///
/// [traceId] is present only when the server hit an unhandled exception. Its
/// own message asks the user to quote it, so the app has to actually show it —
/// it used to be parsed off the response and thrown away, which left testers
/// reading "quote the trace ID" with no trace ID anywhere on screen and no way
/// to tie a screenshot to the row in the admin panel's System Logs.
class ApiError {
  const ApiError(this.message, {this.traceId});

  final String message;
  final String? traceId;
}

/// The server's own wording where it gave one, and something honest where it
/// did not.
ApiError apiError(Object error) {
  if (error is! DioException) {
    return ApiError(error.toString());
  }

  final data = error.response?.data;
  if (data is Map) {
    final message = data['message']?.toString();
    final traceId = data['traceId']?.toString();
    if (message != null && message.isNotEmpty) {
      return ApiError(message, traceId: traceId);
    }
  }

  // No body to read. Separate the cases a user can act on from the ones they
  // cannot: "check your connection" is useless advice when the server answered
  // and simply answered badly.
  final message = switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      'The server took too long to answer. It may be waking up — try again in '
          'a moment.',
    DioExceptionType.connectionError =>
      'Could not reach the server. Check your connection and try again.',
    DioExceptionType.badCertificate =>
      "The server's security certificate could not be verified.",
    DioExceptionType.cancel => 'That request was cancelled.',
    DioExceptionType.badResponse ||
    DioExceptionType.unknown =>
      error.message ?? 'Something went wrong. Please try again.',
  };

  return ApiError(message);
}

/// Convenience for call sites that only want the sentence.
String apiErrorMessage(Object error) => apiError(error).message;
