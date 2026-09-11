import 'package:flutter/material.dart';

class OversizedDimensionWidget extends StatelessWidget {
  const OversizedDimensionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1500,
      height: 2000,
      child: const Text('Oversized Box'),
    );
  }
}
