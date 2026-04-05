import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

const int boardSize = 10;
const int rackSize = 7;
const int port = 9203;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Scrabble Lite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const RoleSelectPage(),
    );
  }
}

class GameSnapshot {
  final List<List<String?>> board;
  final List<List<String>> racks;
  final List<String> bag;
  final int currentTurn;
  final List<int> scores;
  final String message;

  GameSnapshot({
    required this.board,
    required this.racks,
    required this.bag,
    required this.currentTurn,
    required this.scores,
    required this.message,
  });

  GameSnapshot copyWith({
    List<List<String?>>? board,
    List<List<String>>? racks,
    List<String>? bag,
    int? currentTurn,
    List<int>? scores,
    String? message,
  }) {
    return GameSnapshot(
      board: board ?? this.board,
      racks: racks ?? this.racks,
      bag: bag ?? this.bag,
      currentTurn: currentTurn ?? this.currentTurn,
      scores: scores ?? this.scores,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'board': board,
      'racks': racks,
      'bag': bag,
      'currentTurn': currentTurn,
      'scores': scores,
      'message': message,
    };
  }

  factory GameSnapshot.fromJson(Map<String, dynamic> json) {
    final boardJson = json['board'] as List<dynamic>;
    final racksJson = json['racks'] as List<dynamic>;

    final board = boardJson
        .map(
          (row) => (row as List<dynamic>)
              .map((cell) => cell == null ? null : cell.toString())
              .toList(),
        )
        .toList();

    final racks = racksJson
        .map(
          (rack) => (rack as List<dynamic>)
              .map((cell) => cell.toString())
              .toList(),
        )
        .toList();

    return GameSnapshot(
      board: board,
      racks: racks,
      bag: (json['bag'] as List<dynamic>).map((e) => e.toString()).toList(),
      currentTurn: json['currentTurn'] as int,
      scores: (json['scores'] as List<dynamic>).map((e) => e as int).toList(),
      message: json['message'] as String,
    );
  }
}

class ScrabbleController extends ChangeNotifier {
  final bool isHost;
  final String hostIp;
  final int localPlayer;

  ScrabbleController({
    required this.isHost,
    required this.hostIp,
  }) : localPlayer = isHost ? 1 : 2 {
    _createNewGame();
  }

  Socket? _socket;
  ServerSocket? _server;
  String _buffer = '';

  String connectionStatus = 'Not connected';
  GameSnapshot? snapshot;
  int? selectedRackIndex;

  final List<String> _bagTemplate = _buildBag();

  static List<String> _buildBag() {
    final letters = <String>[];

    void add(String letter, int count) {
      for (int i = 0; i < count; i++) {
        letters.add(letter);
      }
    }

    add('E', 12);
    add('A', 9);
    add('I', 9);
    add('O', 8);
    add('N', 6);
    add('R', 6);
    add('T', 6);
    add('L', 4);
    add('S', 4);
    add('U', 4);
    add('D', 4);
    add('G', 3);
    add('B', 2);
    add('C', 2);
    add('M', 2);
    add('P', 2);
    add('F', 2);
    add('H', 2);
    add('V', 2);
    add('W', 2);
    add('Y', 2);
    add('K', 1);
    add('J', 1);
    add('X', 1);
    add('Q', 1);
    add('Z', 1);

    return letters;
  }

  List<List<String?>> _emptyBoard() {
    return List.generate(
      boardSize,
      (_) => List<String?>.filled(boardSize, null),
    );
  }

  List<String> _drawLetters(List<String> bag, int count) {
    final drawn = <String>[];
    while (drawn.length < count && bag.isNotEmpty) {
      drawn.add(bag.removeLast());
    }
    return drawn;
  }

  List<List<String?>> _copyBoard(List<List<String?>> board) {
    return board.map((row) => List<String?>.from(row)).toList();
  }

  List<List<String>> _copyRacks(List<List<String>> racks) {
    return racks.map((rack) => List<String>.from(rack)).toList();
  }

  void _createNewGame() {
    final bag = List<String>.from(_bagTemplate)..shuffle(Random());
    final racks = [
      _drawLetters(bag, rackSize),
      _drawLetters(bag, rackSize),
    ];

    snapshot = GameSnapshot(
      board: _emptyBoard(),
      racks: racks,
      bag: bag,
      currentTurn: 1,
      scores: [0, 0],
      message: 'Player 1 starts. Pick one tile from your rack, then tap a board square.',
    );

    selectedRackIndex = null;
    notifyListeners();
  }

