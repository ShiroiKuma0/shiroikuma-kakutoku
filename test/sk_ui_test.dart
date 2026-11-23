// shiroikuma-kakutoku fork: the black-yellow look, checked where it is drawn —
// the role table's defaults, the theme built from it, the dialog buttons, and
// the real 白い熊 獲得 UI page from its top.

import 'package:flutter_test/flutter_test.dart';
import 'package:obtainium/components/sk_pills.dart';
import 'package:obtainium/components/sk_ui_widgets.dart';
import 'package:obtainium/pages/sk_ui_page.dart';
import 'package:obtainium/providers/settings_provider.dart';
import 'package:obtainium/providers/sk_ui_provider.dart';
import 'package:obtainium/sk_material.dart';
import 'package:obtainium/sk_theme.dart';
import 'package:provider/provider.dart';

const _noStates = <WidgetState>{};

void main() {
  group('role table', () {
    test('a fresh install shows the two primaries', () {
      final p = SkPalette(SkUiKnobs());
      expect(p.base(SkBase.background), skBlack);
      expect(p.base(SkBase.accent), skYellow);
      expect(p[SkRole.buttonMainFrame], skYellow);
      expect(p[SkRole.buttonGround], skBlack);
      expect(p[SkRole.dialogGround], skBlack);
      expect(p[SkRole.switchOnOutline], skYellow);
    });

    test('derived and meaning colours have their settled defaults', () {
      final p = SkPalette(SkUiKnobs());
      expect(p[SkRole.switchOffOutline].toARGB32(), 0xFF8C8C00);
      expect(p[SkRole.switchOffDot].toARGB32(), 0xFF8C8C00);
      expect(p[SkRole.menuDivider].toARGB32(), 0xFFB3B300);
      expect(p[SkRole.pageNote].toARGB32(), 0xFFC8C800);
      expect(p.icon(SkIconRole.call).toARGB32(), 0xFF00FF00);
      expect(p.icon(SkIconRole.message).toARGB32(), 0xFF4D94FF);
      expect(p.icon(SkIconRole.contact).toARGB32(), 0xFF00FFFF);
      expect(p.icon(SkIconRole.share).toARGB32(), 0xFFFF8000);
      expect(p.icon(SkIconRole.block).toARGB32(), 0xFFFF00FF);
      expect(p.icon(SkIconRole.delete).toARGB32(), 0xFFFF0000);
      expect(p.icon(SkIconRole.view), skYellow);
    });

    test('a role follows its foundation colour until it has its own', () {
      final k = SkUiKnobs()..setBase(SkBase.border, const Color(0xFF123456));
      expect(SkPalette(k)[SkRole.cardFrame].toARGB32(), 0xFF123456);
      k.roles[SkRole.cardFrame.name] = 0xFF654321;
      expect(SkPalette(k)[SkRole.cardFrame].toARGB32(), 0xFF654321);
      expect(SkPalette(k)[SkRole.dialogFrame].toARGB32(), 0xFF123456);
    });

    test('roles, section order and fold state travel in the JSON', () {
      final k = SkUiKnobs()
        ..roles[SkRole.delete.name] = 0xFFAA0000
        ..sectionOrder = ['maintenance', 'buttons']
        ..sectionsOpen = ['buttons'];
      final back = SkUiKnobs.fromJson(k.toJson());
      expect(back.roles[SkRole.delete.name], 0xFFAA0000);
      expect(back.sectionOrder, ['maintenance', 'buttons']);
      expect(back.sectionsOpen, ['buttons']);
    });

    test('a settings blob from before the roles still loads', () {
      final back = SkUiKnobs.fromJson({'accent': 0xFF00FF00, 'btnRev': 1});
      expect(back.accent.toARGB32(), 0xFF00FF00);
      expect(back.roles, isEmpty);
      expect(back.sectionsOpen, isEmpty);
    });

    test('every section but the plain ones has roles, each named once', () {
      final names = SkRole.values.map((r) => r.name).toSet();
      expect(names.length, SkRole.values.length);
      const plain = {
        SkSection.eximport,
        SkSection.general,
        SkSection.foundation,
        SkSection.shape,
        SkSection.maintenance,
      };
      for (final s in SkSection.values) {
        expect(
          SkRole.inSection(s).isNotEmpty,
          !plain.contains(s),
          reason: s.name,
        );
      }
    });

    test('icons are told apart by what they do', () {
      expect(skIconRoleFor(Icons.delete_outline), SkIconRole.delete);
      expect(skIconRoleFor(Icons.import_export), SkIconRole.share);
      expect(skIconRoleFor(Icons.download_rounded), SkIconRole.call);
      expect(skIconRoleFor(Icons.edit), SkIconRole.message);
      expect(skIconRoleFor(Icons.palette_outlined), SkIconRole.contact);
      expect(skIconRoleFor(Icons.close), SkIconRole.block);
      expect(skIconRoleFor(Icons.settings_outlined), SkIconRole.view);
    });
  });

  group('theme', () {
    final theme = buildSkTheme(SkUiKnobs(), 'Montserrat');

    test('no button is filled, and the main one is told by weight', () {
      final filled = theme.filledButtonTheme.style!;
      final text = theme.textButtonTheme.style!;
      final elevated = theme.elevatedButtonTheme.style!;
      final outlined = theme.outlinedButtonTheme.style!;
      for (final s in [filled, text, elevated, outlined]) {
        expect(s.backgroundColor!.resolve(_noStates), skBlack);
        expect(s.shape!.resolve(_noStates), isA<StadiumBorder>());
        expect(s.side!.resolve(_noStates)!.color, skYellow);
        expect(s.elevation!.resolve(_noStates), 0);
      }
      expect(filled.side!.resolve(_noStates)!.width, 3);
      expect(filled.textStyle!.resolve(_noStates)!.fontWeight, FontWeight.bold);
      for (final s in [text, elevated, outlined]) {
        expect(s.side!.resolve(_noStates)!.width, 1.25);
        expect(
          s.textStyle!.resolve(_noStates)!.fontWeight,
          isNot(FontWeight.bold),
        );
      }
    });

    test('a disabled pill is dimmed to 38 %', () {
      final side = theme.textButtonTheme.style!.side!.resolve({
        WidgetState.disabled,
      })!;
      expect(side.color.a, closeTo(0.38, 0.001));
    });

    test('the floating button is an outlined ring', () {
      final fab = theme.floatingActionButtonTheme;
      expect(fab.backgroundColor, skBlack);
      expect(fab.elevation, 0);
      expect((fab.shape! as StadiumBorder).side.width, 3);
    });

    test('a colour set for one item reaches the theme', () {
      final k = SkUiKnobs()..roles[SkRole.dialogGround.name] = 0xFF101010;
      expect(
        buildSkTheme(k, 'Montserrat').dialogTheme.backgroundColor!.toARGB32(),
        0xFF101010,
      );
    });
  });

  group('dialogs', () {
    Future<void> show(WidgetTester tester, Widget dialog) => tester.pumpWidget(
      MaterialApp(
        theme: buildSkTheme(SkUiKnobs(), 'Montserrat'),
        home: Scaffold(body: dialog),
      ),
    );

    BorderSide sideOf(WidgetTester tester, String label) => TextButtonTheme.of(
      tester.element(find.text(label)),
    ).style!.side!.resolve(_noStates)!;

    testWidgets('the action that is not a way out is the main pill', (
      tester,
    ) async {
      await show(
        tester,
        AlertDialog(
          title: const Text('Title'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Cancel')),
            TextButton(onPressed: () {}, child: const Text('Save')),
          ],
        ),
      );
      expect(sideOf(tester, 'Cancel').width, 1.25);
      expect(sideOf(tester, 'Save').width, 3);
      expect(sideOf(tester, 'Save').color, skYellow);
    });

    testWidgets('a deleting dialog confirms with a red pill', (tester) async {
      await show(
        tester,
        AlertDialog(
          title: const Text('Title'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Cancel')),
            TextButton(onPressed: () {}, child: const Text('Remove')),
          ],
        ),
      );
      expect(sideOf(tester, 'Remove').width, 3);
      expect(sideOf(tester, 'Remove').color.toARGB32(), 0xFFFF0000);
      expect(sideOf(tester, 'Cancel').color, skYellow);
    });

    testWidgets('with the 白い熊 獲得 UI off, dialogs are upstream’s own', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AlertDialog(
              actions: [
                TextButton(onPressed: () {}, child: const Text('Save')),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(TextButtonTheme), findsNothing);
    });
  });

  group('the UI page', () {
    late SkUiProvider sk;

    Future<void> open(WidgetTester tester) async {
      sk = SkUiProvider();
      tester.view.physicalSize = const Size(1080, 6000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>(
              create: (_) => SettingsProvider(),
            ),
            ChangeNotifierProvider<SkUiProvider>.value(value: sk),
          ],
          child: Consumer<SkUiProvider>(
            builder: (context, sk, _) => MaterialApp(
              theme: buildSkTheme(sk.knobs, 'Montserrat'),
              home: const SkUiPage(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('top: the settings pill, a chip per section, all folded', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('App settings'), findsOneWidget);
      expect(find.byType(SkSectionIndex), findsOneWidget);
      for (final s in SkSection.values) {
        // Once on its chip, once on its heading.
        expect(find.text(s.title), findsNWidgets(2), reason: s.name);
      }
      expect(find.byType(SkSectionHeader), findsNWidgets(SkSection.values.length));
      // Folded: no row of any section is built.
      expect(find.byType(SkRoleRows), findsNothing);
      expect(find.byType(SkSwitchRow), findsNothing);
      expect(find.byType(SkSliderRow), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(SkSection.values.length));
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('a tap on a heading unfolds it, and the state is kept', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byType(SkSectionHeader).at(
        SkSection.values.indexOf(SkSection.buttons),
      ));
      await tester.pump();
      expect(find.text('Main button frame'), findsOneWidget);
      expect(sk.knobs.sectionsOpen, ['buttons']);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      // Every row of the section has an icon, never under 18 dp.
      final rows = tester.widgetList<SkColorRow>(find.byType(SkColorRow));
      expect(rows.length, SkRole.inSection(SkSection.buttons).length);
      final icon = tester.widget<Icon>(
        find
            .descendant(
              of: find.byType(SkColorRow).first,
              matching: find.byType(Icon),
            )
            .first,
      );
      expect(icon.size, greaterThanOrEqualTo(18));
    });

    testWidgets('a chip unfolds its section', (tester) async {
      await open(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(SkSectionIndex),
          matching: find.text(SkSection.maintenance.title),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reset section order'), findsOneWidget);
      expect(find.text('Reset all colours'), findsOneWidget);
      expect(sk.knobs.sectionsOpen, contains('maintenance'));
    });

    testWidgets('the sections follow the stored order', (tester) async {
      await open(tester);
      sk.setSectionOrder(['maintenance', 'buttons']);
      await tester.pump();
      final headers = tester
          .widgetList<SkSectionHeader>(find.byType(SkSectionHeader))
          .map((h) => h.section)
          .toList();
      expect(headers[0], SkSection.maintenance);
      expect(headers[1], SkSection.buttons);
      expect(headers.length, SkSection.values.length);
      sk.resetSectionOrder();
      await tester.pump();
      expect(
        tester.widget<SkSectionHeader>(find.byType(SkSectionHeader).first).section,
        SkSection.values.first,
      );
    });

    testWidgets('the switch is the outlined one, and switching the UI off '
        'leaves only what still works', (tester) async {
      await open(tester);
      sk.setSectionOpen(SkSection.general, true);
      await tester.pump();
      expect(find.byType(SkSwitch), findsOneWidget);
      await tester.tap(find.byType(SkSwitchRow));
      await tester.pump();
      expect(sk.knobs.enabled, isFalse);
      expect(
        tester
            .widgetList<SkSectionHeader>(find.byType(SkSectionHeader))
            .map((h) => h.section),
        [SkSection.eximport, SkSection.general, SkSection.maintenance],
      );
    });

    testWidgets('a role gets a colour of its own, then its default back', (
      tester,
    ) async {
      await open(tester);
      sk.setSectionOpen(SkSection.switches, true);
      await tester.pump();
      expect(find.byIcon(Icons.restart_alt), findsNothing);
      sk.setRole(SkRole.switchOnDot, const Color(0xFF00FF00));
      await tester.pump();
      expect(find.byIcon(Icons.restart_alt), findsOneWidget);
      await tester.tap(find.byIcon(Icons.restart_alt));
      await tester.pump();
      expect(sk.knobs.roles, isEmpty);
    });
  });
}
