import 'dart:convert';
import 'dart:io';
import 'package:na_lata/core/app_config.dart';

Future<void> main(List<String> args) async {
  final demo = args.contains('--demo');
  final flutterArgs = args.where((arg) => arg != '--demo').toList();
  if (!demo) {
    final file = File('config/classroom.json');
    if (!file.existsSync()) {
      stderr.writeln(
        'Coloque o classroom.json recebido do professor na pasta config. Consulte docs/ALUNOS.md.',
      );
      exitCode = 2;
      return;
    }
    try {
      final config = AppConfig.fromMap(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      );
      config.validate();
      if (config.isDemo) {
        stderr.writeln(
          'Este arquivo usa APP_MODE=demo. Para conectar à turma, use supabase.',
        );
        exitCode = 2;
        return;
      }
    } catch (_) {
      stderr.writeln(
        'Configuração inválida. Confira o formato JSON, APP_MODE, URL HTTPS e chave sb_publishable_.',
      );
      exitCode = 2;
      return;
    }
  }
  final process = await Process.start(
    'flutter',
    [
      'run',
      if (!demo) '--dart-define-from-file=config/classroom.json',
      ...flutterArgs,
    ],
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  exitCode = await process.exitCode;
}
