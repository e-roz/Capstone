import 'package:dio/dio.dart';

String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return error.message ?? 'Something went wrong. Please try again.';
  }
  return error.toString();
}
