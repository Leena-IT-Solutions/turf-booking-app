import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turf_booking/screens/main/profile_tab.dart';

void main() {
  void setTestScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget buildTestableProfileTab({
    String userName = 'Sandeep Rathod',
    String userEmail = 'sandeep198558@gmail.com',
    String userMobile = '9664588677',
    VoidCallback? onEditProfile,
    VoidCallback? onChangePassword,
    VoidCallback? onDeleteAccount,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ProfileTab(
          userName: userName,
          userEmail: userEmail,
          userMobile: userMobile,
          onEditProfile: onEditProfile ?? () {},
          onChangePassword: onChangePassword ?? () {},
          onDeleteAccount: onDeleteAccount ?? () {},
        ),
      ),
    );
  }

  group('ProfileTab Tests', () {
    testWidgets('renders user details (name, email, mobile)', (WidgetTester tester) async {
      setTestScreenSize(tester);

      await tester.pumpWidget(buildTestableProfileTab(
        userName: 'Sandeep Rathod',
        userEmail: 'sandeep198558@gmail.com',
        userMobile: '9664588677',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sandeep Rathod'), findsOneWidget);
      expect(find.text('sandeep198558@gmail.com'), findsNWidgets(2));
      expect(find.text('9664588677'), findsOneWidget);
      expect(find.text('Edit Personal Details'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Delete My Account'), findsOneWidget);
    });

    testWidgets('triggers onEditProfile callback when tile is tapped', (WidgetTester tester) async {
      setTestScreenSize(tester);
      bool editTapped = false;

      await tester.pumpWidget(buildTestableProfileTab(
        onEditProfile: () => editTapped = true,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Edit Personal Details'));
      await tester.tap(find.text('Edit Personal Details'));
      await tester.pumpAndSettle();

      expect(editTapped, isTrue);
    });

    testWidgets('triggers onChangePassword callback when tile is tapped', (WidgetTester tester) async {
      setTestScreenSize(tester);
      bool changePassTapped = false;

      await tester.pumpWidget(buildTestableProfileTab(
        onChangePassword: () => changePassTapped = true,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Change Password'));
      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();

      expect(changePassTapped, isTrue);
    });

    testWidgets('triggers onDeleteAccount callback when tile is tapped', (WidgetTester tester) async {
      setTestScreenSize(tester);
      bool deleteTapped = false;

      await tester.pumpWidget(buildTestableProfileTab(
        onDeleteAccount: () => deleteTapped = true,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete My Account'));
      await tester.tap(find.text('Delete My Account'));
      await tester.pumpAndSettle();

      expect(deleteTapped, isTrue);
    });
  });
}
