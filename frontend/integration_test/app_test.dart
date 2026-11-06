import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dating_app/main.dart' as app;

const String _outDir =
    r'C:\Users\ADMIN\.gemini\antigravity\brain\2e1dbf36-794d-459f-a017-dea61738edb9';
const String _adb =
    r'C:\Users\ADMIN\AppData\Local\Android\Sdk\platform-tools\adb.exe';
const String _device = 'c1035178';

Future<void> _shot(String name) async {
  final out = '$_outDir\\$name.png';
  final res = await Process.run('cmd',
      ['/c', '$_adb -s $_device exec-out screencap -p > "$out"']);
  if (res.exitCode != 0) {
    // ignore, just continue
  }
  await Future.delayed(const Duration(milliseconds: 300));
}

Future<void> _tapByText(WidgetTester t, String text) async {
  final finder = find.text(text);
  expect(finder, findsWidgets,
      reason: 'Expected to find text "$text" on screen');
  await t.tap(finder.first, warnIfMissed: false);
  await t.pumpAndSettle(const Duration(milliseconds: 600));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full user flow smoke test', (WidgetTester t) async {
    app.main();
    await t.pumpAndSettle(const Duration(seconds: 2));
    await _shot('01_login');

    // ---- Đăng nhập email + mật khẩu (backend thật) ----
    final emailField = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText ?? '').contains('Email'),
    );
    expect(emailField, findsOneWidget, reason: 'Email field should exist');
    await t.enterText(emailField, 'demo1@soulmate.app');
    await _shot('02_email_filled');
    final pwdField = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText ?? '').contains('Mật khẩu'),
    );
    expect(pwdField, findsOneWidget, reason: 'Password field should exist');
    await t.enterText(pwdField, 'Demo@1234');
    await _tapByText(t, 'Đăng nhập');
    // demo1 đã hoàn thành hồ sơ -> vào thẳng trang chủ
    await t.pumpAndSettle(const Duration(seconds: 4));
    await _shot('05_home');

    // Nếu vào nhầm màn thiết lập hồ sơ (tài khoản mới) thì điền luôn
    if (find.text('Thiết lập hồ sơ').evaluate().isNotEmpty) {
      final nameField = find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.hintText ?? '').contains('Nhập tên'),
      );
      await t.enterText(nameField, 'Linh');
      await _tapByText(t, 'Bắt đầu');
      await t.pumpAndSettle(const Duration(seconds: 2));
      await _shot('05_home');
    }

    // ---- Home tabs ----
    // Tab 0 already chat. Tap Explore (tab index 1)
    await _tapTab(t, 1); // Khám phá
    await _shot('06_explore');
    // Open Soul Game
    await _tapByText(t, 'Trò chơi tâm giao');
    await t.pumpAndSettle(const Duration(seconds: 1));
    await _shot('07_soul_game');
    // Send a message
    final chatInput = find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText ?? '').contains('Nhắn tin ẩn danh'),
    );
    if (chatInput.evaluate().isNotEmpty) {
      await t.enterText(chatInput, 'Chào bạn, mình rất vui được trò chuyện');
      final send = find.byIcon(Icons.send);
      if (send.evaluate().isNotEmpty) {
        await t.tap(send.first, warnIfMissed: false);
        await t.pumpAndSettle(const Duration(seconds: 1));
      }
    }
    await _shot('08_soul_game_msg');
    // Back
    final closeBtn = find.byIcon(Icons.close);
    if (closeBtn.evaluate().isNotEmpty) {
      await t.tap(closeBtn.first, warnIfMissed: false);
      await t.pumpAndSettle(const Duration(seconds: 1));
    }

    // Feed tab (index 2)
    await _tapTab(t, 2);
    await _shot('09_feed');
    // Open create post if present
    final plus = find.byIcon(Icons.add);
    if (plus.evaluate().isNotEmpty) {
      await t.tap(plus.first, warnIfMissed: false);
      await t.pumpAndSettle(const Duration(seconds: 1));
      await _shot('10_create_post');
      await t.pageBack();
      await t.pumpAndSettle(const Duration(seconds: 1));
    }

    // Room tab (index 3)
    await _tapTab(t, 3);
    await _shot('11_rooms');
    final joinBtn = find.text('Tham gia');
    if (joinBtn.evaluate().isNotEmpty) {
      await t.tap(joinBtn.first, warnIfMissed: false);
      await t.pumpAndSettle(const Duration(seconds: 1));
      await _shot('12_room_detail');
      await t.pageBack();
      await t.pumpAndSettle(const Duration(seconds: 1));
    }

    // Profile tab (index 4)
    await _tapTab(t, 4);
    await _shot('13_profile');
    // Open wallet
    final wallet = find.text('Ví & Xu');
    if (wallet.evaluate().isNotEmpty) {
      await t.tap(wallet.first, warnIfMissed: false);
      await t.pumpAndSettle(const Duration(seconds: 1));
      await _shot('14_wallet');
      await t.pageBack();
      await t.pumpAndSettle(const Duration(seconds: 1));
    }
  });
}

Future<void> _tapTab(WidgetTester t, int index) async {
  final bnb = find.byType(BottomNavigationBar);
  expect(bnb, findsOneWidget, reason: 'Bottom nav should exist');
  // Tap by iconic match is hard; use semantics / hit test at computed offset.
  final RenderBox box = t.renderObject(bnb);
  final size = box.size;
  final dy = size.height / 2;
  final dx = size.width * (index + 0.5) / 5;
  await t.tapAt(box.localToGlobal(Offset(dx, dy)));
  await t.pumpAndSettle(const Duration(seconds: 1));
}
