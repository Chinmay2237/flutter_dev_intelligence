import 'package:flutter/material.dart';

class ValidLayoutWidget extends StatelessWidget {
  const ValidLayoutWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Valid Layout')),
      body: Column(
        children: [
          const Text('Header'),
          Expanded(
            child: ListView.builder(
              itemCount: 20,
              itemBuilder: (context, index) =>
                  ListTile(title: Text('Item $index')),
            ),
          ),
        ],
      ),
    );
  }
}
