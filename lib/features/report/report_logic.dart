import '../../core/models.dart';

/// Mensagem exibida quando o mesmo usuário denuncia o mesmo comentário de novo.
const duplicateReportMessage = 'Você já denunciou este comentário.';

/// Motivos aceitos pela tabela `reports` (check em `reason`).
enum ReportReason {
  ofensa('ofensa', 'Ofensa'),
  spam('spam', 'Spam'),
  outro('outro', 'Outro');

  const ReportReason(this.value, this.label);

  /// Texto gravado no banco.
  final String value;

  /// Texto mostrado na interface.
  final String label;

  /// Retorna null quando o texto não é um motivo válido.
  static ReportReason? tryParse(String? text) {
    for (final reason in values) {
      if (reason.value == text) return reason;
    }
    return null;
  }
}

/// Comentários exibidos: ignora avaliações sem texto e ordena do mais novo
/// para o mais antigo. O texto original não é alterado.
List<Review> reportableComments(List<Review> reviews) {
  final withText = reviews.where((r) => r.comment.trim().isNotEmpty).toList();
  withText.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return withText;
}

/// O autor não denuncia o próprio comentário.
bool canReport(Review review, String currentUserId) =>
    review.userId != currentUserId;

/// Data curta dd/MM/aaaa, sem depender de pacote de internacionalização.
String formatReportDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
