import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:foldable/foldable.dart';

/// Publishes the iPhone Duo fold to `MediaQuery.displayFeatures` so [TwoPane]
/// and Flutter's dialogs see it as they see an Android fold.
///
/// Place it above `MaterialApp` / `CupertinoApp`. The fold is published only
/// while the Duo is partially open; nothing is published when it is closed
/// or flat. Off iOS it returns [child] unchanged, because Android already
/// reports display features. It steps aside on its own once Flutter reports
/// display features on iOS (flutter/flutter#193025).
class DualScreenScope extends StatelessWidget {
  const DualScreenScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return child;
    return FoldableProvider(bridgeMode: DisplayFeatureBridgeMode.full, child: child);
  }
}
