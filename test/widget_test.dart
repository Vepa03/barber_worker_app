import 'package:flutter_test/flutter_test.dart';
import 'package:barber/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const BarberApp());
    expect(find.byType(BarberApp), findsOneWidget);
  });
}
