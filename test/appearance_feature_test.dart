import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:na_lata/core/app_scope.dart';
import 'package:na_lata/core/contracts.dart';
import 'package:na_lata/core/models.dart';
import 'package:na_lata/data/demo_repositories.dart';
import 'package:na_lata/features/appearance/appearance_feature.dart';
import 'package:na_lata/features/appearance/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('conversão String <-> ThemeMode', () {
    test('texto conhecido vira o ThemeMode correspondente', () {
      expect(themeModeFromString('system'), ThemeMode.system);
      expect(themeModeFromString('light'), ThemeMode.light);
      expect(themeModeFromString('dark'), ThemeMode.dark);
    });

    test('ausente ou inválido volta para Sistema', () {
      expect(themeModeFromString(null), ThemeMode.system);
      expect(themeModeFromString(''), ThemeMode.system);
      expect(themeModeFromString('roxo'), ThemeMode.system);
      // A conversão é sensível a maiúsculas: só aceita as chaves canônicas.
      expect(themeModeFromString('LIGHT'), ThemeMode.system);
    });

    test('ThemeMode vira texto estável e faz round-trip', () {
      for (final mode in ThemeMode.values) {
        expect(themeModeFromString(themeModeToString(mode)), mode);
      }
      expect(themeModeToString(ThemeMode.system), 'system');
      expect(themeModeToString(ThemeMode.light), 'light');
      expect(themeModeToString(ThemeMode.dark), 'dark');
    });
  });

  group('ThemeController', () {
    test('load lê a preferência salva', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final controller = ThemeController();
      await controller.load();
      expect(controller.value, ThemeMode.dark);
    });

    test('load sem valor mantém Sistema', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController();
      await controller.load();
      expect(controller.value, ThemeMode.system);
    });

    test('load com valor inválido volta para Sistema sem erro', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'arco-iris'});
      final controller = ThemeController();
      await controller.load();
      expect(controller.value, ThemeMode.system);
    });

    test('setMode aplica na hora e persiste a escolha', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController();

      await controller.setMode(ThemeMode.dark);

      expect(controller.value, ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('falha ao gravar mantém o tema atual e lança exceção', () async {
      final controller = ThemeController(
        preferences: () async => throw Exception('sem disco'),
      );

      await expectLater(
        () => controller.setMode(ThemeMode.dark),
        throwsA(isA<ThemePersistenceException>()),
      );
      // Mantém o tema atual (não trocou), sem quebrar.
      expect(controller.value, ThemeMode.system);
    });
  });

  group('AppearanceFeature (widget)', () {
    testWidgets('trocar a opção reflete no notifier e persiste', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppearanceFeature(
              context: _featureContext(),
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Padrão inicial é Sistema.
      expect(controller.value, ThemeMode.system);

      await tester.tap(find.text('Escuro'));
      await tester.pumpAndSettle();
      expect(controller.value, ThemeMode.dark);

      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();
      expect(controller.value, ThemeMode.light);

      // A escolha ficou persistida no armazenamento local.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });
  });
}

/// FeatureContext mínimo: o AppearanceFeature não usa repositórios, mas o
/// construtor padrão do projeto exige um contexto. Usa repositórios demo em
/// memória e um OFF vazio, sem rede nem banco.
FeatureContext _featureContext() => FeatureContext(
  scope: AppScope(
    products: DemoProducts(),
    reviews: DemoReviews(),
    community: DemoCommunity(),
    openFoodFacts: _EmptyOpenFoodFacts(),
    isDemo: true,
    userId: 'demo-user',
  ),
  openProduct: (_) {},
);

class _EmptyOpenFoodFacts implements OpenFoodFactsRepository {
  @override
  Future<Product?> lookup(String barcode) async => null;
}
