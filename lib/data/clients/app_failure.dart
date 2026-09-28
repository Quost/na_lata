enum FailureKind {
  timeout,
  network,
  unauthorized,
  conflict,
  validation,
  unavailable,
  invalidResponse,
}

/// Mensagem segura para a UI. Nunca transportar tokens ou corpo bruto da API.
class AppFailure implements Exception {
  const AppFailure(this.kind, this.message);
  final FailureKind kind;
  final String message;
  @override
  String toString() => message;
}
