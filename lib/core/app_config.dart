class AppConfig {
  const AppConfig({this.mode = 'demo', this.url = '', this.key = ''});

  factory AppConfig.fromEnvironment() => const AppConfig(
    mode: String.fromEnvironment('APP_MODE', defaultValue: 'demo'),
    url: String.fromEnvironment('SUPABASE_URL'),
    key: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  factory AppConfig.fromMap(Map<String, dynamic> values) => AppConfig(
    mode: values['APP_MODE'] as String? ?? 'demo',
    url: values['SUPABASE_URL'] as String? ?? '',
    key: values['SUPABASE_PUBLISHABLE_KEY'] as String? ?? '',
  );

  /// Supabase local (QUA01): a própria máquina ou o host dela visto pelo
  /// emulador Android (10.0.2.2). Somente esses hosts aceitam HTTP.
  static const localHosts = {'127.0.0.1', 'localhost', '10.0.2.2'};

  final String mode, url, key;
  bool get isDemo => mode == 'demo';
  bool get isLocal => localHosts.contains(Uri.tryParse(url)?.host);

  void validate() {
    if (mode != 'demo' && mode != 'supabase') {
      throw const FormatException('APP_MODE deve ser demo ou supabase.');
    }
    if (isDemo) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.scheme == 'https' || (uri.scheme == 'http' && isLocal)) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Confira SUPABASE_URL em config/classroom.json. Use a URL HTTPS do projeto.',
      );
    }
    if (!key.startsWith('sb_publishable_') ||
        key.trim() != key ||
        key.length <= 'sb_publishable_'.length) {
      throw const FormatException(
        'Use a chave pública sb_publishable_ em config/classroom.json. Chaves administrativas não são aceitas.',
      );
    }
  }
}
