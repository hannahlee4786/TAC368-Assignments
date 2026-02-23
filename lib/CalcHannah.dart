import 'package:flutter/material.dart';

void main() {
  runApp(const ConverterApp());
}

class ConverterApp extends StatelessWidget {
  const ConverterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ConverterPage(),
    );
  }
}

class ConverterPage extends StatefulWidget {
  const ConverterPage({Key? key}) : super(key: key);

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  String input = "";
  String output = "";

  void addValue(String value) {
    setState(() {
      input += value;
    });
  }

  void toggleNegative() {
    setState(() {
      if (input.startsWith("-")) {
        input = input.substring(1);
      } else {
        input = "-$input";
      }
    });
  }

  void clearAll() {
    setState(() {
      input = "";
      output = "";
    });
  }

  void convert(String type) {
    if (input.isEmpty) return;

    double value = double.tryParse(input) ?? 0;
    double result = 0;

    switch (type) {
      case "C-F":
        result = (value * 9 / 5) + 32;
        break;
      case "F-C":
        result = (value - 32) * 5 / 9;
        break;
      case "Kg-Lb":
        result = value * 2.20462;
        break;
      case "Lb-Kg":
        result = value / 2.20462;
        break;
    }

    setState(() {
      output = result.toStringAsFixed(4);
    });
  }

  Widget buildButton(String text, {VoidCallback? onPressed}) {
    return SizedBox(
      height: 45,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(4),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Converter"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            // Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // Input box
                Container(
                  width: 120,
                  height: 60,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(width: 2),
                  ),
                  child: Text(
                    input,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),

                // Small divider space
                const SizedBox(width: 4),

                // Output box
                Container(
                  width: 140,
                  height: 60,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(width: 2),
                  ),
                  child: Text(
                    output,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: Row(
                children: [

                  // Number pad
                  Expanded(
                    flex: 2,
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.2,
                      children: [
                        buildButton("7", onPressed: () => addValue("7")),
                        buildButton("8", onPressed: () => addValue("8")),
                        buildButton("9", onPressed: () => addValue("9")),
                        buildButton("4", onPressed: () => addValue("4")),
                        buildButton("5", onPressed: () => addValue("5")),
                        buildButton("6", onPressed: () => addValue("6")),
                        buildButton("1", onPressed: () => addValue("1")),
                        buildButton("2", onPressed: () => addValue("2")),
                        buildButton("3", onPressed: () => addValue("3")),
                        buildButton(".", onPressed: () => addValue(".")),
                        buildButton("0", onPressed: () => addValue("0")),
                        buildButton("-", onPressed: toggleNegative),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Conversion buttons
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 45,
                          child: ElevatedButton(
                            onPressed: () => convert("C-F"),
                            child: const Text("C-F"),
                          ),
                        ),
                        const SizedBox(height: 8),

                        SizedBox(height: 45,
                          child: ElevatedButton(
                            onPressed: () => convert("F-C"),
                            child: const Text("F-C"),
                          ),
                        ),
                        const SizedBox(height: 8),

                        SizedBox(height: 45,
                          child: ElevatedButton(
                            onPressed: () => convert("Kg-Lb"),
                            child: const Text("Kg-Lb"),
                          ),
                        ),
                        const SizedBox(height: 8),

                        SizedBox(height: 45,
                          child: ElevatedButton(
                            onPressed: () => convert("Lb-Kg"),
                            child: const Text("Lb-Kg"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            buildButton("CLEAR", onPressed: clearAll),
          ],
        ),
      ),
    );
  }
}