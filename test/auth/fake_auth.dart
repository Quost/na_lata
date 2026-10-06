import 'dart:async';
import 'package:na_lata/data/auth_repository.dart';

const userA = AuthIdentity(userId: 'user-a', isAnonymous: true);
const userB = AuthIdentity(userId: 'user-b', isAnonymous: true);

/// Auth controlado pelo teste: eventos são emitidos manualmente e o login
/// anônimo devolve [nextGuest] ou lança [signInError].
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.current});
  final _events = StreamController<AuthChange>.broadcast();

  @override
  AuthIdentity? current;
  AuthIdentity nextGuest = userA;
  Object? signInError;
  Completer<void>? holdSignIn;
  int signInCalls = 0;

  void emit(AuthChange change) {
    if (change is AuthSignedIn) current = change.identity;
    if (change is AuthSignedOut) current = null;
    _events.add(change);
  }

  void emitError(Object error) => _events.addError(error);

  @override
  Stream<AuthChange> get changes => _events.stream;

  @override
  Future<AuthIdentity> signInAnonymously() async {
    signInCalls++;
    await holdSignIn?.future;
    final error = signInError;
    if (error != null) throw error;
    current = nextGuest;
    return nextGuest;
  }

  // AUT02 — salvar conta. [accountError] faz a próxima ação de conta falhar.
  @override
  String? pendingEmail;
  Object? accountError;
  final linkedEmails = <String>[];
  int resendCalls = 0;
  int passwordSets = 0;

  void _failIfNeeded() {
    final error = accountError;
    if (error != null) throw error;
  }

  @override
  Future<void> linkEmail(String email) async {
    _failIfNeeded();
    linkedEmails.add(email);
    pendingEmail = email;
  }

  @override
  Future<void> resendConfirmation(String email) async {
    _failIfNeeded();
    resendCalls++;
  }

  /// Simula o clique no link: mesmo userId, agora sem ser anônimo.
  void confirmEmail() {
    pendingEmail = null;
    emit(
      AuthSignedIn(AuthIdentity(userId: current!.userId, isAnonymous: false)),
    );
  }

  @override
  Future<AuthIdentity> reload() async {
    _failIfNeeded();
    return current!;
  }

  @override
  Future<void> setPassword(String password) async {
    _failIfNeeded();
    passwordSets++;
  }

  Future<void> close() => _events.close();
}
