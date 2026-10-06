import 'package:flutter/material.dart';
import '../../core/app_scope.dart';
import '../../design_system/na_lata_ui.dart';
import 'notification_preferences_controller.dart';

class NotificationPreferencesFeature extends StatefulWidget {
  const NotificationPreferencesFeature({super.key, required this.context});
  final FeatureContext context;

  @override
  State<NotificationPreferencesFeature> createState() =>
      _NotificationPreferencesFeatureState();
}

class _NotificationPreferencesFeatureState
    extends State<NotificationPreferencesFeature> {
  NotificationPreferencesController? _controller;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    final repository = widget.context.scope.notificationPreferences;
    _controller = repository == null
        ? null
        : (NotificationPreferencesController(repository)..load());
  }

  @override
  void didUpdateWidget(NotificationPreferencesFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.context.scope;
    final now = widget.context.scope;
    if (before.userId != now.userId ||
        before.notificationPreferences != now.notificationPreferences) {
      _controller?.dispose();
      _attach();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext buildContext) {
    final controller = _controller;
    if (controller == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: NaNotice(
          message: 'As preferências de notificações não estão disponíveis.',
        ),
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => switch (controller.status) {
        NotificationPrefsStatus.loading => const NaLoading(
          label: 'Carregando preferências…',
        ),
        NotificationPrefsStatus.failed => NaError(
          message: controller.loadError ?? 'Tente novamente.',
          onRetry: controller.load,
        ),
        NotificationPrefsStatus.ready => _form(context, controller),
      },
    );
  }

  Widget _form(
    BuildContext context,
    NotificationPreferencesController controller,
  ) {
    final value = controller.value;
    final enabled = !controller.saving;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Avisos dentro do app',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const NaNotice(
            message:
                'Os avisos aparecem somente dentro do Na Lata. '
                'Não enviamos e-mail, SMS nem notificações no celular.',
          ),
          if (!value.hasChosen) ...[
            const SizedBox(height: 8),
            const Text(
              'Você ainda não escolheu. Por enquanto, todos os avisos '
              'estão desligados.',
              key: Key('notif_not_chosen'),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('notif_replies'),
            title: const Text('Respostas às minhas avaliações'),
            subtitle: Text(value.replies ? 'Ligado' : 'Desligado'),
            value: value.replies,
            onChanged: enabled ? (v) => controller.setReplies(v) : null,
          ),
          SwitchListTile(
            key: const Key('notif_followers'),
            title: const Text('Novos seguidores'),
            subtitle: Text(value.newFollowers ? 'Ligado' : 'Desligado'),
            value: value.newFollowers,
            onChanged: enabled ? (v) => controller.setNewFollowers(v) : null,
          ),
          if (controller.saving)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Salvando…', key: Key('notif_saving')),
            ),
          if (controller.saveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.saveError!,
                        key: const Key('notif_error'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
