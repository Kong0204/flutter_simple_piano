import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // required for locking phone orientation
import 'package:flutter_soloud/flutter_soloud.dart';

void main() {
  // Ensure the engine is ready before calling SystemChrome
  WidgetsFlutterBinding.ensureInitialized();

  // Lock the app to landscape mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) => runApp(const PianoApp()));
}

class PianoApp extends StatelessWidget {
  const PianoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: PianoLayout()),
    );
  }
}

class PianoLayout extends StatefulWidget {
  const PianoLayout({super.key});

  @override
  State<PianoLayout> createState() => _PianoLayoutState();
}

class _PianoLayoutState extends State<PianoLayout> {
  final _soloud = SoLoud.instance;

  // Cache loaded sound sources so we only load each file once
  final Map<String, AudioSource> _sources = {};

  // tracks which keys are being pressed
  final Set<String> _activeNotes = {};
  final Map<int, String> _pointerLocation = {};

  final List<String> _allNotes = [
    'c1',
    'd1',
    'e1',
    'f1',
    'g1',
    'a1',
    'b1',
    'c1s',
    'd1s',
    'f1s',
    'g1s',
    'a1s',
  ];

  @override
  void initState() {
    super.initState();
    // pre-create player
    _initSoLoud();
  }

  Future<void> _initSoLoud() async {
    // Initialize the SoLoud engine
    await _soloud.init();

    // Pre-load all note assets into memory
    for (final note in _allNotes) {
      _sources[note] = await _soloud.loadAsset('assets/$note.wav');
    }
  }

  Future<void> _playNote(String note) async {
    final source = _sources[note];
    if (source == null) return;

    // play() on SoLoud always overlaps — true polyphony out of the box
    await _soloud.play(source);

    setState(() => _activeNotes.add(note));
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _activeNotes.remove(note));
    });
  }

  // where kw is keyWidth, th is totalHeight
  void _handlePointerEvent(PointerEvent event, double kw, double th) {
    final currentNote = _calculateNote(event.localPosition, kw, th);
    final pointerId = event.pointer;

    if (event is PointerDownEvent || event is PointerMoveEvent) {
      if (currentNote != null && _pointerLocation[pointerId] != currentNote) {
        _playNote(currentNote);
        _pointerLocation[pointerId] = currentNote;
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointerLocation.remove(pointerId);
    }
  }

  String? _calculateNote(Offset pos, double kw, double th) {
    if (pos.dy < th * 0.5) {
      if (pos.dx > kw * 0.7 && pos.dx < kw * 0.7 + 60) return 'c1s';
      if (pos.dx > kw * 1.7 && pos.dx < kw * 1.7 + 60) return 'd1s';
      if (pos.dx > kw * 3.7 && pos.dx < kw * 3.7 + 60) return 'f1s';
      if (pos.dx > kw * 4.7 && pos.dx < kw * 4.7 + 60) return 'g1s';
      if (pos.dx > kw * 5.7 && pos.dx < kw * 5.7 + 60) return 'a1s';
    }
    final index = (pos.dx / kw).floor();
    const notes = ['c1', 'd1', 'e1', 'f1', 'g1', 'a1', 'b1'];
    return (index >= 0 && index < 7) ? notes[index] : null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double keyWidth = constraints.maxWidth / 7;
        double totalHeight = constraints.maxHeight;

        // We use Listener for Multi-touch support
        return Listener(
          onPointerDown: (e) => _handlePointerEvent(e, keyWidth, totalHeight),
          onPointerMove: (e) => _handlePointerEvent(e, keyWidth, totalHeight),
          onPointerUp: (e) => _handlePointerEvent(e, keyWidth, totalHeight),
          child: Stack(
            children: [
              Row(
                children: [
                  'c1',
                  'd1',
                  'e1',
                  'f1',
                  'g1',
                  'a1',
                  'b1',
                ].map(_buildWhiteKey).toList(),
              ),
              _buildBlackKey(keyWidth * 0.7, totalHeight, 'c1s'),
              _buildBlackKey(keyWidth * 1.7, totalHeight, 'd1s'),
              _buildBlackKey(keyWidth * 3.7, totalHeight, 'f1s'),
              _buildBlackKey(keyWidth * 4.7, totalHeight, 'g1s'),
              _buildBlackKey(keyWidth * 5.7, totalHeight, 'a1s'),
            ],
          ),
        );
      },
    );
  }

  // build white keys
  Widget _buildWhiteKey(String note) => Expanded(
    child: Container(
      decoration: BoxDecoration(
        color: _activeNotes.contains(note) ? Colors.grey[300] : Colors.white,
        border: Border.all(color: Colors.grey, width: 1),
      ),
    ),
  );

  // build black keys
  Widget _buildBlackKey(
    double left,
    double totalHeight,
    String note,
  ) => Positioned(
    left: left,
    top: 0,
    child: Container(
      width: 60,
      height: totalHeight * 0.5,
      decoration: BoxDecoration(
        color: _activeNotes.contains(note) ? Colors.grey[800] : Colors.black,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
      ),
    ),
  );

  @override
  void dispose() {
    _soloud.deinit();
    super.dispose();
  }
}
