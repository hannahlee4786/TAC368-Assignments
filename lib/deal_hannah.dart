import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Deal or No Deal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: DealBloc(),
    );
  }
}

class Suitcase {
  final int number;
  final int value;
  final bool opened;
  final bool held;

  Suitcase({
    required this.number,
    required this.value,
    this.opened = false,
    this.held = false,
  });

  Suitcase copyWith({
    int? number,
    int? value,
    bool? opened,
    bool? held,
  }) {
    return Suitcase(
      number: number ?? this.number,
      value: value ?? this.value,
      opened: opened ?? this.opened,
      held: held ?? this.held,
    );
  }
}

class DealState {
  final List<Suitcase> suitcases;
  final String message;
  final String phase; // chooseHold, chooseOpen, offerShown, finished
  final int? heldCaseNumber;
  final double offer;

  DealState({
    required this.suitcases,
    required this.message,
    required this.phase,
    required this.heldCaseNumber,
    required this.offer,
  });
}

class DealCubit extends Cubit<DealState> {
  DealCubit() : super(_initialState()) {
    newGame();
  }

  static DealState _initialState() {
    return DealState(
      suitcases: [],
      message: '',
      phase: 'chooseHold',
      heldCaseNumber: null,
      offer: 0,
    );
  }

  final List<int> _values = [
    1,
    5,
    10,
    100,
    1000,
    5000,
    10000,
    100000,
    500000,
    1000000,
  ];

  void newGame() {
    final shuffledValues = List<int>.from(_values)..shuffle(Random());

    final cases = List.generate(10, (index) {
      return Suitcase(
        number: index + 1,
        value: shuffledValues[index],
      );
    });

    emit(
      DealState(
        suitcases: cases,
        message: 'Pick one suitcase to hold.',
        phase: 'chooseHold',
        heldCaseNumber: null,
        offer: 0,
      ),
    );
  }

  Suitcase? get heldCase {
    if (state.heldCaseNumber == null) return null;
    try {
      return state.suitcases.firstWhere((c) => c.number == state.heldCaseNumber);
    } catch (_) {
      return null;
    }
  }

  double calculateOffer() {
    final remaining = state.suitcases.where((c) => !c.opened).toList();
    final total = remaining.fold<int>(0, (sum, c) => sum + c.value);
    final average = total / remaining.length;
    return average * 0.9;
  }

  void chooseHold(int number) {
    if (state.phase != 'chooseHold') return;

    final updated = state.suitcases.map((c) {
      if (c.number == number) {
        return c.copyWith(held: true);
      }
      return c;
    }).toList();

    emit(
      DealState(
        suitcases: updated,
        message: 'You are holding suitcase $number. Now open one other suitcase.',
        phase: 'chooseOpen',
        heldCaseNumber: number,
        offer: 0,
      ),
    );
  }

  void openCase(int number) {
    if (state.phase != 'chooseOpen') return;
    if (number == state.heldCaseNumber) return;

    final suitcase = state.suitcases.firstWhere((c) => c.number == number);
    if (suitcase.opened) return;

    final updated = state.suitcases.map((c) {
      if (c.number == number) {
        return c.copyWith(opened: true);
      }
      return c;
    }).toList();

    final offer = calculateOffer();

    emit(
      DealState(
        suitcases: updated,
        message: 'Opened suitcase $number. Dealer offer is \$${offer.toStringAsFixed(2)}.',
        phase: 'offerShown',
        heldCaseNumber: state.heldCaseNumber,
        offer: offer,
      ),
    );
  }

  void deal() {
    if (state.phase != 'offerShown') return;

    emit(
      DealState(
        suitcases: state.suitcases,
        message: 'DEAL accepted. You won \$${state.offer.toStringAsFixed(2)}.',
        phase: 'finished',
        heldCaseNumber: state.heldCaseNumber,
        offer: state.offer,
      ),
    );
  }

  void noDeal() {
    if (state.phase != 'offerShown') return;

    final remainingOpenCases = state.suitcases.where(
      (c) => !c.opened && c.number != state.heldCaseNumber,
    ).toList();

    if (remainingOpenCases.isEmpty) {
      final held = heldCase;
      emit(
        DealState(
          suitcases: state.suitcases,
          message: 'No deal. Your held suitcase wins \$${held?.value ?? 0}.',
          phase: 'finished',
          heldCaseNumber: state.heldCaseNumber,
          offer: state.offer,
        ),
      );
      return;
    }

    emit(
      DealState(
        suitcases: state.suitcases,
        message: 'No deal. Pick another suitcase to open.',
        phase: 'chooseOpen',
        heldCaseNumber: state.heldCaseNumber,
        offer: 0,
      ),
    );
  }

