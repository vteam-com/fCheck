import 'package:flutter/material.dart';

// This StatefulWidget file has too many classes - non-compliant

/// A custom counter widget
class CounterWidget extends StatefulWidget {
  const CounterWidget({super.key});

  @override
  State<CounterWidget> createState() => _CounterWidgetState();
}

/// State for CounterWidget
class _CounterWidgetState extends State<CounterWidget> {
  int _count = 0;

  void _increment() {
    setState(() => _count++);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Count: $_count'),
        ElevatedButton(onPressed: _increment, child: const Text('Increment')),
      ],
    );
  }
}

/// An extra class in the StatefulWidget file - makes it non-compliant
class ExtraHelper {
  static String formatCount(int count) {
    return 'Current count: $count';
  }
}

/// Another extra class
class AnotherClass {
  void doNothing() {
    // This method does nothing
  }
}
