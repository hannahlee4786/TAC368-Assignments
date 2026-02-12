import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const LightsOutApp());
}

class LightsOutApp extends StatelessWidget {
  const LightsOutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LightsOutPage(),
    );
  }
}

class LightsOutPage extends StatefulWidget {
  const LightsOutPage({super.key});

  @override
  State<LightsOutPage> createState() => _LightsOutPageState();
}

class _LightsOutPageState extends State<LightsOutPage> {
  int numberOfLights = 9;
  List<bool> lights = [];
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    _generateLights();
  }

  void _generateLights() {
    lights = List.generate(
      numberOfLights,
      (_) => random.nextBool(),
    );
    setState(() {});
  }

  void _toggleLight(int index) {
    setState(() {
      // Toggle selected light
      lights[index] = !lights[index];

      // Toggle left neighbor
      if (index - 1 >= 0) {
        lights[index - 1] = !lights[index - 1];
      }

      // Toggle right neighbor
      if (index + 1 < lights.length) {
        lights[index + 1] = !lights[index + 1];
      }
    });

    _checkWin();
  }

  void _checkWin() {
    if (lights.every((light) => light == false)) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("🎉 You Win!"),
          content: const Text("All the lights are out!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _generateLights();
              },
              child: const Text("Play Again"),
            )
          ],
        ),
      );
    }
  }

  void _increaseLights() {
    setState(() {
      numberOfLights++;
    });
    _generateLights();
  }

  void _decreaseLights() {
    if (numberOfLights > 3) {
      setState(() {
        numberOfLights--;
      });
      _generateLights();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lights Out"),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lights row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(lights.length, (index) {
                return GestureDetector(
                  onTap: () => _toggleLight(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: lights[index]
                          ? Colors.yellow
                          : Colors.brown,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 30),

          // Number display
          Text(
            "Number of Lights: $numberOfLights",
            style: const TextStyle(fontSize: 18),
          ),

          const SizedBox(height: 20),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _decreaseLights,
                child: const Text("−"),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: _increaseLights,
                child: const Text("+"),
              ),
            ],
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _generateLights,
            child: const Text("New Game"),
          ),
        ],
      ),
    );
  }
}
