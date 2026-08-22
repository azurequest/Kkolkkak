import 'package:flutter_test/flutter_test.dart';
import 'package:kkolkkak/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets("shows app name and today's dose list", (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SupplementStore(await SharedPreferences.getInstance());
    final notifications = NotificationService();

    await tester.pumpWidget(
      KkolkkakApp(store: store, notifications: notifications),
    );

    expect(find.text('Kkolkkak'), findsOneWidget);
    expect(find.text('오늘 꼴깍할 것'), findsOneWidget);
  });
}
