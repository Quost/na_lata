import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/data/auth_repository.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/features/auth/session_controller.dart';
import 'fake_auth.dart';

void main() {
  late FakeAuthRepository auth;
  late SessionController session;
  late int notifications;

  void create({AuthIdentity? current}) {
    auth = FakeAuthRepository(current: current);
    session = SessionController(auth);
    notifications = 0;
    session.addListener(() => notifications++);
    addTearDown(() {
      session.dispose();
      return auth.close();
    });
  }

  test('usa sessão restaurada sem criar visitante novo', () async {
    create(current: userA);
    await session.start();
    expect(session.state, isA<SessionGuest>());
    expect(session.userId, 'user-a');
    expect(auth.signInCalls, 0);
  });

  test(
    'sem sessão cria um único visitante mesmo com chamadas concorrentes',
    () async {
      create();
      final first = session.start();
      final second = session.retry();
      await Future.wait([first, second]);
      expect(auth.signInCalls, 1);
      expect(session.state, const SessionGuest(userA));
    },
  );

  test('refresh de token e eventos duplicados não notificam', () async {
    create(current: userA);
    await session.start();
    notifications = 0;
    auth.emit(const AuthSignedIn(userA)); // tokenRefreshed
    auth.emit(const AuthSignedIn(userA)); // duplicado
    await pumpEventQueue();
    expect(notifications, 0);
    expect(session.userId, 'user-a');
  });

  test('troca A→B muda userId e notifica uma vez', () async {
    create(current: userA);
    await session.start();
    notifications = 0;
    auth.emit(const AuthSignedIn(userB));
    auth.emit(const AuthSignedIn(userB));
    await pumpEventQueue();
    expect(session.userId, 'user-b');
    expect(notifications, 1);
  });

  test('visitante que vira conta mantém userId e muda de estado', () async {
    create(current: userA);
    await session.start();
    auth.emit(
      const AuthSignedIn(AuthIdentity(userId: 'user-a', isAnonymous: false)),
    );
    await pumpEventQueue();
    expect(session.state, isA<SessionAccount>());
    expect(session.userId, 'user-a');
  });

  test(
    'sessão expirada pede recuperação explícita, sem visitante automático',
    () async {
      create(current: userA);
      await session.start();
      auth.emit(const AuthSignedOut(expired: true));
      await pumpEventQueue();
      expect(
        session.state,
        isA<SessionFailed>().having((s) => s.expired, 'expired', isTrue),
      );
      expect(session.userId, isNull);
      expect(auth.signInCalls, 0);

      auth.nextGuest = userB;
      await session.retry();
      expect(auth.signInCalls, 1);
      expect(session.state, const SessionGuest(userB));
    },
  );

  test('saída pedida também não cria sessão anônima sozinha', () async {
    create(current: userA);
    await session.start();
    auth.emit(const AuthSignedOut(expired: false));
    await pumpEventQueue();
    expect(
      session.state,
      isA<SessionFailed>().having((s) => s.expired, 'expired', isFalse),
    );
    expect(auth.signInCalls, 0);
  });

  test('erro de rede no stream mantém a identidade local', () async {
    create(current: userA);
    await session.start();
    auth.emitError(const AppFailure(FailureKind.network, 'Sem conexão.'));
    await pumpEventQueue();
    expect(session.state, const SessionGuest(userA));
  });

  test(
    'falha ao criar visitante mostra mensagem segura e permite tentar de novo',
    () async {
      create();
      auth.signInError = const AppFailure(
        FailureKind.network,
        'Sem conexão. Verifique sua internet.',
      );
      await session.start();
      expect(
        session.state,
        const SessionFailed('Sem conexão. Verifique sua internet.'),
      );

      auth.signInError = StateError('detalhe interno');
      await session.retry();
      expect(
        (session.state as SessionFailed).message,
        isNot(contains('detalhe interno')),
      );

      auth.signInError = null;
      await session.retry();
      expect(session.state, const SessionGuest(userA));
      expect(auth.signInCalls, 3);
    },
  );

  test('evento durante login anônimo prevalece sobre o resultado', () async {
    create();
    auth.holdSignIn = Completer();
    final starting = session.start();
    expect(session.state, isA<SessionInitializing>());
    auth.emit(const AuthSignedIn(userB));
    await pumpEventQueue();
    auth.holdSignIn!.complete();
    await starting;
    expect(session.userId, 'user-b');
  });
}
