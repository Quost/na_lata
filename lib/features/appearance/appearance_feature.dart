// Autoria: T26 — Tema escuro (seletor de aparência).
import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../design_system/na_lata_ui.dart';
import 'theme_controller.dart';

/// Uma opção do seletor de aparência.
class _AppearanceOption {
  const _AppearanceOption(this.mode, this.label, this.description, this.icon);
  final ThemeMode mode;
  final String label;
  final String description;
  final IconData icon;
}

const List<_AppearanceOption> _options = [
  _AppearanceOption(
    ThemeMode.system,
    'Sistema',
    'Acompanha o tema do aparelho.',
    Icons.brightness_auto_outlined,
  ),
  _AppearanceOption(
    ThemeMode.light,
    'Claro',
    'Fundo claro em qualquer situação.',
    Icons.light_mode_outlined,
  ),
  _AppearanceOption(
    ThemeMode.dark,
    'Escuro',
    'Fundo escuro em qualquer situação.',
    Icons.dark_mode_outlined,
  ),
];

/// T26 — seletor de aparência (Sistema/Claro/Escuro) com persistência local.
///
/// Lê e escreve na instância [ThemeController], que o `NaLataApp` escuta para
/// trocar o tema na hora. O `context` é recebido por convenção do projeto,
/// mesmo sem uso de repositório aqui.
class AppearanceFeature extends StatefulWidget {
  const AppearanceFeature({super.key, required this.context, this.controller});
  final FeatureContext context;

  /// Injetável em teste; por padrão usa a instância global [themeController].
  final ThemeController? controller;

  @override
  State<AppearanceFeature> createState() => _AppearanceFeatureState();
}

class _AppearanceFeatureState extends State<AppearanceFeature> {
  late final ThemeController _controller = widget.controller ?? themeController;
  bool _saving = false;

  Future<void> _select(ThemeMode mode) async {
    if (_saving || mode == _controller.value) return;
    setState(() => _saving = true);
    try {
      await _controller.setMode(mode);
    } on ThemePersistenceException catch (error) {
      _notify(error.message);
    } catch (_) {
      _notify('Não foi possível salvar a preferência de tema.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => NaContent(
    child: NaSection(
      title: 'Aparência',
      description: 'Escolha como o app usa o tema claro ou escuro.',
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _controller,
        builder: (context, mode, _) => RadioGroup<ThemeMode>(
          groupValue: mode,
          onChanged: (value) {
            if (value != null) _select(value);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in _options)
                RadioListTile<ThemeMode>(
                  key: Key('theme_option_${themeModeToString(option.mode)}'),
                  value: option.mode,
                  title: Text(option.label),
                  subtitle: Text(option.description),
                  secondary: Icon(option.icon),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
