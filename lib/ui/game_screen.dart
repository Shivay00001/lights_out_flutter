import 'package:flutter/material.dart';
import '../game_logic.dart';
import 'animated_background.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameLogic game = GameLogic(); // Simple dependency injection

  @override
  Widget build(BuildContext context) {
    // Rebuild UI when game notifies listeners
    return ListenableBuilder(
      listenable: game,
      builder: (context, child) {
        if (game.isWon) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showWinDialog(context);
          });
        }
        
        return Scaffold(
          body: AnimatedGradientBackground(
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'LIGHTS OUT',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 4,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black45)],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildStatsRow(),
                    const SizedBox(height: 40),
                    _buildGrid(),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: game.newGame,
                      icon: const Icon(Icons.refresh),
                      label: const Text('NEW GAME'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('MOVES', '${game.moves}'),
        _buildStatItem('BEST', '${game.bestScore == 0 ? "-" : game.bestScore}'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    // 5x5 grid usually, game logic default
    double gridSize = 300;
    
    return Container(
      width: gridSize,
      height: gridSize,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: game.gridSize * game.gridSize,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: game.gridSize,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          int r = index ~/ game.gridSize;
          int c = index % game.gridSize;
          bool isOn = game.grid[r][c];
          
          return GestureDetector(
            onTap: () => game.toggleLight(r, c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isOn ? Colors.yellowAccent : Colors.white10,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isOn
                    ? [
                        BoxShadow(
                          color: Colors.yellowAccent.withOpacity(0.6),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showWinDialog(BuildContext context) {
      // Prevent multiple dialogs if already showing or handled
      // But in this simple logic, we just show it. Ideally we should have a 'dialogShown' state in logic or here.
      // For now, we rely on game.isWon state. We should reset it or ignore.
      // Actually, since build is called repeatedly, this is risky.
      // Better way: show dialog only when transitioning to win.
      // However, for this simple task, let's just make the dialog modal and reset game on close.
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('You Won!'),
           content: Text('Completed in ${game.moves} moves.'),
           actions: [
             TextButton(
               onPressed: () {
                 Navigator.of(context).pop();
                 game.newGame();
               },
               child: const Text('PLAY AGAIN'),
             ),
           ],
        ),
      );
  }
}
