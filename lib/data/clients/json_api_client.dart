import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'app_failure.dart';

/// Transporte HTTP de leitura. Parsing de Product é responsabilidade da T01.
class JsonApiClient {
  JsonApiClient({
    http.Client? transport,
    this.timeout = const Duration(seconds: 10),
  }) : _transport = transport ?? http.Client();
  final http.Client _transport;
  final Duration timeout;

  Future<Map<String, dynamic>> getObject(Uri uri) async {
    try {
      final response = await _transport
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent':
                  'NaLataClassroom/1.0 (https://github.com/ADSSTech/na_lata)',
            },
          )
          .timeout(timeout);
      if (response.statusCode == 429) {
        throw const AppFailure(
          FailureKind.unavailable,
          'Muitas consultas. Aguarde antes de tentar novamente.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AppFailure(
          FailureKind.unavailable,
          'O serviço de produtos não respondeu como esperado.',
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) {
        throw const FormatException('JSON deve ser objeto');
      }
      return data;
    } on TimeoutException {
      throw const AppFailure(
        FailureKind.timeout,
        'A consulta demorou demais. Tente novamente.',
      );
    } on SocketException {
      throw const AppFailure(
        FailureKind.network,
        'Sem conexão. Verifique sua internet.',
      );
    } on http.ClientException {
      throw const AppFailure(
        FailureKind.network,
        'Não foi possível conectar ao serviço de produtos.',
      );
    } on FormatException {
      throw const AppFailure(
        FailureKind.invalidResponse,
        'O serviço retornou dados inválidos.',
      );
    }
  }

  /// Quem cria o transporte é responsável por encerrar este cliente ao descartá-lo.
  void close() => _transport.close();
}
