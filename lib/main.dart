import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FifteenPuzzleApp());
}

class FifteenPuzzleApp extends StatelessWidget {
  const FifteenPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '15 Puzzle Solver (IDA*)',
      theme: ThemeData(useMaterial3: true),
      home: const PuzzlePage(),
    );
  }
}

class PuzzlePage extends StatefulWidget {
  const PuzzlePage({super.key});

  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  static const int n = 4;

  List<int> _tiles = List<int>.generate(16, (i) => (i == 15) ? 0 : i + 1);
  bool _solving = false;
  bool _stopRequested = false;

  // You can tweak animation speed.
  Duration _stepDelay = const Duration(milliseconds: 500);

  String _status = 'Tap tiles to move.';

  @override
  void initState() {
    super.initState();
    // Optional: start with a small shuffle
    _shuffle(60);
  }

  int get _blankIndex => _tiles.indexOf(0);

  bool _isGoal() {
    for (int i = 0; i < 15; i++) {
      if (_tiles[i] != i + 1) return false;
    }
    return _tiles[15] == 0;
  }

  bool _canMoveIndex(int tileIndex) {
    final b = _blankIndex;
    final tr = tileIndex ~/ n, tc = tileIndex % n;
    final br = b ~/ n, bc = b % n;
    return (tr - br).abs() + (tc - bc).abs() == 1;
  }

  /// Move tile at [tileIndex] into the blank if adjacent.
  bool _moveByIndex(int tileIndex) {
    if (!_canMoveIndex(tileIndex)) return false;
    final b = _blankIndex;
    setState(() {
      final tile = _tiles[tileIndex];
      _tiles[b] = tile;
      _tiles[tileIndex] = 0;
    });
    return true;
  }

  /// Move tile with number [tileValue] into the blank if adjacent.
  bool _moveByTileValue(int tileValue) {
    final idx = _tiles.indexOf(tileValue);
    if (idx == -1) return false;
    return _moveByIndex(idx);
  }

