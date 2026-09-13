import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  if (kDebugMode) {
    debugPrint("Guarded debug log");
  }
  print("Raw unguarded log");
}

class MySampleWidget extends StatelessWidget {
  const MySampleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Image.asset('assets/missing_file.png'),
          Image.asset('assets/decorative.png', excludeFromSemantics: true),
          ListView(
            shrinkWrap: true,
            children: const [],
          ),
        ],
      ),
    );
  }
}
