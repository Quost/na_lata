class NotificationPreferences {
  const NotificationPreferences({
    this.replies = false,
    this.newFollowers = false,
    this.hasChosen = false,
  });

  final bool replies;

  final bool newFollowers;

  final bool hasChosen;

  NotificationPreferences copyWith({bool? replies, bool? newFollowers}) =>
      NotificationPreferences(
        replies: replies ?? this.replies,
        newFollowers: newFollowers ?? this.newFollowers,
        hasChosen: true,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.replies == replies &&
      other.newFollowers == newFollowers &&
      other.hasChosen == hasChosen;

  @override
  int get hashCode => Object.hash(replies, newFollowers, hasChosen);
}

abstract interface class NotificationPreferencesRepository {
  Future<NotificationPreferences> load();

  Future<NotificationPreferences> save(NotificationPreferences value);
}
