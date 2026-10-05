// Autoria: Kauã Dal Santo (T23).
import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../data/clients/app_failure.dart';

const int kNicknameMin = 2;
const int kNicknameMax = 40;

enum NicknameError { empty, tooShort, tooLong }

/// Resultado da validação: ou [value] (já com trim) ou [error].
class NicknameValidation {
  const NicknameValidation.ok(String this.value) : error = null;
  const NicknameValidation.fail(NicknameError this.error) : value = null;
  final String? value;
  final NicknameError? error;
  bool get isValid => error == null;
}

/// Regra pura (sem Flutter/rede) para poder ser testada de forma automatizada.
/// Conta caracteres (runes) para não penalizar emojis.
NicknameValidation validateNickname(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return const NicknameValidation.fail(NicknameError.empty);
  final length = text.runes.length;
  if (length < kNicknameMin) {
    return const NicknameValidation.fail(NicknameError.tooShort);
  }
  if (length > kNicknameMax) {
    return const NicknameValidation.fail(NicknameError.tooLong);
  }
  return NicknameValidation.ok(text);
}

String nicknameErrorMessage(NicknameError error) => switch (error) {
  NicknameError.empty => 'Digite um apelido.',
  NicknameError.tooShort =>
    'O apelido precisa ter pelo menos $kNicknameMin caracteres.',
  NicknameError.tooLong =>
    'O apelido pode ter no máximo $kNicknameMax caracteres.',
};

class NicknameFeature extends StatefulWidget {
  const NicknameFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<NicknameFeature> createState() => _NicknameFeatureState();
}

class _NicknameFeatureState extends State<NicknameFeature> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.context.scope.userId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = validateNickname(_controller.text);
    if (!result.isValid) {
      setState(() {
        _error = nicknameErrorMessage(result.error!);
        _success = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      // ASSUMIDO: contrato `setNickname(String)` no repositório de comunidade.
      await widget.context.scope.community.setNickname(result.value!);
      // Comentários leem o apelido de profiles; refresh atualiza a UI.
      widget.context.scope.refresh();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _success = 'Apelido atualizado!';
      });
    } on AppFailure catch (e) {
      // ASSUMIDO: AppFailure tem `message` segura para exibir.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext buildContext) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('nickname_field'),
            controller: _controller,
            enabled: !_saving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: 'Apelido',
              helperText: '$kNicknameMin a $kNicknameMax caracteres',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('nickname_save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar apelido'),
          ),
          if (_success != null) ...[
            const SizedBox(height: 12),
            Text(_success!, key: const Key('nickname_success')),
          ],
        ],
      ),
    );
  }
}
