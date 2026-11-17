/// Arabic server/client error without the Dart `Exception:` prefix.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;

  /// Prefer [message] on [ApiException]; strip `Exception:` from anything else.
  static String messageOf(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}
