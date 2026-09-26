// The app shell with a fake cloud connection: signing in, the five tabs,
// and signing out.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_mobile/app.dart';
import 'package:owner_mobile/presentation/screens/more/more_screen.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/testing/fake_cloud_sync_repository.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

/// Pumps the app at an iPhone 15's screen size.
Future<FakeCloudSyncRepository> _pumpApp(WidgetTester tester, {CloudSyncState? initial}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final cloud = FakeCloudSyncRepository(initial: initial ?? CloudSyncState.signedOut);
  final sync = CloudSyncViewModel(cloud, onRemoteChanges: () async {});
  await sync.load();
  await tester.pumpWidget(OwnerApp(cloudSync: sync));
  await tester.pumpAndSettle();
  return cloud;
}

const _connected = CloudSyncState(status: CloudStatus.upToDate, email: 'owner@example.com');

void main() {
  testWidgets('signing in with the wrong password shows why and stays on sign-in', (tester) async {
    await _pumpApp(tester);

    await tester.enterText(find.byType(CupertinoTextFormFieldRow).at(0), 'owner@example.com');
    await tester.enterText(find.byType(CupertinoTextFormFieldRow).at(1), 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text("That email and password don't match."), findsOneWidget);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('an empty email is caught before signing in', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text("Enter the account's email."), findsOneWidget);
  });

  testWidgets('a good sign-in opens the five tabs', (tester) async {
    await _pumpApp(tester);

    await tester.enterText(find.byType(CupertinoTextFormFieldRow).at(0), 'owner@example.com');
    await tester.enterText(find.byType(CupertinoTextFormFieldRow).at(1), FakeCloudSyncRepository.goodPassword);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final tab in ['Today', 'Sales', 'Stock', 'Money', 'More']) {
      expect(find.text(tab), findsWidgets, reason: tab);
    }
  });

  testWidgets('each tab opens without layout errors', (tester) async {
    await _pumpApp(tester, initial: _connected);

    for (final tab in ['Sales', 'Stock', 'Money', 'More', 'Today']) {
      await tester.tap(find.descendant(of: find.byType(CupertinoTabBar), matching: find.text(tab)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('More shows the account, and signing out asks first', (tester) async {
    await _pumpApp(tester, initial: _connected);
    await tester.tap(find.descendant(of: find.byType(CupertinoTabBar), matching: find.text('More')));
    await tester.pumpAndSettle();
    expect(find.text('owner@example.com'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('owner@example.com'), findsOneWidget, reason: 'cancel keeps you signed in');

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(CupertinoActionSheet), matching: find.text('Sign out')));
    await tester.pumpAndSettle();
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  test('the sync line reads naturally', () {
    final now = DateTime(2026, 9, 26, 15);
    expect(
      syncLabel(CloudSyncState(status: CloudStatus.upToDate, lastSyncedAt: DateTime(2026, 9, 26, 14, 46)), now: now),
      // intl puts a narrow no-break space before AM/PM.
      'Up to date · 2:46 PM',
    );
    expect(
      syncLabel(CloudSyncState(status: CloudStatus.upToDate, lastSyncedAt: DateTime(2026, 9, 24, 9)), now: now),
      'Up to date · Sep 24',
    );
    expect(syncLabel(const CloudSyncState(status: CloudStatus.offline)), 'Offline');
  });
}
