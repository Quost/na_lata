// lib/data/supabase_reviews.dart

@override
Future delete(String reviewId) async {
  if (reviewId.trim().isEmpty) {
    throw const AppFailure('Identificador da avaliação inválido.');
  }

  if (isDemo) {
    await Future.delayed(const Duration(milliseconds: 200));
    _demoReviews.removeWhere((r) => r.id == reviewId);
    return;
  }

  try {
    final client = _client ?? Supabase.instance.client;
    // Filtra pelo ID da avaliação; a autorização do usuário é garantida via RLS no Supabase
    await client
        .from('reviews')
        .delete()
        .eq('id', reviewId);
  } catch (e) {
    throw AppFailure('Erro ao excluir avaliação: $e');
  }
}