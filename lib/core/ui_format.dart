import '../data/clients/app_failure.dart';
import 'contracts.dart';

/// Converte um erro em uma mensagem segura para exibir na UI.
///
/// Centraliza o padrão repetido nas features: [AppFailure] traz uma mensagem
/// já segura; [FeaturePending] é uma entrega ainda não disponível; qualquer
/// outra coisa cai no [fallback] genérico (nunca expõe payload/stack).
String messageForError(
  Object error, {
  String fallback = 'Algo deu errado. Tente novamente.',
}) => switch (error) {
  AppFailure(:final message) => message,
  FeaturePending() => error.toString(),
  _ => fallback,
};

/// Data curta no formato dd/MM/aaaa, em horário local, sem dependência de
/// pacote de internacionalização.
String formatShortDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
