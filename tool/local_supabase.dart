import 'dart:convert';
import 'dart:io';
import 'package:na_lata/core/app_config.dart';

/// QUA01 — Supabase LOCAL (Docker) com contas A/B e fixtures.
///
/// Nunca acessa o projeto da turma: recusa --linked/--db-url/--project-ref,
/// confere no `supabase status` que API e banco são locais antes de apagar
/// dados e só escreve config/local*.json (classroom.json fica intocado).
/// Das saídas do CLI lê apenas URL e chave publishable; chaves secretas não
/// são lidas nem impressas.
const usage = '''
Uso: dart run tool/local_supabase.dart <comando>

  start   sobe o Supabase local (Docker), aplica migrações e seeds, gera configs
  reset   recria o banco LOCAL do zero (migrações + supabase/seeds)
  seed    reaplica só os seeds no banco LOCAL (idempotente)
  env     gera config/local.json e config/local.android.json
  check   confere URL local, contas A/B e fixtures [--config=config/local.json]
  stop    desliga os containers locais''';

/// Versão fixa do CLI para a turma inteira ter o mesmo ambiente.
const cliVersion = '2.119.0';

/// Container do banco: `supabase_db_` + project_id de supabase/config.toml.
const dbContainer = 'supabase_db_na_lata';

const fixturePassword = 'nalata-local-123';
const fixtureEmails = ['aluno.a@nalata.local', 'aluno.b@nalata.local'];

const remoteFlags = ['--linked', '--db-url', '--project-ref'];

/// Mensagem de recusa quando algum argumento apontaria para um banco remoto.
String? remoteFlagError(List<String> args) {
  for (final arg in args) {
    if (remoteFlags.any((flag) => arg == flag || arg.startsWith('$flag='))) {
      return 'Recusado: $arg aponta para outro banco. Este script só opera o Supabase local.';
    }
  }
  return null;
}

Future<void> main(List<String> args) async {
  final refusal = remoteFlagError(args);
  if (refusal != null) return fail(refusal);
  final command = args.isEmpty ? '' : args.first;
  try {
    switch (command) {
      case 'start':
        if (await cli(['start']) != 0) {
          return fail('Não foi possível subir. O Docker está aberto?');
        }
        await writeLocalConfigs(await localStatus());
      case 'reset':
        await localStatus();
        if (await cli(['db', 'reset', '--local']) != 0) {
          return fail('Reset local falhou; leia a mensagem acima.');
        }
      case 'seed':
        await localStatus();
        await seed();
      case 'env':
        await writeLocalConfigs(await localStatus());
      case 'check':
        await check(args);
      case 'stop':
        exitCode = await cli(['stop']);
      default:
        stdout.writeln(usage);
        exitCode = command.isEmpty ? 0 : 64;
    }
  } on FormatException catch (error) {
    fail(error.message);
  }
}

void fail(String message) {
  stderr.writeln(message);
  exitCode = 2;
}

Future<int> cli(List<String> args) async {
  final process = await Process.start(
    'npx',
    ['--yes', 'supabase@$cliVersion', ...args],
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  return process.exitCode;
}

/// Lê `supabase status` e garante que API e banco estão nesta máquina.
Future<({String url, String key})> localStatus() async {
  final result = await Process.run('npx', [
    '--yes',
    'supabase@$cliVersion',
    'status',
    '-o',
    'json',
  ], runInShell: Platform.isWindows);
  final out = '${result.stdout}';
  final start = out.indexOf('{');
  if (result.exitCode != 0 || start < 0) {
    throw const FormatException(
      'Supabase local não está rodando. Execute: dart run tool/local_supabase.dart start',
    );
  }
  final status = jsonDecode(out.substring(start)) as Map<String, dynamic>;
  final url = '${status['API_URL']}';
  final key = '${status['PUBLISHABLE_KEY']}';
  final dbHost = Uri.tryParse('${status['DB_URL']}')?.host;
  final config = AppConfig(mode: 'supabase', url: url, key: key);
  if (!config.isLocal || !AppConfig.localHosts.contains(dbHost)) {
    throw const FormatException(
      'Recusado: o status não aponta para um Supabase local.',
    );
  }
  config.validate();
  return (url: url, key: key);
}

Future<void> writeLocalConfigs(({String url, String key}) status) async {
  final port = Uri.parse(status.url).port;
  final files = {
    'config/local.json': 'http://127.0.0.1:$port',
    // O emulador Android enxerga a máquina hospedeira em 10.0.2.2.
    'config/local.android.json': 'http://10.0.2.2:$port',
  };
  for (final entry in files.entries) {
    File(entry.key).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'APP_MODE': 'supabase', 'SUPABASE_URL': entry.value, 'SUPABASE_PUBLISHABLE_KEY': status.key})}\n',
    );
    stdout.writeln('Gerado ${entry.key} (${entry.value}).');
  }
  stdout.writeln('config/classroom.json não foi alterado.');
}

