import 'package:dual_screen_ce/dual_screen_ce.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DualScreenScope(child: MaterialApp(home: _Home())));

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TwoPane(
        startPane: const ColoredBox(
          color: Colors.amber,
          child: Center(child: Text('start')),
        ),
        endPane: ColoredBox(
          color: Colors.teal,
          child: Center(
            child: StreamBuilder<double>(
              stream: DualScreenInfo.hingeAngleEvents,
              builder: (BuildContext context, AsyncSnapshot<double> s) =>
                  Text('hinge: ${s.data?.toStringAsFixed(0) ?? '-'}°'),
            ),
          ),
        ),
      ),
    );
  }
}