  void _shuffle(int steps) {
    if (_solving) return;

    final rng = Random();
    setState(() {
      _tiles = List<int>.generate(16, (i) => (i == 15) ? 0 : i + 1);
      _status = 'Shuffled.';
    });

    // Do random valid moves from goal; guarantees solvable.
    int lastBlank = -1;
    for (int i = 0; i < steps; i++) {
      final b = _tiles.indexOf(0);
      final br = b ~/ n, bc = b % n;

      final candidates = <int>[];
      for (final (dr, dc) in const <(int, int)>[(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final nr = br + dr, nc = bc + dc;
        if (nr < 0 || nr >= n || nc < 0 || nc >= n) continue;
        final idx = nr * n + nc;
        candidates.add(idx);
      }

      // Avoid immediately undoing the last move if possible.
      candidates.shuffle(rng);
      int chosen = candidates.first;
      for (final c in candidates) {
        if (c != lastBlank) {
          chosen = c;
          break;
        }
      }

      final tile = _tiles[chosen];
      _tiles[b] = tile;
      _tiles[chosen] = 0;
      lastBlank = b;
    }

    setState(() {});
  }

  Future<void> _solveAndAnimate() async {
    if (_solving) return;

    if (_isGoal()) {
      setState(() => _status = 'Already solved.');
      return;
    }

    setState(() {
      _solving = true;
      _stopRequested = false;
      _status = 'Solving…';
    });

    final start = List<int>.from(_tiles);

    // ✅ NEW: distinguish unsolvable from "took too long / limit"
    if (!isSolvable15(start)) {
      setState(() {
        _solving = false;
        _status = 'This position is unsolvable (parity check).';
      });
      return;
    }

    // Run IDA* in an isolate so the UI stays snappy.
    final moves = await compute(_solveIDAEntry, start);

    if (!mounted) return;

    if (moves == null) {
      setState(() {
        _solving = false;
        _status = 'No solution found (search limits exceeded).';
      });
      return;
    }

    setState(() {
      _status = 'Solution found: ${moves.length} moves. Animating…';
    });

    // Animate step-by-step so the user can watch.
    int step = 0;
    for (final tile in moves) {
      if (!mounted) return;
      if (_stopRequested) break;

      final ok = _moveByTileValue(tile);
      step++;

      setState(() {
        _status = _stopRequested
            ? 'Stopped at step $step / ${moves.length}.'
            : 'Solving… step $step / ${moves.length}';
      });

      // If somehow a move becomes invalid (shouldn't), bail.
      if (!ok) {
        setState(() {
          _status = 'Animation desynced (invalid move). Stopped.';
          _solving = false;
        });
        return;
      }

      await Future.delayed(_stepDelay);
    }

    if (!mounted) return;

    setState(() {
      _solving = false;
      if (_stopRequested) {
        _status = 'Stopped.';
      } else {
        _status = _isGoal() ? 'Solved!' : 'Finished animation.';
      }
    });
  }

  void _stop() {
    if (!_solving) return;
    setState(() {
      _stopRequested = true;
      _status = 'Stop requested…';
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boardSize = min(size.width, size.height) * 0.45;

    return Scaffold(
      appBar: AppBar(
        title: const Text('15 Puzzle (IDA* Solver)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusBar(
              status: _status,
              solving: _solving,
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: boardSize,
                height: boardSize,
                child: _Board(
                  tiles: _tiles,
                  solving: _solving,
                  onTapIndex: (i) {
                    if (_solving) return;
                    _moveByIndex(i);
                    if (_isGoal()) {
                      setState(() => _status = 'Solved!');
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _solving ? null : () => _shuffle(120),
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Shuffle'),
                ),
                FilledButton.icon(
                  onPressed: _solving ? null : _solveAndAnimate,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Solve (watch it)'),
                ),
                OutlinedButton.icon(
                  onPressed: _solving ? _stop : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SpeedControl(
              value: _stepDelay.inMilliseconds.toDouble(),
              onChanged: _solving
                  ? null
                  : (v) {
                      setState(() {
                        _stepDelay = Duration(milliseconds: v.round());
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String status;
  final bool solving;

  const _StatusBar({
    required this.status,
    required this.solving,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (solving)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          const Icon(Icons.info_outline, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            status,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _SpeedControl extends StatelessWidget {
  final double value; // milliseconds
  final ValueChanged<double>? onChanged;

  const _SpeedControl({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ms = value.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Animation speed: ${ms}ms/step'),
        Slider(
          value: value.clamp(100, 1000),
          min: 100,
          max: 1000,
          divisions: 45,
          label: '$ms ms',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  final List<int> tiles;
  final bool solving;
  final void Function(int index) onTapIndex;

  const _Board({
    required this.tiles,
    required this.solving,
    required this.onTapIndex,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 16,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, i) {
          final v = tiles[i];
          final isBlank = v == 0;

          return GestureDetector(
            onTap: isBlank ? null : () => onTapIndex(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: isBlank
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isBlank
                      ? Theme.of(context).colorScheme.outlineVariant
                      : Theme.of(context).colorScheme.primary,
                  width: isBlank ? 1 : 1.5,
                ),
              ),
              child: Center(
                child: isBlank
                    ? const SizedBox.shrink()
                    : Text(
                        '$v',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// =======================
/// IDA* SOLVER (pure Dart)
/// =======================

List<int>? _solveIDAEntry(List<int> start) => solve15PuzzleIDAStar(start);

List<int>? solve15PuzzleIDAStar(
  List<int> start, {
  int maxDepth = 200,
}) {
  if (start.length != 16) {
    throw ArgumentError('start must have length 16');
  }
  if (!isSolvable15(start)) return null;

  final board = List<int>.from(start);
  final int blank = board.indexOf(0);

  // Goal positions for Manhattan.
  final goalRow = List<int>.filled(16, 0);
  final goalCol = List<int>.filled(16, 0);
  for (int v = 1; v <= 15; v++) {
    final gi = v - 1;
    goalRow[v] = gi ~/ 4;
    goalCol[v] = gi % 4;
  }

  int h = _manhattanWithGoals(board, goalRow, goalCol);
  int bound = h;

  final path = <int>[];

  // Directions correspond to blank movement: 0=up,1=down,2=left,3=right.
  const dr = [-1, 1, 0, 0];
  const dc = [0, 0, -1, 1];
  const opposite = [1, 0, 3, 2];

  while (true) {
    if (bound > maxDepth) return null;

    final t = _idaDfs(
      board: board,
      blankIndex: blank,
      g: 0,
      bound: bound,
      h: h,
      path: path,
      lastDir: -1,
      dr: dr,
      dc: dc,
      opposite: opposite,
      goalRow: goalRow,
      goalCol: goalCol,
    );

    if (t == _found) return List<int>.from(path, growable: false);
    if (t == _inf) return null;
    bound = t;
  }
}

const int _found = -1;
const int _inf = 1 << 30;

int _idaDfs({
  required List<int> board,
  required int blankIndex,
  required int g,
  required int bound,
  required int h,
  required List<int> path,
  required int lastDir,
  required List<int> dr,
  required List<int> dc,
  required List<int> opposite,
  required List<int> goalRow,
  required List<int> goalCol,
}) {
  final f = g + h;
  if (f > bound) return f;
  if (h == 0) return _found;

  int minNextBound = _inf;

  final br = blankIndex ~/ 4;
  final bc = blankIndex % 4;

  for (int dir = 0; dir < 4; dir++) {
    if (lastDir != -1 && dir == opposite[lastDir]) continue;

    final nr = br + dr[dir];
    final nc = bc + dc[dir];
    if (nr < 0 || nr > 3 || nc < 0 || nc > 3) continue;

    final nIdx = nr * 4 + nc; // tile index to move into blank
    final tile = board[nIdx];

    // Incremental Manhattan update: only moved tile changes.
    final oldDist = _tileManhattan(tile, nIdx, goalRow, goalCol);
    final newDist = _tileManhattan(tile, blankIndex, goalRow, goalCol);
    final newH = h - oldDist + newDist;

    // Apply move
    board[blankIndex] = tile;
    board[nIdx] = 0;
    path.add(tile);

    final t = _idaDfs(
      board: board,
      blankIndex: nIdx,
      g: g + 1,
      bound: bound,
      h: newH,
      path: path,
      lastDir: dir,
      dr: dr,
      dc: dc,
      opposite: opposite,
      goalRow: goalRow,
      goalCol: goalCol,
    );

    if (t == _found) return _found;
    if (t < minNextBound) minNextBound = t;

    // Undo move
    path.removeLast();
    board[nIdx] = tile;
    board[blankIndex] = 0;
  }

  return minNextBound;
}

int _manhattanWithGoals(List<int> board, List<int> goalRow, List<int> goalCol) {
  int sum = 0;
  for (int i = 0; i < 16; i++) {
    final v = board[i];
    if (v == 0) continue;
    sum += _tileManhattan(v, i, goalRow, goalCol);
  }
  return sum;
}

int _tileManhattan(int tile, int index, List<int> goalRow, List<int> goalCol) {
  if (tile == 0) return 0;
  final r = index ~/ 4;
  final c = index % 4;
  return (r - goalRow[tile]).abs() + (c - goalCol[tile]).abs();
}

/// ✅ FIXED: Solvability test for 4x4 (15 puzzle).
/// For even width (4):
/// - blank row from bottom even  => inversions must be odd
/// - blank row from bottom odd   => inversions must be even
/// Which is: blankEven == invOdd
bool isSolvable15(List<int> tiles) {
  int inv = 0;
  final arr = tiles.where((x) => x != 0).toList(growable: false);
  for (int i = 0; i < arr.length; i++) {
    for (int j = i + 1; j < arr.length; j++) {
      if (arr[i] > arr[j]) inv++;
    }
  }

  final blankIndex = tiles.indexOf(0);
  final blankRowFromBottom = 4 - (blankIndex ~/ 4); // 1..4

  final blankEven = (blankRowFromBottom % 2 == 0);
  final invOdd = (inv % 2 == 1);

  // IMPORTANT: equality, not XOR
  return blankEven == invOdd;
}
