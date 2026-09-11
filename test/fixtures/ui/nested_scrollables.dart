import 'package:flutter/widgets.dart';

Widget buildNested() {
  return ListView(
    children: <Widget>[
      GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
        ),
        itemCount: 2,
        itemBuilder: (context, index) => const Text('item'),
      ),
      const SizedBox(width: 1200, height: 16),
    ],
  );
}
