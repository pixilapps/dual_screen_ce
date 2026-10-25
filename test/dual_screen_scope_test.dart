import 'package:dual_screen_ce/dual_screen_ce.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable/foldable.dart';

void main() {
  testWidgets('passes through off iOS', (WidgetTester tester) async {
    await tester.pumpWidget(const DualScreenScope(child: SizedBox()));
    expect(find.byType(FoldableProvider), findsNothing);
  });

  testWidgets('bridges the fold on iOS', (WidgetTester tester) async {
    await tester.pumpWidget(const DualScreenScope(child: SizedBox()));
    final FoldableProvider provider = tester.widget(find.byType(FoldableProvider));
    expect(provider.bridgeMode, DisplayFeatureBridgeMode.full);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
