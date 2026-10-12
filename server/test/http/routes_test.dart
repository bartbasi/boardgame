import 'package:boardgame_server/boardgame_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('Routes.templateOf', () {
    test('turns shelf_router parameters into {name}', () {
      expect(Routes.templateOf('/v1/games/<bggId>'), '/v1/games/{bggId}');
      expect(
        Routes.templateOf('/v1/prices/<bggId|[0-9]+>/history'),
        '/v1/prices/{bggId}/history',
      );
      expect(
        Routes.templateOf('/v1/lookup/barcode/<code>'),
        '/v1/lookup/barcode/{code}',
      );
      expect(Routes.templateOf('/health'), '/health');
    });
  });

  group('RouteSlot', () {
    test('is absent on a request that did not pass the request log', () {
      final request = Request('GET', Uri.parse('http://localhost/health'));

      expect(RouteSlot.of(request), isNull);
    });

    test('attach adds an empty slot to the request context', () {
      final request = Request('GET', Uri.parse('http://localhost/health'));

      final (tracked, slot) = RouteSlot.attach(request);

      expect(RouteSlot.of(tracked), same(slot));
      expect(slot.template, isNull);
    });
  });
}
