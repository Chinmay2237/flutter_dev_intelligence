// ignore_for_file: unused_element, unused_field

import 'dart:async';
import 'package:flutter/material.dart';

class ValidLifecycleWidget extends StatefulWidget {
  const ValidLifecycleWidget({super.key, required this.externalController});
  final TextEditingController externalController;

  @override
  State<ValidLifecycleWidget> createState() => _ValidLifecycleWidgetState();
}

class _ValidLifecycleWidgetState extends State<ValidLifecycleWidget> {
  late final TextEditingController _textController;
  late final AnimationController _animController;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    _animController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _safeAsync() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _textController);
  }
}

class InvalidLifecycleWidget extends StatefulWidget {
  const InvalidLifecycleWidget({super.key});

  @override
  State<InvalidLifecycleWidget> createState() => _InvalidLifecycleWidgetState();
}

class _InvalidLifecycleWidgetState extends State<InvalidLifecycleWidget> {
  final TextEditingController _leakedController = TextEditingController();
  late StreamSubscription _leakedSub;

  Future<void> _unsafeAsync() async {
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _leakedController);
  }
}
