// ponytail: spike-only entry point for doc/iphone_duo_matrix.md (plan step 1.0). Run with
// `flutter run -t lib/duo_probe.dart` on the iPhone Duo simulator, change poses in Device Hub, read the DUO_* log
// lines. Delete together with ios/.../DebugProbe.swift once the matrix is recorded.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show DisplayFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _bar = MethodChannel('dual_screen_ce/vertical_bar');
const EventChannel _stateChannel = EventChannel('dual_screen_ce/display_state');
const EventChannel _angleChannel = EventChannel('dual_screen_ce/hinge_angle');

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: _Probe()));

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  StreamSubscription<dynamic>? _stateSub;
  StreamSubscription<dynamic>? _angleSub;
  Object? _lastState;
  Object? _lastDump;
  double? _angle;
  int _events = 0;

  @override
  void initState() {
    super.initState();
    _stateSub = _stateChannel.receiveBroadcastStream().listen((Object? event) {
      _events++;
      setState(() => _lastState = event);
      _maybeRunSequence(event);
    });
    _angleSub = _angleChannel.receiveBroadcastStream().listen((Object? a) => setState(() => _angle = a as double?));
  }

  // Full records go to a file in the app's tmp dir (the simulator log truncates long lines).
  final File _out = File('${Directory.systemTemp.path}/duo_probe.jsonl');

  void _record(String kind, Object? data) {
    _out.writeAsStringSync('${jsonEncode(<String, Object?>{'kind': kind, 'pose': _currentPose, 'data': data})}\n', mode: FileMode.append);
  }

  Map<String, Object> _mq() {
    final MediaQueryData mq = MediaQuery.of(context);
    return <String, Object>{'size': <double>[mq.size.width, mq.size.height], 'padding': _insets(mq.padding), 'viewPadding': _insets(mq.viewPadding), 'features': mq.displayFeatures.map((DisplayFeature f) => '${f.type.name}:${f.state.name}:${f.bounds}').toList()};
  }

  Future<void> _dump([String kind = 'dump']) async {
    final Object? dump = await _bar.invokeMethod<Object?>('debugDump');
    if (!mounted) return;
    _record(kind, <String, Object?>{'native': dump, 'mq': _mq()});
    setState(() => _lastDump = dump);
  }

  List<double> _insets(EdgeInsets e) => <double>[e.left, e.top, e.right, e.bottom];

  // Once per new pose (posture, window size, bar side): alert, sheet, bar off/on, each followed by a dump.
  final Set<String> _seenPoses = <String>{};
  Timer? _settle;
  bool _running = false;
  String _currentPose = '-';

  String _poseOf(Map<Object?, Object?> state) {
    final Size size = MediaQuery.sizeOf(context);
    final Object? bar = state['verticalBar'];
    return '${state['posture']}|${size.width.round()}x${size.height.round()}|${bar is Map ? bar['side'] : 'none'}';
  }

  void _maybeRunSequence(Object? event) {
    if (_running) return; // the sequence's own bar toggle changes the state; that is not a new pose
    final Map<Object?, Object?> state = (event as Map<Object?, Object?>?) ?? const <Object?, Object?>{};
    _currentPose = _poseOf(state);
    _record('state', state);
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 2000), () async {
      final String pose = _currentPose;
      if (!_seenPoses.add(pose)) return;
      _running = true;
      debugPrint('DUO_POSE_BEGIN $pose');
      await _dump('pose');
      await _call('debugProbePresentation', 'alert');
      await _call('debugProbePresentation', 'sheet');
      await _call('setPreferredVerticalBarBehavior', 'disabled');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await _dump('barDisabled');
      await _call('setPreferredVerticalBarBehavior', 'automatic');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final String after = _poseOf((_lastState as Map<Object?, Object?>?) ?? const <Object?, Object?>{});
      debugPrint('DUO_POSE_END $pose${after == pose ? '' : ' (moved to $after mid-check: redo this pose)'}');
      if (after != pose) _seenPoses.remove(pose);
      _running = false;
    });
  }

  Future<void> _call(String method, [Object? args]) async {
    final Object? result = await _bar.invokeMethod<Object?>(method, args);
    _record('call', <String, Object?>{'method': method, 'args': args, 'result': result});
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _dump('after:$method:$args');
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _angleSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    const JsonEncoder pretty = JsonEncoder.withIndent(' ');
    return Scaffold(
      backgroundColor: Colors.teal.shade900,
      body: Stack(
        children: <Widget>[
          // Shows the safe area Flutter receives: the inner box is the area inside MediaQuery.padding.
          Positioned.fill(child: Padding(padding: padding, child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: Colors.amber, width: 2))))),
          Padding(
            padding: padding,
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: <Widget>[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    FilledButton(onPressed: _dump, child: const Text('Dump')),
                    FilledButton(onPressed: () => _call('setPreferredVerticalBarBehavior', 'disabled'), child: const Text('Bar off')),
                    FilledButton(onPressed: () => _call('setPreferredVerticalBarBehavior', 'automatic'), child: const Text('Bar on')),
                    FilledButton(onPressed: () => _call('debugProbePresentation', 'alert'), child: const Text('Alert')),
                    FilledButton(onPressed: () => _call('debugProbePresentation', 'sheet'), child: const Text('Sheet')),
                  ],
                ),
                Text('events: $_events  angle: ${_angle?.toStringAsFixed(1) ?? '-'}  padding: $padding', style: const TextStyle(color: Colors.white)),
                Text(pretty.convert(_lastState), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(pretty.convert(_lastDump), style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
