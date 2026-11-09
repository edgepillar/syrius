import 'dart:math';

import 'package:zenon_syrius_wallet_flutter/screens/onboarding/new_wallet/seed_quiz.dart';

/// Creates the repeatable display quiz with words invalid for wallet use.
SeedQuiz createSyntheticSeedQuiz() => SeedQuiz(
  List<String>.generate(12, (int index) => 'fixture-word-$index'),
  random: Random(7),
  isValidWord: (String _) => true,
  validateMnemonic: (List<String> _) => true,
);
