import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/sprintify_state.dart';

void main() {
  runApp(
    ChangeNotifierProvider<SprintifyState>(
      create: (_) => SprintifyState(),
      child: const SprintifyApp(),
    ),
  );
}
