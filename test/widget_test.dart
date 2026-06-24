import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:t_smart/app.dart';
import 'package:t_smart/providers/t_smart_state.dart';

void main() {
  testWidgets('App builds and shows T-Smart', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TSmartState>(
        create: (_) => TSmartState(),
        child: const TSmartApp(),
      ),
    );
    await tester.pump();
    expect(find.textContaining('T-Smart'), findsWidgets);
    // Selesaikan timer splash (1.8s) agar tidak tertinggal saat dispose.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
  });
}
