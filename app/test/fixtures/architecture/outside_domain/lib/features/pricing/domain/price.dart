// Fixture: pure Dart files outside the domain allowlist are still refused.
import 'package:board_game_collector/app/routes.dart';

import '../../../core/ui/spacing.dart';

class Price {
  const Price(this.route, this.gap);
  final Routes route;
  final Spacing gap;
}
