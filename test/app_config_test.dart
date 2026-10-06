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

  test('HTTP só é aceito para o Supabase local (máquina ou emulador)', () {
    for (final url in [
      'http://127.0.0.1:54321',
      'http://localhost:54321',
      'http://10.0.2.2:54321',
    ]) {
      final config = AppConfig(
        mode: 'supabase',
        url: url,
        key: 'sb_publishable_test',
      );
      config.validate();
      expect(config.isLocal, isTrue, reason: url);
    }
    for (final url in [
      'http://localhost.example.com:54321',
      'http://192.168.0.10:54321',
      'http://10.0.2.2.example.com',
    ]) {
      expect(
        () => AppConfig(
          mode: 'supabase',
          url: url,
          key: 'sb_publishable_test',
        ).validate(),
        throwsFormatException,
        reason: url,
      );
    }
    expect(
      const AppConfig(
        mode: 'supabase',
        url: 'https://example.supabase.co',
        key: 'sb_publishable_test',
      ).isLocal,
      isFalse,
    );
  });
}
