// Fixture: shared domain code must not import an HTTP package.
import 'package:dio/dio.dart';

class Failure {
  const Failure(this.error);
  final DioException error;
}