  Future<void> start() async {
    if (isHost) {
      connectionStatus = 'Host ready on port $port. Waiting for client...';
      notifyListeners();

      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _server!.listen((client) {
        _socket = client;
        connectionStatus = 'Client connected.';
        notifyListeners();

        _listenToSocket(client);
        _sendSync();
      });
    } else {
      connectionStatus = 'Connecting to $hostIp:$port ...';
      notifyListeners();

      _socket = await Socket.connect(hostIp, port);
      connectionStatus = 'Connected to host.';
      notifyListeners();

      _listenToSocket(_socket!);
    }
  }

  void _listenToSocket(Socket socket) {
    socket.listen(
      (data) {
        _buffer += utf8.decode(data);

        while (_buffer.contains('\n')) {
          final index = _buffer.indexOf('\n');
          final line = _buffer.substring(0, index).trim();
          _buffer = _buffer.substring(index + 1);

          if (line.isEmpty) continue;
          _handleIncoming(line);
        }
      },
      onDone: () {
        connectionStatus = 'Connection closed.';
        notifyListeners();
      },
      onError: (e) {
        connectionStatus = 'Connection error: $e';
        notifyListeners();
      },
    );
  }

  void _handleIncoming(String raw) {
    try {
      final msg = jsonDecode(raw) as Map<String, dynamic>;
      final type = msg['type'];

      if (type == 'sync') {
        snapshot = GameSnapshot.fromJson(
          msg['snapshot'] as Map<String, dynamic>,
        );
        selectedRackIndex = null;
        notifyListeners();
      }
    } catch (e) {
      connectionStatus = 'Message error: $e';
      notifyListeners();
    }
  }

  void _sendSync() {
    if (_socket == null || snapshot == null) return;

    final msg = jsonEncode({
      'type': 'sync',
      'snapshot': snapshot!.toJson(),
    });

    _socket!.write('$msg\n');
  }

  bool get isMyTurn =>
      snapshot != null && snapshot!.currentTurn == localPlayer;

  List<String> get localRack {
    if (snapshot == null) return [];
    return snapshot!.racks[localPlayer - 1];
  }

  void selectRackIndex(int index) {
    if (!isMyTurn) return;
    if (snapshot == null) return;
    if (index < 0 || index >= localRack.length) return;

    selectedRackIndex = selectedRackIndex == index ? null : index;
    notifyListeners();
  }

  void placeOnBoard(int row, int col) {
    if (!isMyTurn) return;
    if (snapshot == null) return;
    if (selectedRackIndex == null) return;
    if (snapshot!.board[row][col] != null) return;
    if (selectedRackIndex! >= localRack.length) return;

    final board = _copyBoard(snapshot!.board);
    final racks = _copyRacks(snapshot!.racks);
    final scores = List<int>.from(snapshot!.scores);
    final bag = List<String>.from(snapshot!.bag);

    final letter = racks[localPlayer - 1].removeAt(selectedRackIndex!);
    board[row][col] = letter;
    scores[localPlayer - 1] += 1;

    snapshot = snapshot!.copyWith(
      board: board,
      racks: racks,
      bag: bag,
      scores: scores,
      message: 'Player $localPlayer placed "$letter".',
    );

    selectedRackIndex = null;
    SystemSound.play(SystemSoundType.click);
    notifyListeners();
    _sendSync();
  }

  void endTurn() {
    if (!isMyTurn) return;
    if (snapshot == null) return;

    final board = _copyBoard(snapshot!.board);
    final racks = _copyRacks(snapshot!.racks);
    final bag = List<String>.from(snapshot!.bag);
    final scores = List<int>.from(snapshot!.scores);

    final myRack = racks[localPlayer - 1];
    while (myRack.length < rackSize && bag.isNotEmpty) {
      myRack.add(bag.removeLast());
    }

    final nextTurn = localPlayer == 1 ? 2 : 1;

    snapshot = snapshot!.copyWith(
      board: board,
      racks: racks,
      bag: bag,
      currentTurn: nextTurn,
      scores: scores,
      message: 'Player $localPlayer ended the turn. Player $nextTurn goes now.',
    );

    selectedRackIndex = null;
    SystemSound.play(SystemSoundType.click);
    notifyListeners();
    _sendSync();
  }

