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

  Future<void> close() => _events.close();
}
