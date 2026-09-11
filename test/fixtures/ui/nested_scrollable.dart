import 'package:flutter/material.dart';

class NestedScrollableWidget extends StatelessWidget {
  const NestedScrollableWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ListView(
            shrinkWrap: true,
            children: const [Text('Child 1'), Text('Child 2')],
          ),
        ],
      ),
    );
  }
}
