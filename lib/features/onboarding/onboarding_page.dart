import 'package:flutter/material.dart';
import '../../design_system/na_lata_ui.dart';
import 'onboarding_controller.dart';

/// Primeiro uso: proposta do app, região opcional e saída imediata.
///
/// "Continuar explorando" e "Pular" nunca exigem GPS, e-mail ou cadastro.
/// [onSaveAccount] é o ponto de integração do fluxo de conta; enquanto ele
/// não existe, o link explica a situação em vez de apontar para uma tela
/// inexistente.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.controller,
    this.onFinished,
    this.onSaveAccount,
  });
  final OnboardingController controller;

  /// Chamado depois de concluir ou pular (ex.: fechar a tela na reabertura).
  final VoidCallback? onFinished;
  final VoidCallback? onSaveAccount;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  String? _regionId;

  @override
  void initState() {
    super.initState();
    _regionId = widget.controller.regionId;
  }

  Future<void> _finish({required bool keepRegion}) async {
    await widget.controller.complete(regionId: keepRegion ? _regionId : null);
    widget.onFinished?.call();
  }

  void _saveAccount() {
    final callback = widget.onSaveAccount;
    if (callback != null) return callback();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar minha conta'),
        content: const Text(
          'O cadastro com e-mail ainda não está disponível nesta versão. '
          'Você pode explorar e avaliar normalmente como visitante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: NaSize.content),
            child: SingleChildScrollView(
              padding: NaSpace.page,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                    semanticLabel: 'Na Lata',
                  ),
                  const SizedBox(height: NaSpace.lg),
                  Text(
                    'Bem-vindo ao Na Lata',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: NaSpace.sm),
                  Text(
                    'Comprou. Provou. Falou. Veja o que a comunidade acha de '
                    'alimentos industrializados e conte a sua experiência.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: NaSpace.xl),
                  Text(
                    'Onde você costuma comprar? (opcional)',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: NaSpace.xs),
                  Text(
                    'Serve só para filtrar a busca; não publicamos seu '
                    'endereço nem usamos sua localização. Lista provisória de '
                    'cidades.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: NaSpace.md),
                  Wrap(
                    spacing: NaSpace.sm,
                    runSpacing: NaSpace.sm,
                    children: [
                      ChoiceChip(
                        label: const Text('Todas as regiões'),
                        selected: _regionId == null,
                        onSelected: (_) => setState(() => _regionId = null),
                      ),
                      for (final region in onboardingRegions)
                        ChoiceChip(
                          label: Text(region.label),
                          selected: _regionId == region.id,
                          onSelected: (_) =>
                              setState(() => _regionId = region.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: NaSpace.xl),
                  NaButton(
                    label: 'Continuar explorando',
                    onPressed: () => _finish(keepRegion: true),
                  ),
                  const SizedBox(height: NaSpace.sm),
                  TextButton(
                    onPressed: () => _finish(keepRegion: false),
                    child: const Text('Pular'),
                  ),
                  TextButton(
                    onPressed: _saveAccount,
                    child: const Text('Salvar minha conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
