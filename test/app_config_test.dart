import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/core/app_config.dart';

void main() {
  test('demo funciona sem credenciais', () {
    const AppConfig().validate();
  });
  test(
    'configuração compartilhada aceita somente URL HTTPS e chave pública',
    () {
      AppConfig.fromMap({
        'APP_MODE': 'supabase',
        'SUPABASE_URL': 'https://example.supabase.co',
        'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_test',
      }).validate();
      for (final key in ['', 'sb_secret_admin', 'eyJlegacy']) {
        expect(
          () => AppConfig(
            mode: 'supabase',
            url: 'https://example.supabase.co',
            key: key,
          ).validate(),
          throwsFormatException,
        );
      }
      expect(
        () => const AppConfig(
          mode: 'supabase',
          url: 'http://example.com',
          key: 'sb_publishable_test',
        ).validate(),
        throwsFormatException,
      );
      expect(
        () => const AppConfig(mode: 'typo').validate(),
        throwsFormatException,
      );
    },
  );
}
