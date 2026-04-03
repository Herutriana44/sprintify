import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sprintify/app.dart';
import 'package:sprintify/providers/sprintify_state.dart';

void main() {
  testWidgets('App builds and shows Sprintify', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SprintifyState>(
        create: (_) => SprintifyState(),
        child: const SprintifyApp(),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Sprintify'), findsWidgets);
    // Selesaikan timer splash (1.8s) agar tidak tertinggal saat dispose.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
  });
}
