import 'package:url_launcher/url_launcher.dart';

/// Abre [uri] fora do app. Devolve false se nada pôde abrir o link; pode
/// lançar em erro de plataforma. Quem chama trata os dois casos.
typedef LinkOpener = Future<bool> Function(Uri uri);

Future<bool> openExternalLink(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
