import 'package:flutter/material.dart';

class ExpandedMisuseWidget extends StatelessWidget {
  const ExpandedMisuseWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(child: Expanded(child: const Text('Invalid parent')));
  }
}
