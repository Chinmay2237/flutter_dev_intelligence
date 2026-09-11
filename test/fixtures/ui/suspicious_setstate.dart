import 'package:flutter/material.dart';

class SuspiciousSetStateWidget extends StatefulWidget {
  const SuspiciousSetStateWidget({super.key});

  @override
  State<SuspiciousSetStateWidget> createState() =>
      _SuspiciousSetStateWidgetState();
}

class _SuspiciousSetStateWidgetState extends State<SuspiciousSetStateWidget> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    setState(() {
      _counter++;
    });
    return Text('Count: $_counter');
  }
}
