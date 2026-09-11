import 'package:flutter/material.dart';

class FalsePositivesWidget extends StatelessWidget {
  const FalsePositivesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Normal Header'),
        SizedBox(
          height: 300,
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) =>
                ListTile(title: Text('Row $index')),
          ),
        ),
      ],
    );
  }
}
