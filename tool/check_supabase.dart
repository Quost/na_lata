import 'dart:convert';
import 'dart:io';
import 'package:na_lata/core/app_config.dart';

/// Sem argumentos: apenas verifica autenticação. --session cria um usuário de
/// diagnóstico e confirma perfil/tabelas, sem escrever produtos ou avaliações.
Future<void> main(List<String> args) async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final file = File('config/classroom.json');
    if (!file.existsSync()) {
      throw const FormatException('Falta config/classroom.json.');
    }
    final config = AppConfig.fromMap(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
    config.validate();
    if (config.isDemo) {
      throw const FormatException(
        'Use APP_MODE=supabase para diagnosticar a conexão.',
      );
    }
    Future<(int, dynamic)> request(
      String path, {
      String? token,
      bool post = false,
    }) async {
      final req = await http
          .openUrl(post ? 'POST' : 'GET', Uri.parse(config.url).resolve(path))
          .timeout(const Duration(seconds: 10));
      req.headers.set('apikey', config.key);
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      if (post) {
        req.headers.contentType = ContentType.json;
        req.write('{}');
      }
      final response = await req.close().timeout(const Duration(seconds: 10));
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      return (response.statusCode, jsonDecode(body));
    }

    final settings = await request('/auth/v1/settings');
    if (settings.$1 != 200) {
      stderr.writeln(
        'Configurações Auth indisponíveis (HTTP ${settings.$1}). Confira URL e chave no painel.',
      );
      exitCode = 2;
      return;
    }
    stdout.writeln('URL e chave pública: aceitas pelo serviço Auth.');
    if (settings.$2['external']['anonymous_users'] != true) {
      stderr.writeln(
        'PENDENTE: habilitar Anonymous Sign-Ins em Authentication no Supabase.',
      );
      exitCode = 2;
      return;
    }
    stdout.writeln('Login anônimo: habilitado.');
    if (!args.contains('--session')) {
      stdout.writeln(
        'Para validar perfil e tabelas, execute com --session (cria um usuário de diagnóstico).',
      );
      return;
    }
    final auth = await request('/auth/v1/signup', post: true);
    if (auth.$1 != 200 && auth.$1 != 201) {
      stderr.writeln(
        'Não foi possível criar a sessão (HTTP ${auth.$1}). Confira CAPTCHA, limite de cadastros e trigger de perfil no painel.',
      );
      exitCode = 2;
      return;
    }
    final token = auth.$2['access_token'] as String;
    final userId = auth.$2['user']['id'] as String;
    final profile = await request(
      '/rest/v1/profiles?select=id&id=eq.$userId',
      token: token,
    );
    if (profile.$1 != 200 ||
        profile.$2 is! List ||
        (profile.$2 as List).length != 1) {
      stderr.writeln(
        'PENDENTE: perfil não foi encontrado. Confira a migração, o trigger e a RLS.',
      );
      exitCode = 2;
      return;
    }
    for (final table in [
      'products',
      'reviews',
      'favorites',
      'reports',
      'sightings',
    ]) {
      final result = await request(
        '/rest/v1/$table?select=*&limit=0',
        token: token,
      );
      if (result.$1 != 200) {
        stderr.writeln(
          'PENDENTE: acesso a $table retornou HTTP ${result.$1}. Confira a migração e as permissões.',
        );
        exitCode = 2;
        return;
      }
    }
    stdout.writeln(
      'Sessão, perfil e leitura das cinco tabelas: OK. Escritas e RLS entre usuários precisam dos testes de integração documentados.',
    );
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
  } catch (_) {
    stderr.writeln(
      'Não foi possível completar o diagnóstico. Confira internet, configuração e estado do projeto no painel.',
    );
    exitCode = 2;
  } finally {
    http.close(force: true);
  }
}
