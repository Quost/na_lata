import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../core/contracts.dart';
import '../../core/models.dart';
import '../../data/clients/app_failure.dart';
import '../../design_system/na_lata_ui.dart';

/// T02 · Importar produto no catálogo.
///
/// Regras puras de validação do formulário. Retorna a mensagem de erro a
/// exibir ou `null` quando os campos estão válidos.
/// - código de barras e nome são obrigatórios (comparados após trim);
/// - no modo real (não-demo), códigos iniciados por "demo-" são recusados,
///   pois ficam reservados aos produtos fictícios da demonstração.
String? validateImportForm({
  required String barcode,
  required String name,
  required bool isDemoMode,
}) {
  final trimmedBarcode = barcode.trim();
  if (trimmedBarcode.isEmpty) {
    return 'Informe o código de barras do produto.';
  }
  if (name.trim().isEmpty) {
    return 'Informe o nome do produto.';
  }
  if (!isDemoMode && trimmedBarcode.toLowerCase().startsWith('demo-')) {
    return 'Códigos iniciados por "demo-" são reservados à demonstração. '
        'Use o código de barras real do produto.';
  }
  return null;
}

class ImportFeature extends StatefulWidget {
  const ImportFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<ImportFeature> createState() => _ImportFeatureState();
}

class _ImportFeatureState extends State<ImportFeature> {
  final _barcode = TextEditingController();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _category = TextEditingController();
  bool _saving = false;
  bool _success = false;
  String? _formError;
  String? _saveError;

  AppScope get _scope => widget.context.scope;

  @override
  void dispose() {
    _barcode.dispose();
    _name.dispose();
    _brand.dispose();
    _category.dispose();
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  /// Editar qualquer campo apaga o feedback anterior (erro ou sucesso).
  void _resetFeedback() {
    if (_formError != null || _saveError != null || _success) {
      setState(() {
        _formError = null;
        _saveError = null;
        _success = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final error = validateImportForm(
      barcode: _barcode.text,
      name: _name.text,
      isDemoMode: _scope.isDemo,
    );
    setState(() {
      _formError = error;
      _saveError = null;
      _success = false;
    });
    if (error != null) return;
    final product = Product(
      barcode: _barcode.text.trim(),
      name: _name.text.trim(),
      brand: _optional(_brand),
      category: _optional(_category),
      isDemo: _scope.isDemo,
    );
    setState(() => _saving = true);
    try {
      await _scope.products.importProduct(product);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _success = true;
        _barcode.clear();
        _name.clear();
        _brand.clear();
        _category.clear();
      });
      _scope.refresh();
    } on AppFailure catch (e) {
      _failSave(e.message);
    } on FeaturePending catch (e) {
      _failSave('$e');
    } on Exception {
      _failSave('Não foi possível importar o produto. Tente novamente.');
    }
  }

  void _failSave(String message) {
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = message;
    });
  }

  @override
  Widget build(BuildContext context) => NaSection(
    title: 'Importar produto',
    description: _scope.isDemo
        ? 'Modo demonstração: o produto fica só nesta sessão. Código de '
              'barras e nome são obrigatórios.'
        : 'Cadastre um produto no catálogo da turma. Código de barras e '
              'nome são obrigatórios.',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(NaSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(
              controller: _barcode,
              label: 'Código de barras *',
              hint: _scope.isDemo ? 'Ex.: demo-suco-1' : 'Ex.: 7891000100103',
              icon: Icons.qr_code_2_outlined,
            ),
            const SizedBox(height: NaSpace.md),
            _field(
              controller: _name,
              label: 'Nome do produto *',
              hint: 'Ex.: Suco de uva integral',
              icon: Icons.label_outline,
            ),
            const SizedBox(height: NaSpace.md),
            _field(
              controller: _brand,
              label: 'Marca (opcional)',
              hint: 'Ex.: Fazenda Aurora',
              icon: Icons.storefront_outlined,
            ),
            const SizedBox(height: NaSpace.md),
            _field(
              controller: _category,
              label: 'Categoria (opcional)',
              hint: 'Ex.: Suco',
              icon: Icons.category_outlined,
              action: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_formError != null) ...[
              const SizedBox(height: NaSpace.md),
              _Message(
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                text: _formError!,
              ),
            ],
            const SizedBox(height: NaSpace.lg),
            NaButton(
              label: 'Adicionar ao catálogo',
              loading: _saving,
              onPressed: _submit,
            ),
            if (_success) ...[
              const SizedBox(height: NaSpace.md),
              const _Message(
                icon: Icons.check_circle,
                color: NaColors.green,
                text:
                    'Produto importado no catálogo. Ele já aparece na busca '
                    'do Catálogo.',
              ),
            ],
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: NaSpace.md),
                child: NaError(
                  message: 'Importação não concluída: $_saveError',
                  onRetry: _submit,
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) => TextField(
    controller: controller,
    enabled: !_saving,
    textInputAction: action,
    onSubmitted: onSubmitted,
    onChanged: (_) => _resetFeedback(),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
    ),
  );
}

/// Linha de feedback com ícone + texto: comunica por forma e cor, não só cor.
class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: NaSpace.sm),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}
