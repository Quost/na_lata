import 'package:flutter/material.dart';

import 'tokens.dart';

/// Conteúdo centralizado, sem impor altura nem bloquear text scaling.
class NaContent extends StatelessWidget {
  const NaContent({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: NaSize.content),
      child: child,
    ),
  );
}

class NaSection extends StatelessWidget {
  const NaSection({
    super.key,
    required this.title,
    this.description,
    required this.child,
  });
  final String title;
  final String? description;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: NaSpace.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (description != null) ...[
          const SizedBox(height: NaSpace.xs),
          Text(description!),
        ],
        const SizedBox(height: NaSpace.md),
        child,
      ],
    ),
  );
}

/// Loading bloqueia toques duplicados. A regra da ação pertence à feature.
class NaButton extends StatelessWidget {
  const NaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: loading ? null : onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: NaSpace.md),
      child: Wrap(
        spacing: NaSpace.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          Text(loading ? 'Aguarde…' : label),
        ],
      ),
    ),
  );
}

class NaLoading extends StatelessWidget {
  const NaLoading({super.key, this.label = 'Carregando…'});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(NaSpace.xl),
    child: Column(
      children: [
        CircularProgressIndicator(semanticsLabel: label),
        const SizedBox(height: NaSpace.md),
        Text(label),
      ],
    ),
  );
}

class NaEmpty extends StatelessWidget {
  const NaEmpty({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(NaSpace.xl),
    child: Column(
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: NaSpace.md),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: NaSpace.sm),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: NaSpace.lg), action!],
      ],
    ),
  );
}

class NaError extends StatelessWidget {
  const NaError({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => NaEmpty(
    title: 'Não foi possível carregar',
    message: message,
    icon: Icons.error_outline,
    action: OutlinedButton(
      onPressed: onRetry,
      child: const Text('Tentar novamente'),
    ),
  );
}

/// Recebe números já calculados. Não calcula médias nem seleciona estrelas.
class NaRatingBadge extends StatelessWidget {
  const NaRatingBadge({super.key, required this.average, required this.count})
    : assert(count >= 0),
      assert(average == null || (average >= 1 && average <= 5));
  final double? average;
  final int count;
  @override
  Widget build(BuildContext context) {
    final label = average == null || count == 0
        ? 'Sem avaliações'
        : '${average!.toStringAsFixed(1).replaceAll('.', ',')} de 5 · $count avaliações';
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Chip(
          avatar: const Icon(
            Icons.star_rounded,
            color: NaColors.amber,
            size: 20,
          ),
          label: Text(label),
        ),
      ),
    );
  }
}

/// Card visual genérico; carregar/mapear Product continua a cargo da feature.
class NaItemCard extends StatelessWidget {
  const NaItemCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.leading,
  });
  final String title, subtitle;
  final VoidCallback onTap;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(NaSpace.lg),
        child: Row(
          children: [
            leading ?? const Icon(Icons.shopping_bag_outlined),
            const SizedBox(width: NaSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: NaSpace.xs),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: NaSpace.sm),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
