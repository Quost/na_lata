import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';
import 'sighting_logic.dart';

/// T22 — Registrar onde encontrei.
///
/// Formulário de loja/cidade para o produto aberto e lista dos relatos já
/// enviados. Os relatos são pistas da comunidade, sem garantia de estoque.
class SightingsFeature extends StatefulWidget {
  const SightingsFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<SightingsFeature> createState() => _SightingsFeatureState();
}

class _SightingsFeatureState extends State<SightingsFeature> {
  final _storeController = TextEditingController();
  final _cityController = TextEditingController();

  List<Sighting>? _items;
  String? _loadError;
  String? _formError;
  String? _success;
  bool _saving = false;
  int _generation = 0;

  AppScope get _scope => widget.context.scope;
  Product? get _product => widget.context.product;

  @override
  void initState() {
    super.initState();
    _scope.addListener(_reload);
    _fetch(_generation);
  }

  @override
  void dispose() {
    _scope.removeListener(_reload);
    _storeController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _reload() {
    final generation = ++_generation;
    setState(() {
      _items = null;
      _loadError = null;
    });
    _fetch(generation);
  }

  Future<void> _fetch(int generation) async {
    final product = _product;
    if (product == null) {
      if (!mounted || generation != _generation) return;
      setState(() => _items = const []);
      return;
    }
    try {
      final items = await _scope.community.sightings(product.barcode);
      if (!mounted || generation != _generation) return;
      setState(() => _items = items);
    } on AppFailure catch (e) {
      _failLoad(e.message, generation);
    } on FeaturePending catch (e) {
      _failLoad('$e', generation);
    } on Exception {
      _failLoad(
        'Não foi possível carregar os relatos. Tente novamente.',
        generation,
      );
    }
  }

  void _failLoad(String message, int generation) {
    if (!mounted || generation != _generation) return;
    setState(() => _loadError = message);
  }

  Future<void> _submit() async {
    final product = _product;
    if (product == null) return;

    // Valida os dois campos antes de tocar o repositório.
    final store = validateSightingField(_storeController.text);
    final city = validateSightingField(_cityController.text);
    if (!store.isValid) {
      setState(() {
        _formError = sightingErrorMessage(SightingField.store, store.error!);
        _success = null;
      });
      return;
    }
    if (!city.isValid) {
      setState(() {
        _formError = sightingErrorMessage(SightingField.city, city.error!);
        _success = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _formError = null;
      _success = null;
    });
    try {
      await _scope.community.addSighting(
        Sighting(
          barcode: product.barcode,
          store: store.value!,
          city: city.value!,
        ),
      );
      if (!mounted) return;
      _storeController.clear();
      _cityController.clear();
      setState(() {
        _saving = false;
        _success = 'Relato registrado. Obrigado por ajudar a turma!';
      });
      // Atualiza a lista com o relato recém-adicionado.
      _reload();
    } on AppFailure catch (e) {
      _failForm(e.message);
    } on FeaturePending catch (e) {
      _failForm('$e');
    } on Exception {
      _failForm('Não foi possível registrar o relato. Tente novamente.');
    }
  }

  void _failForm(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _formError = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    if (product == null) {
      return const NaContent(
        child: NaSection(
          title: 'Registrar onde encontrei',
          child: NaEmpty(
            icon: Icons.storefront_outlined,
            title: 'Abra um produto primeiro',
            message:
                'Escolha um produto no Catálogo para registrar onde você o '
                'encontrou.',
          ),
        ),
      );
    }

    return NaContent(
      child: ListView(
        padding: NaSpace.page,
        children: [
          NaSection(
            title: 'Onde encontrei · ${product.name}',
            description:
                'Compartilhe a loja e a cidade onde você viu este produto. '
                'São relatos da turma — não garantem estoque no momento.',
            child: _form(),
          ),
          const SizedBox(height: NaSpace.lg),
          _list(),
        ],
      ),
    );
  }

  Widget _form() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const Key('sighting_store'),
        controller: _storeController,
        enabled: !_saving,
        maxLength: sightingFieldMaxLength,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Loja',
          hintText: 'Ex.: Mercado do Bairro',
          prefixIcon: Icon(Icons.storefront_outlined),
        ),
      ),
      TextField(
        key: const Key('sighting_city'),
        controller: _cityController,
        enabled: !_saving,
        maxLength: sightingFieldMaxLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _saving ? null : _submit(),
        decoration: const InputDecoration(
          labelText: 'Cidade',
          hintText: 'Ex.: Jaraguá do Sul',
          prefixIcon: Icon(Icons.location_city_outlined),
        ),
      ),
      if (_formError != null) ...[
        const SizedBox(height: NaSpace.sm),
        Text(
          _formError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      if (_success != null) ...[
        const SizedBox(height: NaSpace.sm),
        Row(
          children: [
            const Icon(Icons.check_circle_outline, color: NaColors.amber),
            const SizedBox(width: NaSpace.sm),
            Expanded(
              child: Text(_success!, key: const Key('sighting_success')),
            ),
          ],
        ),
      ],
      const SizedBox(height: NaSpace.sm),
      FilledButton.icon(
        key: const Key('sighting_submit'),
        onPressed: _saving ? null : _submit,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_location_alt_outlined),
        label: Text(_saving ? 'Registrando…' : 'Registrar relato'),
      ),
    ],
  );

  Widget _list() {
    if (_loadError != null) {
      return NaError(message: _loadError!, onRetry: _reload);
    }
    final items = _items;
    if (items == null) {
      return const NaLoading(label: 'Carregando relatos…');
    }
    if (items.isEmpty) {
      return const NaEmpty(
        icon: Icons.travel_explore_outlined,
        title: 'Nenhum relato ainda',
        message: 'Seja o primeiro a dizer onde encontrou este produto.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final sighting in items)
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(sighting.store),
              subtitle: Text(sighting.city),
            ),
          ),
      ],
    );
  }
}
