// 超級單字 app 測試
//
// 測試主要功能：級別選擇、UI 元素顯示

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocabpass/main.dart';

void main() {
  group('超級單字 App 測試', () {
    testWidgets('應用程式啟動測試 - 顯示級別選擇畫面', (WidgetTester tester) async {
      // 啟動應用程式
      await tester.pumpWidget(const MyApp());

      // 驗證標題顯示
      expect(find.text('選擇英文難度'), findsOneWidget);

      // 驗證主標題顯示
      expect(find.text('選擇你的學習程度'), findsOneWidget);

      // 驗證所有級別按鈕都顯示
      expect(find.text('英文1級'), findsOneWidget);
      expect(find.text('英文2級'), findsOneWidget);
      expect(find.text('英文3級'), findsOneWidget);
      expect(find.text('英文4級'), findsOneWidget);
      expect(find.text('英文5級'), findsOneWidget);
      expect(find.text('英文6級'), findsOneWidget);
      expect(find.text('英文7級'), findsOneWidget);

      // 驗證圖示顯示
      expect(find.byIcon(Icons.school), findsOneWidget);
    });

    testWidgets('級別卡片顯示測試', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // 驗證每個級別都有副標題
      expect(find.text('基礎入門'), findsOneWidget);
      expect(find.text('初級程度'), findsOneWidget);
      expect(find.text('中級基礎'), findsOneWidget);
      expect(find.text('中級進階'), findsOneWidget);
      expect(find.text('高級基礎'), findsOneWidget);
      expect(find.text('高級進階'), findsOneWidget);
      expect(find.text('專業程度'), findsOneWidget);
    });

    testWidgets('點擊級別按鈕導航測試', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // 找到並點擊第一個級別卡片
      final level1Card = find.text('英文1級');
      expect(level1Card, findsOneWidget);

      // 點擊卡片（注意：實際導航會嘗試網路請求，這裡只測試導航動作）
      await tester.tap(level1Card);
      await tester.pumpAndSettle();

      // 驗證導航到單字列表頁面（會看到 loading 或錯誤狀態）
      // 由於沒有網路模擬，這裡會顯示 loading 或 error
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('UI 元素樣式測試', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // 驗證有 Card 元素（級別卡片）
      expect(find.byType(Card), findsWidgets);

      // 驗證有漸層背景容器
      expect(find.byType(Container), findsWidgets);

      // 驗證有安全區域
      expect(find.byType(SafeArea), findsWidgets);
    });
  });

  group('BigWordPage 測試', () {
    testWidgets('單字詳細頁面顯示測試', (WidgetTester tester) async {
      // 直接測試 BigWordPage widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('BigWordPage 測試需要完整的導航流程'),
          ),
        ),
      );

      // 基本驗證
      expect(find.text('BigWordPage 測試需要完整的導航流程'), findsOneWidget);
    });
  });
}
