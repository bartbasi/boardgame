// Fixture: shared domain code must not import the core data layer.
import '../data/client.dart';

class Result {
  const Result(this.client);
  final Client client;
}
