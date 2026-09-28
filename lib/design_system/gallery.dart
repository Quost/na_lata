import 'package:flutter/material.dart';
import 'components.dart';
import 'tokens.dart';

class DesignSystemGallery extends StatelessWidget {
  const DesignSystemGallery({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Guia visual · Na Lata')),
    body: NaContent(
      child: ListView(
        padding: NaSpace.page,
        children: [
          Text(
            'Uma turma. Uma linguagem visual.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: NaSpace.sm),
          const Text(
            'Componentes de apresentação. As regras, consultas e testes das funcionalidades são responsabilidade de cada entrega.',
          ),
          const SizedBox(height: NaSpace.xl),
          NaSection(
            title: 'Cores',
            child: Wrap(
              spacing: NaSpace.sm,
              runSpacing: NaSpace.sm,
              children: [
                for (final entry in [
                  ('Verde', NaColors.green),
                  ('Texto', NaColors.ink),
                  ('Erro', NaColors.red),
                  ('Nota', NaColors.amber),
                ])
                  Chip(
                    avatar: CircleAvatar(backgroundColor: entry.$2),
                    label: Text(entry.$1),
                  ),
              ],
            ),
          ),
          NaSection(
            title: 'Tipografia',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Título de tela',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  'Título de seção',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Nome do produto',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Texto simples, direto e legível.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          NaSection(
            title: 'Ações',
            child: Wrap(
              spacing: NaSpace.sm,
              runSpacing: NaSpace.sm,
              children: [
                NaButton(
                  label: 'Salvar avaliação',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Exemplo visual — nenhuma avaliação foi salva.',
                      ),
                    ),
                  ),
                ),
                const NaButton(label: 'Salvar', onPressed: null, loading: true),
                const NaButton(label: 'Indisponível', onPressed: null),
                OutlinedButton(onPressed: () {}, child: const Text('Cancelar')),
              ],
            ),
          ),
          NaSection(
            title: 'Campos e filtros',
            description:
                'Use TextFormField com validator na sua funcionalidade.',
            child: Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Comentário',
                    hintText: 'O que você achou do produto?',
                    helperText: 'Seja sincero e respeitoso.',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: NaSpace.lg),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Código de barras',
                    errorText: 'Confira os dígitos do código.',
                  ),
                ),
                const SizedBox(height: NaSpace.sm),
                Wrap(
                  spacing: NaSpace.sm,
                  children: [
                    FilterChip(
                      label: const Text('Leite'),
                      selected: true,
                      onSelected: (_) {},
                    ),
                    FilterChip(
                      label: const Text('Chocolate'),
                      selected: false,
                      onSelected: (_) {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          NaSection(
            title: 'Cards e notas',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NaItemCard(
                  title: 'Produto de exemplo',
                  subtitle: 'Marca de exemplo • Categoria',
                  onTap: () {},
                ),
                const Wrap(
                  spacing: NaSpace.sm,
                  children: [
                    NaRatingBadge(average: 4.2, count: 12),
                    NaRatingBadge(average: null, count: 0),
                  ],
                ),
              ],
            ),
          ),
          NaSection(
            title: 'Estados',
            child: Column(
              children: [
                const NaLoading(),
                const NaEmpty(
                  title: 'Nenhum produto encontrado',
                  message: 'Tente outro nome ou limpe os filtros.',
                ),
                NaError(
                  message: 'Confira sua conexão e tente outra vez.',
                  onRetry: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
