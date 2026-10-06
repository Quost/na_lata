import 'package:flutter/widgets.dart';
import 'core/app_scope.dart';
import 'features/off/off_feature.dart';
import 'features/import/import_feature.dart';
import 'features/scanner/scanner_feature.dart';
import 'features/barcode/barcode_feature.dart';
import 'features/catalog/catalog_feature.dart';
import 'features/detail/detail_feature.dart';
import 'features/review_form/review_form_feature.dart';
import 'features/review_store/review_store_feature.dart';
import 'features/comments/comments_feature.dart';
import 'features/summary/summary_feature.dart';
import 'features/my_reviews/my_reviews_feature.dart';
import 'features/filters/filters_feature.dart';
import 'features/brands/brands_feature.dart';
import 'features/ranking/ranking_feature.dart';
import 'features/moderation/moderation_feature.dart';
import 'features/edit_review/edit_review_feature.dart';
import 'features/delete_review/delete_review_feature.dart';
import 'features/favorites/favorites_feature.dart';
import 'features/report/report_feature.dart';
import 'features/compare/compare_feature.dart';
import 'features/minimum_rating/minimum_rating_feature.dart';
import 'features/sightings/sightings_feature.dart';
import 'features/nickname/nickname_feature.dart';
import 'features/history/history_feature.dart';
import 'features/appearance/appearance_feature.dart';
import 'features/notifications/notification_preferences_feature.dart';

typedef FeatureBuilder = Widget Function(FeatureContext);
final List<(String, String, FeatureBuilder)> features = [
  (
    'T01',
    'Consultar produto no Open Food Facts',
    (FeatureContext c) => OffFeature(context: c),
  ),
  (
    'T02',
    'Importar produto no Supabase',
    (FeatureContext c) => ImportFeature(context: c),
  ),
  (
    'T03',
    'Ler código de barras pela câmera',
    (FeatureContext c) => ScannerFeature(context: c),
  ),
  (
    'T04',
    'Consultar código digitado',
    (FeatureContext c) => BarcodeFeature(context: c),
  ),
  (
    'T05',
    'Pesquisar catálogo por nome',
    (FeatureContext c) => CatalogFeature(context: c),
  ),
  (
    'T06',
    'Construir ficha do produto',
    (FeatureContext c) => DetailFeature(context: c),
  ),
  (
    'T07',
    'Criar formulário de avaliação',
    (FeatureContext c) => ReviewFormFeature(context: c),
  ),
  (
    'T08',
    'Persistir e consultar avaliações',
    (FeatureContext c) => ReviewStoreFeature(context: c),
  ),
  (
    'T09',
    'Exibir comentários do produto',
    (FeatureContext c) => CommentsFeature(context: c),
  ),
  (
    'T10',
    'Calcular resumo das avaliações',
    (FeatureContext c) => SummaryFeature(context: c),
  ),
  (
    'T11',
    'Listar minhas avaliações',
    (FeatureContext c) => MyReviewsFeature(context: c),
  ),
  (
    'T12',
    'Filtrar por marca e categoria',
    (FeatureContext c) => FiltersFeature(context: c),
  ),
  (
    'T13',
    'Explorar produtos e notas de marca',
    (FeatureContext c) => BrandsFeature(context: c),
  ),
  (
    'T14',
    'Classificar produtos por categoria',
    (FeatureContext c) => RankingFeature(context: c),
  ),
  (
    'T15',
    'Mascarar palavrões na exibição',
    (FeatureContext c) => ModerationFeature(context: c),
  ),
  (
    'T16',
    'Editar minha avaliação',
    (FeatureContext c) => EditReviewFeature(context: c),
  ),
  (
    'T17',
    'Excluir minha avaliação',
    (FeatureContext c) => DeleteReviewFeature(context: c),
  ),
  (
    'T18',
    'Favoritar produtos',
    (FeatureContext c) => FavoritesFeature(context: c),
  ),
  (
    'T19',
    'Denunciar comentário',
    (FeatureContext c) => ReportFeature(context: c),
  ),
  (
    'T20',
    'Comparar dois produtos',
    (FeatureContext c) => CompareFeature(context: c),
  ),
  (
    'T21',
    'Filtrar por nota mínima',
    (FeatureContext c) => MinimumRatingFeature(context: c),
  ),
  (
    'T22',
    'Registrar onde encontrei',
    (FeatureContext c) => SightingsFeature(context: c),
  ),
  ('T23', 'Definir apelido', (FeatureContext c) => NicknameFeature(context: c)),
  (
    'T24',
    'Guardar histórico de produtos vistos',
    (FeatureContext c) => HistoryFeature(context: c),
  ),
  ('T26', 'Aparência', (FeatureContext c) => AppearanceFeature(context: c)),
  (
    'ENT02',
    'Preferências de notificações',
    (FeatureContext c) => NotificationPreferencesFeature(context: c),
  ),
];
