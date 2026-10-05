import 'package:flutter/foundation.dart';
import '../../core/notification_contracts.dart';
import '../../data/clients/app_failure.dart';

enum NotificationPrefsStatus { loading, ready, failed }

class NotificationPreferencesController extends ChangeNotifier {
  NotificationPreferencesController(this._repository);
  final NotificationPreferencesRepository _repository;

  NotificationPrefsStatus status = NotificationPrefsStatus.loading;
  NotificationPreferences value = const NotificationPreferences();
  String? loadError;
  String? saveError;
  bool saving = false;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    status = NotificationPrefsStatus.loading;
    loadError = null;
    saveError = null;
    _notify();
    try {
      value = await _repository.load();
      status = NotificationPrefsStatus.ready;
    } catch (e) {
      loadError = _message(e, 'Não foi possível carregar suas preferências.');
      status = NotificationPrefsStatus.failed;
    }
    _notify();
  }

  Future<bool> setReplies(bool enabled) =>
      _change((current) => current.copyWith(replies: enabled));

  Future<bool> setNewFollowers(bool enabled) =>
      _change((current) => current.copyWith(newFollowers: enabled));

  Future<bool> _change(
    NotificationPreferences Function(NotificationPreferences) edit,
  ) async {
    if (saving || status != NotificationPrefsStatus.ready) return false;
    final previous = value;
    value = edit(previous);
    saving = true;
    saveError = null;
    _notify();
    try {
      value = await _repository.save(value);
      saving = false;
      _notify();
      return true;
    } catch (e) {
      var restored = previous;
      if (e is AppFailure && e.kind == FailureKind.timeout) {
        try {
          restored = await _repository.load();
        } catch (_) {
          restored = previous;
        }
      }
      value = restored;
      saving = false;
      saveError = _message(
        e,
        'Não foi possível salvar. A opção voltou ao valor anterior.',
      );
      _notify();
      return false;
    }
  }

  String _message(Object error, String fallback) =>
      error is AppFailure ? error.message : fallback;
}
