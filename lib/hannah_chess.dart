import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ChessApp());
}

// Root application widget
class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChessBoard(),
    );
  }
}

// Stateful widget because the chess board changes over time
class ChessBoard extends StatefulWidget {
  const ChessBoard({super.key});

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {

  // 8x8 board represented as a 2D list of strings.
  List<List<String>> board = [];

  // Stores currently selected piece location
  int? selectedRow;
  int? selectedCol;

  @override
  void initState() {
    super.initState();

    // Attempt to load saved game when app starts.
    // If no saved game exists, a new board will be created.
    _loadGame();
  }

  // Returns a new chess board in standard starting position.
  List<List<String>> _initialBoard() {
    return [
      ["br","bn","bb","bq","bk","bb","bn","br"],
      List.filled(8, "bp"),
      List.filled(8, ""),
      List.filled(8, ""),
      List.filled(8, ""),
      List.filled(8, ""),
      List.filled(8, "wp"),
      ["wr","wn","wb","wq","wk","wb","wn","wr"],
    ];
  }

  // Saves the current board state to local storage.
  // The board is converted to JSON and stored using SharedPreferences.
  Future<void> _saveGame() async {
    final prefs = await SharedPreferences.getInstance();

    // Convert 2D list into JSON string
    String encodedBoard = jsonEncode(board);

    // Store the JSON string under the key "chess_board"
    await prefs.setString("chess_board", encodedBoard);
  }

  // Loads the board state from local storage.
  // If no saved state exists, initializes a new board.
  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();

    // Retrieve saved JSON string
    String? savedBoard = prefs.getString("chess_board");

    setState(() {
      if (savedBoard != null) {
        // Decode JSON string back into 2D list
        board = List<List<String>>.from(
          jsonDecode(savedBoard).map(
            (row) => List<String>.from(row),
          ),
        );
      } else {
        // If nothing saved, create a new board
        board = _initialBoard();
      }
    });
  }

  // Handles square tap logic.
  // First tap selects a piece.
  // Second tap moves selected piece to new square.
  void _onSquareTap(int row, int col) {
    setState(() {

      // If no piece is currently selected
      if (selectedRow == null) {

        // Only allow selection if square is not empty
        if (board[row][col] != "") {
          selectedRow = row;
          selectedCol = col;
        }

      } else {

        // Move piece to new square
        board[row][col] = board[selectedRow!][selectedCol!];

        // Clear original square
        board[selectedRow!][selectedCol!] = "";

        // Reset selection
        selectedRow = null;
        selectedCol = null;

        // Save updated board state after move
        _saveGame();
      }
    });
  }

  // Returns alternating colors to create a checkerboard pattern.
  Color _squareColor(int row, int col) {
    return (row + col) % 2 == 0
        ? Colors.brown[300]!
        : Colors.brown[700]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hydrate Chess")),

      body: board.isEmpty
          ? const Center(child: CircularProgressIndicator())

          // Build an 8x8 grid
          : GridView.builder(
              itemCount: 64,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
              ),
              itemBuilder: (context, index) {

                int row = index ~/ 8;
                int col = index % 8;

                return GestureDetector(
                  onTap: () => _onSquareTap(row, col),

                  child: Container(
                    color: _squareColor(row, col),
                    child: Center(
                      child: Text(
                        board[row][col],
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
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
