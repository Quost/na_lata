import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../design_system/na_lata_ui.dart';
import 'comment_moderator.dart';

class ModerationFeature extends StatefulWidget {
  const ModerationFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<ModerationFeature> createState() => _ModerationFeatureState();
}

class _ModerationFeatureState extends State<ModerationFeature> {
  late final TextEditingController _commentController = TextEditingController(
    text: 'A embalagem é uma merda, mas o produto é ótimo.',
  );

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NaContent(
    child: Padding(
      padding: const EdgeInsets.all(NaSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Moderação de comentários',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: NaSpace.xs),
          Text(
            widget.context.product == null
                ? 'Demonstração local; nenhum produto selecionado.'
                : 'Produto: ${widget.context.product!.name}',
          ),
          const SizedBox(height: NaSpace.md),
          const Text(
            'Filtro demonstrativo, com lista explícita e sem IA. '
            'Não detecta todos os casos.',
          ),
          const SizedBox(height: NaSpace.lg),
          TextField(
            controller: _commentController,
            maxLength: 500,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Comentário de exemplo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: NaSpace.lg),
          if (_commentController.text.trim().isEmpty)
            const NaEmpty(
              title: 'Comentário vazio',
              message: 'Digite um comentário para ver o filtro.',
              icon: Icons.chat_bubble_outline,
            )
          else ...[
            NaSection(
              title: 'Exibição moderada',
              child: SelectableText(moderateComment(_commentController.text)),
            ),
            NaSection(
              title: 'Entrada original, sem alteração',
              description:
                  'Na integração, o original é armazenado; a máscara é '
                  'apenas para exibição.',
              child: SelectableText(_commentController.text),
            ),
          ],
        ],
      ),
    ),
  );
}
