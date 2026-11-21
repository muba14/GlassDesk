import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glassdesk/src/glass_panel.dart';
import 'package:glassdesk/src/launcher/launcher.dart';
import 'package:glassdesk/src/theme.dart';
import 'package:glassdesk/src/widget_kind.dart';

import 'support/fonts.dart';
import 'support/scene.dart';

/// Her widget'ı gerçek pencere boyutunda çizer; taşma (overflow) ya da
/// hata olursa test başarısız olur.
Future<void> pumpInWindow(
  WidgetTester tester,
  Size size,
  Widget child, {
  bool panel = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildGlassTheme(fontFamily: 'Roboto'),
      home: Scaffold(
        backgroundColor: const Color(0xFF1B1446),
        body: panel ? GlassPanel(child: child) : child,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('Saat ve takvim', (tester) async {
    await pumpInWindow(
      tester,
      WidgetKind.clock.size,
      sampleContent(WidgetKind.clock),
    );
    expect(find.text('18:45'), findsOneWidget);
    expect(find.text('CUMARTESİ'), findsOneWidget);
    expect(find.text('Kasım 2026'), findsOneWidget);

    // Saate tıklayınca analog moda geçer.
    await tester.tap(find.text('18:45'));
    await tester.pump();
    expect(find.text('18:45'), findsNothing);

    // Takvimde bir sonraki ay.
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    expect(find.text('Aralık 2026'), findsOneWidget);
  });

  testWidgets('Sistem monitörü', (tester) async {
    await pumpInWindow(
      tester,
      WidgetKind.system.size,
      sampleContent(WidgetKind.system),
    );
    await tester.pump();
    expect(find.text('27'), findsOneWidget);
    expect(find.text('RAM'), findsOneWidget);
    expect(find.text('%78'), findsOneWidget);
  });

  testWidgets('Hava durumu', (tester) async {
    await pumpInWindow(
      tester,
      WidgetKind.weather.size,
      sampleContent(WidgetKind.weather),
    );
    expect(find.text('14°'), findsOneWidget);
    expect(find.text('Parçalı bulutlu'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);

    // Şehir arama moduna geçiş.
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Not ve yapılacaklar', (tester) async {
    await pumpInWindow(
      tester,
      WidgetKind.notes.size,
      sampleContent(WidgetKind.notes),
    );
    expect(find.textContaining('Hafta sonu planı'), findsOneWidget);

    await tester.tap(find.textContaining('Yapılacaklar'));
    await tester.pump();
    expect(find.text('Ekran görüntülerini ekle'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Yeni görev');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Yeni görev'), findsOneWidget);
    expect(find.text('Yapılacaklar 3/6'), findsOneWidget);
  });

  testWidgets('Kontrol paneli', (tester) async {
    await pumpInWindow(
      tester,
      launcherSize,
      const LauncherScene(),
      panel: false,
    );
    expect(find.text('GlassDesk'), findsOneWidget);
    for (final kind in WidgetKind.values) {
      expect(find.text(kind.title), findsOneWidget);
    }
  });
}