  void handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (state.phase == 'finished') return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.keyD) {
      deal();
      return;
    }

    if (key == LogicalKeyboardKey.keyN) {
      noDeal();
      return;
    }

    final number = _keyToNumber(key);
    if (number == null) return;

    if (state.phase == 'chooseHold') {
      chooseHold(number);
    } else if (state.phase == 'chooseOpen') {
      openCase(number);
    }
  }

  int? _keyToNumber(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.digit1) return 1;
    if (key == LogicalKeyboardKey.digit2) return 2;
    if (key == LogicalKeyboardKey.digit3) return 3;
    if (key == LogicalKeyboardKey.digit4) return 4;
    if (key == LogicalKeyboardKey.digit5) return 5;
    if (key == LogicalKeyboardKey.digit6) return 6;
    if (key == LogicalKeyboardKey.digit7) return 7;
    if (key == LogicalKeyboardKey.digit8) return 8;
    if (key == LogicalKeyboardKey.digit9) return 9;
    if (key == LogicalKeyboardKey.digit0) return 10;
    return null;
  }
}

class DealBloc extends StatelessWidget {
  DealBloc({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DealCubit(),
      child: const DealPage(),
    );
  }
}

class DealPage extends StatefulWidget {
  const DealPage({super.key});

  @override
  State<DealPage> createState() => _DealPageState();
}

class _DealPageState extends State<DealPage> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Widget buildSuitcaseButton(BuildContext context, Suitcase suitcase, DealState state) {
    final isHeld = suitcase.number == state.heldCaseNumber;

    Color bg;
    if (suitcase.opened) {
      bg = Colors.grey;
    } else if (isHeld) {
      bg = Colors.orange;
    } else {
      bg = Colors.blueGrey;
    }

    final canPick = state.phase == 'chooseHold' ||
        (state.phase == 'chooseOpen' && !suitcase.opened && !isHeld);

    return ElevatedButton(
      onPressed: canPick
          ? () {
              final cubit = context.read<DealCubit>();
              if (state.phase == 'chooseHold') {
                cubit.chooseHold(suitcase.number);
              } else if (state.phase == 'chooseOpen') {
                cubit.openCase(suitcase.number);
              }
            }
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${suitcase.number}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            suitcase.opened
                ? '\$${suitcase.value}'
                : isHeld
                    ? 'HOLD'
                    : 'CASE',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget buildValueRow(Suitcase suitcase) {
    return BlocBuilder<DealCubit, DealState>(
      builder: (context, state) {
        final isRevealed = suitcase.opened;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isRevealed ? Colors.grey.shade200 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '\$${suitcase.value}',
                  style: TextStyle(
                    color: isRevealed ? Colors.grey : Colors.black,
                    fontWeight: isRevealed ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ),
              Text(isRevealed ? 'revealed' : 'hidden'),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        context.read<DealCubit>().handleKey(event);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Deal or No Deal'),
          centerTitle: true,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BlocBuilder<DealCubit, DealState>(
                builder: (context, state) {
                  final held = state.heldCaseNumber ?? '--';
                  final offerText = state.phase == 'offerShown'
                      ? '\$${state.offer.toStringAsFixed(2)}'
                      : '--';

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Keyboard: d = DEAL, n = NO DEAL, 1-9 and 0 = suitcase 10',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  'Dealer offer: $offerText',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Held suitcase: $held'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 5,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.1,
                          children: state.suitcases
                              .map((suitcase) => buildSuitcaseButton(context, suitcase, state))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Values in order',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...(() {
                                  List<Suitcase> sorted = List.from(state.suitcases);
                                  sorted.sort((a, b) => a.value.compareTo(b.value));
                                  return sorted.map((s) => buildValueRow(s));
                                })(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (state.phase == 'offerShown')
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => context.read<DealCubit>().deal(),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(60),
                                    textStyle: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  child: const Text('DEAL'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => context.read<DealCubit>().noDeal(),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(60),
                                    textStyle: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  child: const Text('NO DEAL'),
                                ),
                              ),
                            ],
                          ),
                        if (state.phase == 'finished')
                          Card(
                            color: Colors.amber.shade100,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Column(
                                  children: [
                                    Text(
                                      state.message,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () => context.read<DealCubit>().newGame(),
                                      child: const Text('New Game'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}