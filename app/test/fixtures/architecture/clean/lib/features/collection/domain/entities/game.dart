// A clean domain file. The commented imports below must be ignored:
// import 'package:flutter/material.dart';
/* import 'dart:ui'; */
import 'dart:async';
import 'dart:collection';

import 'package:board_game_collector/core/result/result.dart';
import 'package:meta/meta.dart';

import '../repositories/game_repository.dart';

@immutable
class Game {
  const Game(this.name);
  final String name;
}

typedef Uses = (Future<void>, HashMap<int, int>, Result, GameRepository);
