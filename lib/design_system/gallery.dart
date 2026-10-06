import 'package:flutter/material.dart';
import 'components.dart';
import 'filter_summary.dart';
import 'tokens.dart';

/// Vitrine dos componentes visuais compartilhados. Não é uma tela do usuário
/// nem faz parte da navegação: serve de referência de aparência e de estados.
/// Cada componente aqui reage de verdade (estado local), sem regra de negócio,
/// cálculo de média ou acesso a banco — isso pertence às funcionalidades.
class DesignSystemGallery extends StatefulWidget {
  const DesignSystemGallery({super.key});
  @override
  State<DesignSystemGallery> createState() => _DesignSystemGalleryState();
}

class _DesignSystemGalleryState extends State<DesignSystemGallery> {
  static const _sabores = ['Leite', 'Chocolate'];
  final Set<String> _filtros = {'Leite'};
  static const _ativosIniciais = [
    NaFilterItem(id: 'text', dimension: 'Nome', value: '“leite”'),
    NaFilterItem(id: 'brand', dimension: 'Marca', value: 'Fazenda Aurora'),
    NaFilterItem(id: 'minRating', dimension: 'Nota mínima', value: '4 ou mais'),
  ];
  List<NaFilterItem> _ativos = _ativosIniciais;
  int _salvos = 0;
  bool _cardSalvo = false;
  bool _comFalha = true;

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
            description:
                'Salvar soma um item ao contador; Limpar zera e fica indisponível quando não há o que limpar.',
            child: Wrap(
              spacing: NaSpace.sm,
              runSpacing: NaSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                NaButton(
                  label: _salvos == 0 ? 'Salvar avaliação' : 'Salvas: $_salvos',
                  onPressed: () => setState(() => _salvos++),
                ),
                const NaButton(label: 'Salvar', onPressed: null, loading: true),
                const NaButton(label: 'Indisponível', onPressed: null),
                OutlinedButton(
                  onPressed: _salvos == 0
                      ? null
                      : () => setState(() => _salvos = 0),
                  child: const Text('Limpar'),
                ),
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
                    for (final sabor in _sabores)
                      FilterChip(
                        label: Text(sabor),
                        selected: _filtros.contains(sabor),
                        onSelected: (selecionado) => setState(() {
                          if (selecionado) {
                            _filtros.add(sabor);
                          } else {
                            _filtros.remove(sabor);
                          }
                        }),
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
                  leading: Icon(
                    _cardSalvo ? Icons.bookmark : Icons.bookmark_border,
                  ),
                  title: 'Bebida de aveia',
                  subtitle: _cardSalvo
                      ? 'Salvo na sua lista'
                      : 'Toque para salvar na lista',
                  onTap: () => setState(() => _cardSalvo = !_cardSalvo),
                ),
                const SizedBox(height: NaSpace.md),
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
            title: 'Filtros ativos',
            description:
                'Chips removíveis com contagem e ação Limpar. Cada remover '
                'tem tooltip e rótulo para leitor de tela.',
            child: _ativos.isEmpty
                ? OutlinedButton(
                    onPressed: () => setState(() => _ativos = _ativosIniciais),
                    child: const Text('Restaurar exemplo'),
                  )
                : NaFilterSummary(
                    items: _ativos,
                    onRemove: (id) => setState(
                      () => _ativos = [
                        for (final item in _ativos)
                          if (item.id != id) item,
                      ],
                    ),
                    onClear: () => setState(() => _ativos = const []),
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
                if (_comFalha)
                  NaError(
                    message: 'Confira sua conexão e tente outra vez.',
                    onRetry: () => setState(() => _comFalha = false),
                  )
                else
                  NaEmpty(
                    icon: Icons.check_circle_outline,
                    title: 'Conexão restabelecida',
                    message: 'A ação "Tentar novamente" refez a busca.',
                    action: OutlinedButton(
                      onPressed: () => setState(() => _comFalha = true),
                      child: const Text('Simular falha de novo'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
