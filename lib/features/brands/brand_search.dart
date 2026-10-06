import 'package:flutter/material.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../core/ui_format.dart';
import '../../design_system/na_lata_ui.dart';

/// Diretório de marcas com busca e paginação no repositório. A escolha da
/// marca é devolvida por [onSelect]; a navegação fica com quem usa o widget.
class BrandSearch extends StatefulWidget {
  const BrandSearch({
    super.key,
    required this.repository,
    required this.onSelect,
    this.pageSize = 20,
  });
  final BrandRepository repository;
  final void Function(Brand) onSelect;
  final int pageSize;

  @override
  State<BrandSearch> createState() => _BrandSearchState();
}

class _BrandSearchState extends State<BrandSearch> {
  final _controller = TextEditingController();
  final _items = <Brand>[];
  String _text = '';
  String? _next;
  String? _error;
  bool _loading = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    _text = _controller.text.trim();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _next = null;
      }
    });
    try {
      final page = await widget.repository.search(
        _text,
        after: reset ? null : _next,
        limit: widget.pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _next = page.nextAfter;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = messageForError(
          e,
          fallback: 'Não foi possível carregar as marcas.',
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          labelText: 'Buscar marca',
          suffixIcon: IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ),
      ),
      const SizedBox(height: NaSpace.md),
      ..._results(),
    ],
  );

  List<Widget> _results() {
    void retry() => _load(reset: _items.isEmpty);
    if (_items.isEmpty) {
      if (_error != null) return [NaError(message: _error!, onRetry: retry)];
      if (_loading) return [const NaLoading(label: 'Carregando marcas…')];
      return [
        NaEmpty(
          title: 'Nenhuma marca encontrada',
          message: _text.isEmpty
              ? 'Os produtos do catálogo ainda não têm marca informada.'
              : 'Nenhuma marca contém “$_text”.',
          icon: Icons.sell_outlined,
        ),
      ];
    }
    return [
      for (final brand in _items)
        NaItemCard(
          leading: const Icon(Icons.storefront_outlined, color: NaColors.amber),
          title: brand.key,
          subtitle:
              '${brand.productCount} '
              '${brand.productCount == 1 ? 'produto' : 'produtos'}',
          onTap: () => widget.onSelect(brand),
        ),
      if (_error != null)
        NaError(message: _error!, onRetry: retry)
      else if (_loading)
        const NaLoading(label: 'Carregando mais marcas…')
      else if (_next != null)
        Align(
          child: TextButton(
            onPressed: () => _load(reset: false),
            child: const Text('Carregar mais marcas'),
          ),
        ),
    ];
  }
}
