import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameLogic extends ChangeNotifier {
  final int gridSize;
  late List<List<bool>> grid;
  int moves = 0;
  int bestScore = 0;
  bool isWon = false;
  final Random _random = Random();

  GameLogic({this.gridSize = 5}) {
    _initGrid();
    _loadBestScore();
  }

  void _initGrid() {
    // Initialize all off
    grid = List.generate(gridSize, (_) => List.filled(gridSize, false));
    moves = 0;
    isWon = false;
    notifyListeners();
  }

  void newGame() {
    _initGrid();
    // Randomize
    // We toggle random lights to ensure the board is solvable
    for (int i = 0; i < 20; i++) {
      int r = _random.nextInt(gridSize);
      int c = _random.nextInt(gridSize);
      _toggle(r, c, recordMove: false);
    }
    moves = 0; // Reset moves after shuffling
    isWon = false;
    notifyListeners();
  }

  void toggleLight(int row, int col) {
    if (isWon) return;
    
    _toggle(row, col);
    moves++;
    _checkWin();
    notifyListeners();
  }

  void _toggle(int row, int col, {bool recordMove = true}) {
    // Toggle self
    if (row >= 0 && row < gridSize && col >= 0 && col < gridSize) {
      grid[row][col] = !grid[row][col];
    }
    // Toggle neighbors
    int? dirs = 4;
    List<List<int>> offsets = [
      [-1, 0], [1, 0], [0, -1], [0, 1]
    ];
    
    for (var offset in offsets) {
      int r = row + offset[0];
      int c = col + offset[1];
      if (r >= 0 && r < gridSize && c >= 0 && c < gridSize) {
        grid[r][c] = !grid[r][c];
      }
    }
  }

  void _checkWin() {
    bool allOff = true;
    for (var row in grid) {
      for (var val in row) {
        if (val) {
          allOff = false;
          break;
        }
      }
    }
    
    if (allOff) {
      isWon = true;
      _updateBestScore();
    }
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    bestScore = prefs.getInt('best_score_v1') ?? 0;
    notifyListeners();
  }

  Future<void> _updateBestScore() async {
    if (bestScore == 0 || moves < bestScore) {
      bestScore = moves;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('best_score_v1', bestScore);
      notifyListeners();
    }
  }
}
