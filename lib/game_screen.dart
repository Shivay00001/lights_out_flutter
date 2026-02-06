import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Grid = List<List<bool>>;
typedef SizeOption = int; // constrained to 4, 5, 6 via UI

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const List<SizeOption> sizeOptions = [4, 5, 6];

  late SizeOption _size;
  late Grid _grid;
  int _moves = 0;
  bool _won = false;
  int? _best;

  // Animated background intensity (0..1 based on how many are ON)
  double get _intensity {
    final total = _size * _size;
    final on = _grid.expand((row) => row).where((v) => v).length;
    return total == 0 ? 0 : on / total;
  }

  String get _bestKey => 'lightsout_best_$_size';

  @override
  void initState() {
    super.initState();
    _size = 5;
    _grid = _createEmptyGrid(_size);
    // Start with randomized game and load best
    _newGame(_size);
  }

  Grid _createEmptyGrid(SizeOption size) {
    return List.generate(size, (_) => List.generate(size, (_) => false));
  }

  Grid _toggleAt(Grid grid, int r, int c) {
    final size = grid.length;
    final next = grid.map((row) => List<bool>.from(row)).toList();

    void toggleCell(int rr, int cc) {
      if (rr >= 0 && rr < size && cc >= 0 && cc < size) {
        next[rr][cc] = !next[rr][cc];
      }
    }

    toggleCell(r, c);
    toggleCell(r - 1, c);
    toggleCell(r + 1, c);
    toggleCell(r, c - 1);
    toggleCell(r, c + 1);

    return next;
  }

  bool _isSolved(Grid grid) {
    for (final row in grid) {
      for (final cell in row) {
        if (cell) return false;
      }
    }
    return true;
  }

  Grid _randomize(SizeOption s) {
    // Start solved and apply N random toggles -> guaranteed solvable
    Grid next = _createEmptyGrid(s);
    final toggles = max(6, s * s); // difficulty scaling
    final rand = Random.secure();
    for (int i = 0; i < toggles; i++) {
      final r = rand.nextInt(s);
      final c = rand.nextInt(s);
      next = _toggleAt(next, r, c);
    }
    return next;
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getInt(_bestKey);
    setState(() {
      _best = raw;
    });
  }

  Future<void> _saveBestIfBetter(int finalMoves) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentBest = prefs.getInt(_bestKey);
      if (currentBest == null || finalMoves < currentBest) {
        await prefs.setInt(_bestKey, finalMoves);
        setState(() {
          _best = finalMoves;
        });
      }
    } catch (_) {
      // ignore write failures
    }
  }

  Future<void> _newGame(SizeOption s) async {
    setState(() {
      _size = s;
      _grid = _randomize(s);
      _moves = 0;
      _won = false;
    });
    await _loadBest();
  }

  void _handleToggle(int r, int c) {
    if (_won) return;
    HapticFeedback.selectionClick();
    setState(() {
      _grid = _toggleAt(_grid, r, c);
      final nowSolved = _isSolved(_grid);
      if (nowSolved) {
        _won = true;
        _moves += 1;
        _saveBestIfBetter(_moves);
        HapticFeedback.mediumImpact();
      } else {
        _moves += 1;
      }
    });
  }

  void _resetToSolved() {
    setState(() {
      _grid = _createEmptyGrid(_size);
      _moves = 0;
      _won = false;
    });
  }

  // Fancy accent based on tile position
  LinearGradient _accentFor(int r, int c) {
    final even = (r + c) % 2 == 0;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: even
          ? const [Color(0xFF6366F1), Color(0xFF9B5DE5)] // indigo -> purple
          : const [Color(0xFFFF5DA2), Color(0xFFFF6F91)] // pink -> rose
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.ease,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4F46E5), // indigo-600
                  Color(0xFF9333EA), // purple-600
                  Color(0xFFEC4899), // pink-500
                ],
              ),
            ),
            transform: Matrix4.identity()
              ..scale(1 + _intensity * 0.06)
              ..setEntry(3, 2, 0.001),
          ),
          // Soft blobs
          Positioned(
            top: -MediaQuery.of(context).size.height * 0.33,
            left: -MediaQuery.of(context).size.width * 0.33,
            child: _Blob(
              diameter: min(
                MediaQuery.of(context).size.height * 0.7,
                MediaQuery.of(context).size.width * 0.7,
              ),
              color: Colors.pink.withOpacity(0.2),
            ),
          ),
          Positioned(
            bottom: -MediaQuery.of(context).size.height * 0.33,
            right: -MediaQuery.of(context).size.width * 0.33,
            child: _Blob(
              diameter: min(
                MediaQuery.of(context).size.height * 0.7,
                MediaQuery.of(context).size.width * 0.7,
              ),
              color: Colors.indigo.withOpacity(0.2),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _HeaderCard(
                        size: _size,
                        moves: _moves,
                        best: _best,
                        onNewGame: () => _newGame(_size),
                        onPickSize: (s) => _newGame(s),
                      ),
                      const SizedBox(height: 16),
                      _BoardCard(
                        size: _size,
                        grid: _grid,
                        won: _won,
                        accentFor: _accentFor,
                        onToggle: _handleToggle,
                        onResetToSolved: _resetToSolved,
                        onShuffle: () => _newGame(_size),
                        best: _best,
                        moves: _moves,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Crafted with Flutter. Local best score only.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final SizeOption size;
  final int moves;
  final int? best;
  final VoidCallback onNewGame;
  final ValueChanged<SizeOption> onPickSize;

  const _HeaderCard({
    required this.size,
    required this.moves,
    required this.best,
    required this.onNewGame,
    required this.onPickSize,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: Colors.white.withOpacity(0.08),
      elevation: 8,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    runSpacing: 8,
                    children: const [
                      Text(
                        'Lights Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Toggle a cell to flip it and its neighbors. Turn off all lights to win.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _SizePicker(
                  active: size,
                  onPickSize: onPickSize,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatChip(label: 'Moves', value: '$moves'),
                const SizedBox(width: 8),
                _StatChip(label: 'Best', value: best?.toString() ?? '—'),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: cs.primary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: onNewGame,
                  child: const Text('New Game'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final SizeOption size;
  final Grid grid;
  final bool won;
  final LinearGradient Function(int r, int c) accentFor;
  final void Function(int r, int c) onToggle;
  final VoidCallback onResetToSolved;
  final VoidCallback onShuffle;
  final int? best;
  final int moves;

  const _BoardCard({
    required this.size,
    required this.grid,
    required this.won,
    required this.accentFor,
    required this.onToggle,
    required this.onResetToSolved,
    required this.onShuffle,
    required this.best,
    required this.moves,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      color: Colors.white.withOpacity(0.08),
      elevation: 8,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          children: [
            if (won)
              Column(
                children: [
                  const Text(
                    'You won! 🎉',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (best != null && moves <= (best ?? 0))
                        ? 'New personal best!'
                        : 'Can you beat your best score?',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: cs.primary,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        onPressed: onShuffle,
                        child: const Text('Play Again'),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        onPressed: onShuffle,
                        child: const Text('Shuffle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final spacing = 10.0;
                final totalSpacingX = (size - 1) * spacing;
                final tileWidth = (constraints.maxWidth - totalSpacingX) / size;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: size * size,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: size,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final r = index ~/ size;
                    final c = index % size;
                    final on = grid[r][c];
                    final gradient = accentFor(r, c);

                    return Semantics(
                      label: 'Cell ${r + 1}, ${c + 1} ${on ? 'on' : 'off'}',
                      button: true,
                      child: InkWell(
                        onTap: () => onToggle(r, c),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: on
                                  ? Colors.white.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.2),
                            ),
                            gradient: on ? gradient : null,
                            color: on
                                ? null
                                : Colors.white.withOpacity(0.05), // off state color
                            boxShadow: on
                                ? [
                                    const BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              if (on)
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color.fromARGB(38, 255, 255, 255),
                                          blurRadius: 40,
                                          spreadRadius: -4,
                                          inset: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Center(
                                child: Text(
                                  on ? ' ' : ' ',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 14),
            if (!won)
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tip: Corners and edges behave differently—plan your path!',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: onResetToSolved,
                    child: const Text('Reset to Solved'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SizePicker extends StatelessWidget {
  final SizeOption active;
  final ValueChanged<SizeOption> onPickSize;

  const _SizePicker({
    required this.active,
    required this.onPickSize,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      children: [4, 5, 6].map((s) {
        final selected = s == active;
        return Semantics(
          label: 'Grid size $s by $s ${selected ? 'selected' : ''}',
          button: true,
          child: ChoiceChip(
            selected: selected,
            label: Text('$s×$s'),
            onSelected: (_) => onPickSize(s),
            selectedColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.1),
            labelStyle: TextStyle(
              color: selected ? cs.primary : Colors.white,
              fontWeight: FontWeight.w600,
            ),
            shape: const StadiumBorder(),
          ),
        );
      }).toList(),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double diameter;
  final Color color;

  const _Blob({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: diameter,
      width: diameter,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(diameter / 2),
        boxShadow: const [
          BoxShadow(blurRadius: 40, spreadRadius: 2),
        ],
      ),
    );
  }
}
