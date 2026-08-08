import 'package:flutter_test/flutter_test.dart';
import 'package:duka_smart_app/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    await tester.pumpWidget(const HardwareStoreApp());
  });
}