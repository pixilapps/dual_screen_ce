import 'package:dual_screen_ce/dual_screen_ce.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DualScreenScope(child: MaterialApp(home: _Home())));

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    final DualScreenData duo = DualScreen.of(context);
    final VerticalBar? bar = duo.verticalBar;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          TwoPane(
            // One pane in compact windows (a closed iPhone Duo, an Android cover screen), two on the inner display.
            panePriority: duo.horizontalSizeClass == SizeClass.compact || MediaQuery.sizeOf(context).width < 600 ? TwoPanePriority.start : TwoPanePriority.both,
            startPane: ColoredBox(color: Colors.amber, child: SafeArea(child: _Facts(duo))),
            endPane: ColoredBox(
              color: Colors.teal,
              child: Center(
                child: StreamBuilder<double>(
                  stream: DualScreenInfo.hingeAngleEvents,
                  builder: (BuildContext context, AsyncSnapshot<double> s) => Text('hinge: ${s.data?.toStringAsFixed(0) ?? '-'}°'),
                ),
              ),
            ),
          ),
          // A custom vertical bar goes exactly where the system would draw its own.
          if (bar != null) Positioned.fromRect(rect: bar.rect, child: const _Bar()),
        ],
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts(this.duo);

  final DualScreenData duo;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('posture: ${duo.posture.name}'),
        Text('size class: ${duo.horizontalSizeClass.name} × ${duo.verticalSizeClass.name}'),
        Text('vertical bar: ${duo.verticalBar?.side.name ?? 'none'}'),
        Text('fold: ${duo.fold?.rect ?? 'none'}'),
        for (final DisplayRegion region in duo.regions) Text('${region.kind.name}${region.isActive ? '' : ' (inactive)'}: ${region.rect}'),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => DualScreenInfo.setPreferredVerticalBarBehavior(VerticalBarBehavior.disabled), child: const Text('Vertical bar off')),
        FilledButton(onPressed: () => DualScreenInfo.setPreferredVerticalBarBehavior(VerticalBarBehavior.automatic), child: const Text('Vertical bar on')),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_back_ios_new)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.share)),
        const Spacer(),
        IconButton(onPressed: () {}, icon: const Icon(Icons.home)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
      ],
    );
  }
}
