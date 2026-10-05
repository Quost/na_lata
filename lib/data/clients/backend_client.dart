import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_failure.dart';

/// Uma instância compartilhada, injetada nos repositórios em main.dart.
/// O callback mantém o query builder oficial sem criar outra linguagem de consulta.
class BackendClient {
  BackendClient(this._supabase, {this.timeout = const Duration(seconds: 10)});
  final SupabaseClient _supabase;
  final Duration timeout;

  bool get isAnonymous => _supabase.auth.currentUser?.isAnonymous ?? true;

  String get requireUserId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) {
      throw const AppFailure(
        FailureKind.unauthorized,
        'Sua sessão expirou. Reinicie o aplicativo.',
      );
    }
    return id;
  }

  /// Não repete escritas: timeout não garante que o servidor cancelou a operação.
  /// A UI deve reconciliar o estado antes de reenviar uma gravação.
  Future<T> request<T>(Future<T> Function(SupabaseClient db) action) async {
    try {
      return await Future<T>.sync(() => action(_supabase)).timeout(timeout);
    } on TimeoutException {
      throw const AppFailure(
        FailureKind.timeout,
        'A operação demorou demais. Confira se foi concluída antes de tentar novamente.',
      );
    } on SocketException {
      throw const AppFailure(
        FailureKind.network,
        'Sem conexão. Verifique sua internet.',
      );
    } on http.ClientException {
      throw const AppFailure(
        FailureKind.network,
        'Não foi possível conectar. Verifique sua internet.',
      );
    } on AuthException catch (error) {
      if (error.code == 'anonymous_provider_disabled') {
        throw const AppFailure(
          FailureKind.unauthorized,
          'O login anônimo está desabilitado no Supabase. Peça ao professor para habilitar Anonymous Sign-Ins em Authentication e reinicie o app.',
        );
      }
      throw const AppFailure(
        FailureKind.unauthorized,
        'Não foi possível validar sua sessão. Reinicie o aplicativo.',
      );
    } on PostgrestException catch (error) {
      switch (error.code) {
        case '42501':
        case 'PGRST301':
        case 'PGRST302':
        case 'PGRST303':
          throw const AppFailure(
            FailureKind.unauthorized,
            'Você não tem permissão para esta operação.',
          );
        case '23505':
          throw const AppFailure(
            FailureKind.conflict,
            'Este registro já existe. Atualize a tela.',
          );
        case '23514':
        case '23503':
        case '23502':
        case '22P02':
          throw const AppFailure(
            FailureKind.validation,
            'Confira os dados informados e tente novamente.',
          );
        default:
          throw const AppFailure(
            FailureKind.unavailable,
            'Não foi possível acessar os dados. Tente novamente mais tarde.',
          );
      }
    }
  }
}
