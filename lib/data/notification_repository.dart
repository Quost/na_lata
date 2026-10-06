import '../core/notification_contracts.dart';
import 'clients/app_failure.dart';
import 'clients/backend_client.dart';

class SupabaseNotificationPreferences
    implements NotificationPreferencesRepository {
  SupabaseNotificationPreferences(this.client);
  final BackendClient client;

  @override
  Future<NotificationPreferences> load() async {
    final userId = client.requireUserId;
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db
            .from('notification_preferences')
            .select('replies, new_followers')
            .eq('user_id', userId)
            .limit(1),
      ),
    );
    if (rows.isEmpty) return const NotificationPreferences();
    return _fromRow(rows.first);
  }

  @override
  Future<NotificationPreferences> save(NotificationPreferences value) async {
    final userId = client.requireUserId;
    final rows = await client.request<List<Map<String, dynamic>>>(
      (db) async => List<Map<String, dynamic>>.from(
        await db
            .from('notification_preferences')
            .upsert({
              'user_id': userId,
              'replies': value.replies,
              'new_followers': value.newFollowers,
            }, onConflict: 'user_id')
            .select('replies, new_followers'),
      ),
    );
    if (rows.isEmpty) {
      throw const AppFailure(
        FailureKind.unavailable,
        'Não foi possível confirmar a gravação. Tente novamente.',
      );
    }
    return _fromRow(rows.first);
  }

  NotificationPreferences _fromRow(Map<String, dynamic> row) =>
      NotificationPreferences(
        replies: row['replies'] as bool? ?? false,
        newFollowers: row['new_followers'] as bool? ?? false,
        hasChosen: true,
      );
}

class DemoNotificationPreferences implements NotificationPreferencesRepository {
  NotificationPreferences _value = const NotificationPreferences();

  @override
  Future<NotificationPreferences> load() async => _value;

  @override
  Future<NotificationPreferences> save(NotificationPreferences value) async {
    _value = NotificationPreferences(
      replies: value.replies,
      newFollowers: value.newFollowers,
      hasChosen: true,
    );
    return _value;
  }
}
