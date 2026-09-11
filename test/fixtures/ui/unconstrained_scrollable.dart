import 'package:flutter/material.dart';

class UnconstrainedScrollableWidget extends StatelessWidget {
  const UnconstrainedScrollableWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Header'),
        ListView(children: const [Text('Item 1')]),
      ],
    );
  }
}
