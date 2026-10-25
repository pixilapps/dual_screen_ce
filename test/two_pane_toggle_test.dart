import 'package:dual_screen_ce/dual_screen_ce.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all three panes without a notifier shows the dual layout', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: TwoPane(singleWidget: Text('single'), startPane: Text('start'), endPane: Text('end')),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('start'), findsOneWidget);
    expect(find.text('single'), findsNothing);
  });

  testWidgets('notifier toggles to the single widget', (WidgetTester tester) async {
    final ValueNotifier<bool> showDual = ValueNotifier<bool>(true);
    addTearDown(showDual.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TwoPane(singleWidget: const Text('single'), startPane: const Text('start'), endPane: const Text('end'), switchToSinglePane: showDual),
      ),
    );
    showDual.value = false;
    await tester.pumpAndSettle();
    expect(find.text('single'), findsOneWidget);
    expect(find.text('start'), findsNothing);
  });
}
