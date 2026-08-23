import 'package:flutter_test/flutter_test.dart';
import 'package:kkolttak/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets("shows app name and today's dose list", (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SupplementStore(await SharedPreferences.getInstance());
    final notifications = NotificationService();

    await tester.pumpWidget(
      KkolttakApp(store: store, notifications: notifications),
    );

    expect(find.text('KKOLTTAK'), findsOneWidget);
    expect(find.text('오늘 꼴딱할 것'), findsOneWidget);
  });
}