  void resetGame() {
    if (!isHost) return;
    _createNewGame();
    _sendSync();
  }

  @override
  void dispose() {
    _socket?.destroy();
    _server?.close();
    super.dispose();
  }
}

class RoleSelectPage extends StatefulWidget {
  const RoleSelectPage({super.key});

  @override
  State<RoleSelectPage> createState() => _RoleSelectPageState();
}

class _RoleSelectPageState extends State<RoleSelectPage> {
  final TextEditingController _ipController =
      TextEditingController(text: '127.0.0.1');

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _startHost() {
    final controller = ScrabbleController(
      isHost: true,
      hostIp: _ipController.text.trim(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePage(
          controller: controller,
          title: 'Scrabble Lite - Host',
        ),
      ),
    );
  }

  void _startClient() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    final controller = ScrabbleController(
      isHost: false,
      hostIp: ip,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePage(
          controller: controller,
          title: 'Scrabble Lite - Client',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrabble Lite'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Choose Host or Client',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tap one tile from your rack, then tap a square on the board. Press End Turn when done. The board is 10x10, each player sees only their own rack, and the other computer gets the same board state through the socket connection.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'Host IP',
                    border: OutlineInputBorder(),
                    hintText: '127.0.0.1 for same machine testing',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startHost,
                        child: const Text('Start Host'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startClient,
                        child: const Text('Start Client'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Player 1 starts. The rack refills from the shared bag at the end of each turn.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GamePage extends StatefulWidget {
  final ScrabbleController controller;
  final String title;

  const GamePage({
    super.key,
    required this.controller,
    required this.title,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.start();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  Widget _buildBoardCell(ScrabbleController controller, int row, int col) {
    final snap = controller.snapshot!;
    final letter = snap.board[row][col];
    final isEmpty = letter == null;
    final canTap = controller.isMyTurn;

    return GestureDetector(
      onTap: canTap ? () => controller.placeOnBoard(row, col) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isEmpty ? Colors.white : Colors.orange.shade200,
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            letter ?? '',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildRackTile(ScrabbleController controller, int index) {
    final rack = controller.localRack;
    final hasLetter = index < rack.length;
    final letter = hasLetter ? rack[index] : '';
    final isSelected = controller.selectedRackIndex == index;
    final canTap = controller.isMyTurn && hasLetter;

    return GestureDetector(
      onTap: canTap ? () => controller.selectRackIndex(index) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.shade300
              : hasLetter
                  ? Colors.brown.shade200
                  : Colors.grey.shade200,
          border: Border.all(
            color: isSelected ? Colors.green.shade900 : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            letter,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final snap = controller.snapshot;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            centerTitle: true,
            actions: [
              if (controller.isHost)
                TextButton(
                  onPressed: controller.resetGame,
                  child: const Text('New Game'),
                ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: snap == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            controller.connectionStatus,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              controller.connectionStatus,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snap.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Text(
                                      'Turn: Player ${snap.currentTurn}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text('You are Player ${controller.localPlayer}'),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Scores  —  P1: ${snap.scores[0]}   P2: ${snap.scores[1]}',
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      controller.isMyTurn
                                          ? 'Your turn'
                                          : 'Waiting for opponent...',
                                      style: TextStyle(
                                        color: controller.isMyTurn
                                            ? Colors.green.shade800
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Board',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: boardSize * boardSize,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: boardSize,
                                crossAxisSpacing: 2,
                                mainAxisSpacing: 2,
                                childAspectRatio: 1.5,
                              ),
                              itemBuilder: (context, index) {
                                final row = index ~/ boardSize;
                                final col = index % boardSize;
                                return _buildBoardCell(controller, row, col);
                              },
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Your rack',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 56,
                              child: Row(
                                children: List.generate(
                                  rackSize,
                                  (index) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      child: _buildRackTile(controller, index),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed:
                                  controller.isMyTurn ? controller.endTurn : null,
                              child: const Text('End Turn'),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Rules: no word checking, no special squares, no letter points. Score is just the number of letters placed. Each turn, play any number of your tiles, then press End Turn. Your rack refills from the shared bag after the turn.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}