import '../lib/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ExampleApp renders diagnostic preview UI correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Flutter Dev Intelligence Demo'), findsOneWidget);
    expect(find.text('Diagnostic Overview'), findsOneWidget);
    expect(find.text('Terminal Report Preview:'), findsOneWidget);
  });
}
