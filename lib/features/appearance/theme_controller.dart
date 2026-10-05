import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chave usada no SharedPreferences para guardar a preferência de tema.
const themeModeKey = 'theme_mode';

/// Converte o texto salvo em [ThemeMode] (regra pura, sem Flutter de UI/rede).
///
/// Valor ausente ou desconhecido volta para [ThemeMode.system] sem erro, de
/// modo que dados antigos ou corrompidos nunca quebrem o app.
ThemeMode themeModeFromString(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// Converte o [ThemeMode] no texto estável usado na persistência (regra pura).
String themeModeToString(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};

/// Falha ao gravar/ler a preferência de tema no aparelho.
class ThemePersistenceException implements Exception {
  const ThemePersistenceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Fonte da verdade do [ThemeMode] atual do app.
///
/// É um [ValueNotifier] para o `MaterialApp` reagir na hora (via
/// [ValueListenableBuilder]) e o seletor de aparência atualizar/persistir a
/// escolha sem reiniciar. A persistência usa SharedPreferences, injetável para
/// testes através de [preferences].
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController({
    ThemeMode initial = ThemeMode.system,
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       super(initial);

  final Future<SharedPreferences> Function() _preferences;

  /// Lê a preferência salva e aplica. Ausente/inválida vira [ThemeMode.system].
  ///
  /// Qualquer falha de leitura mantém o tema atual e não propaga erro: o app
  /// nunca deixa de iniciar por causa da preferência de tema.
  Future<void> load() async {
    try {
      final prefs = await _preferences();
      value = themeModeFromString(prefs.getString(themeModeKey));
    } catch (_) {
      // Mantém o valor atual (padrão Sistema) sem quebrar o boot.
    }
  }

  /// Persiste [mode] e, só então, aplica a troca (imediata, sem reiniciar).
  ///
  /// Em falha de gravação o tema atual é mantido (nada muda) e uma
  /// [ThemePersistenceException] é lançada para a UI avisar sem quebrar.
  Future<void> setMode(ThemeMode mode) async {
    if (value == mode) return;
    try {
      final prefs = await _preferences();
      final saved = await prefs.setString(
        themeModeKey,
        themeModeToString(mode),
      );
      if (!saved) {
        throw const ThemePersistenceException(
          'Não foi possível salvar a preferência de tema.',
        );
      }
    } on ThemePersistenceException {
      rethrow;
    } catch (_) {
      throw const ThemePersistenceException(
        'Não foi possível salvar a preferência de tema.',
      );
    }
    value = mode;
  }
}

/// Instância única escutada pelo `NaLataApp` e usada pelo `AppearanceFeature`.
///
/// Segue o padrão de notifier global já usado no projeto (ex.:
/// `HistoryStore.changes`), evitando alterar o `FeatureContext`.
final ThemeController themeController = ThemeController();