/// Reaplica supabase/seeds/*.sql em uma transação, só no container local.
Future<void> seed() async {
  final files =
      Directory('supabase/seeds')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final process = await Process.start('docker', [
    'exec',
    '-i',
    dbContainer,
    'psql',
    '-U',
    'postgres',
    '-d',
    'postgres',
    '-v',
    'ON_ERROR_STOP=1',
    '--quiet',
    '--single-transaction',
  ]);
  for (final file in files) {
    process.stdin.writeln(file.readAsStringSync());
  }
  await process.stdin.close();
  final errors = await process.stderr.transform(utf8.decoder).join();
  await process.stdout.drain<void>();
  if (await process.exitCode != 0) {
    throw FormatException('Seed falhou; nada foi gravado.\n$errors');
  }
  stdout.writeln('Seeds reaplicados (${files.length} arquivos).');
}

Future<void> check(List<String> args) async {
  final path = args
      .firstWhere(
        (arg) => arg.startsWith('--config='),
        orElse: () => '--config=config/local.json',
      )
      .substring('--config='.length);
  final file = File(path);
  if (!file.existsSync()) {
    throw FormatException(
      'Falta $path. Execute: dart run tool/local_supabase.dart env',
    );
  }
  final config = AppConfig.fromMap(
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
  );
  config.validate();
  if (!config.isLocal) {
    throw FormatException(
      'Recusado: $path aponta para ${Uri.parse(config.url).host}, não para o Supabase local.',
    );
  }
  // 10.0.2.2 só existe dentro do emulador; daqui testamos a mesma porta local.
  final base = Uri.parse(config.url).replace(host: '127.0.0.1');
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    Future<(int, dynamic)> request(
      String method,
      String path, {
      String? token,
      Object? body,
    }) async {
      final req = await http.openUrl(method, base.resolve(path));
      req.headers.set('apikey', config.key);
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final response = await req.close().timeout(const Duration(seconds: 10));
      final text = await response.transform(utf8.decoder).join();
      return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
    }

    final settings = await request('GET', '/auth/v1/settings');
    if (settings.$1 != 200 ||
        settings.$2['external']['anonymous_users'] != true) {
      throw const FormatException(
        'Auth local indisponível ou sem login anônimo. Confira supabase/config.toml.',
      );
    }
    final tokens = <String>[];
    for (final email in fixtureEmails) {
      final auth = await request(
        'POST',
        '/auth/v1/token?grant_type=password',
        body: {'email': email, 'password': fixturePassword},
      );
      if (auth.$1 != 200) {
        throw FormatException(
          'Login de $email falhou (HTTP ${auth.$1}). Execute reset ou seed.',
        );
      }
      tokens.add(auth.$2['access_token'] as String);
    }
    stdout.writeln('Contas A e B: login OK.');
    final products = await request(
      'GET',
      '/rest/v1/products?select=barcode&barcode=like.200*',
      token: tokens[0],
    );
    if (products.$1 != 200 || (products.$2 as List).length < 5) {
      throw const FormatException(
        'Fixtures de catálogo ausentes. Execute: dart run tool/local_supabase.dart seed',
      );
    }
    stdout.writeln('Fixtures de catálogo: OK.');
    final favoritesOfB = await request(
      'GET',
      '/rest/v1/favorites?select=user_id',
      token: tokens[1],
    );
    final owners = {
      for (final row in favoritesOfB.$2 as List) (row as Map)['user_id'],
    };
    if (favoritesOfB.$1 != 200 ||
        owners.length != 1 ||
        owners.first != 'bbbbbbbb-0000-4000-8000-00000000000b') {
      throw const FormatException(
        'RLS de favoritos inesperada: B deveria ver só os próprios.',
      );
    }
    stdout.writeln('RLS: B vê apenas os próprios favoritos.');
    stdout.writeln(
      'Ambiente local pronto. Smoke A/B com repositórios: veja docs/LOCAL.md.',
    );
  } on SocketException {
    throw FormatException(
      'Sem conexão com ${base.origin}. Execute: dart run tool/local_supabase.dart start',
    );
  } finally {
    http.close(force: true);
  }
}
