import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Versão atual do primeiro uso. Subir este número reapresenta o onboarding a
/// quem concluiu uma versão anterior (ex.: quando a proposta do app mudar).
const onboardingVersion = 1;

/// Chaves no SharedPreferences. Tudo fica só no aparelho: nada vai ao banco.
const onboardingVersionKey = 'onboarding_completed_version';
const onboardingRegionKey = 'onboarding_region';

/// Região de busca escolhida no primeiro uso.
///
/// Interface provisória até o seletor de municípios por código IBGE (GEO02):
/// o [id] é um texto estável local, não um código oficial.
class OnboardingRegion {
  const OnboardingRegion(this.id, this.label);
  final String id;
  final String label;
}

/// Lista fake e curta, só para o onboarding enquanto GEO02 não existe.
const onboardingRegions = [
  OnboardingRegion('joinville-sc', 'Joinville • SC'),
  OnboardingRegion('florianopolis-sc', 'Florianópolis • SC'),
  OnboardingRegion('curitiba-pr', 'Curitiba • PR'),
  OnboardingRegion('sao-paulo-sp', 'São Paulo • SP'),
];

/// Estado do primeiro uso: se deve aparecer e qual região foi escolhida.
///
/// Nunca bloqueia o app: falha ao ler o aparelho pula o onboarding, e falha ao
/// gravar conclui só nesta sessão (volta a aparecer no próximo início).
class OnboardingController extends ChangeNotifier {
  OnboardingController({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  var _shouldShow = false;
  String? _regionId;

  /// True enquanto a versão atual ainda não foi concluída neste aparelho.
  bool get shouldShow => _shouldShow;

  /// Região de busca salva, ou null para "Todas as regiões".
  String? get regionId => _regionId;

  /// Lê a versão concluída e a região salva. Ausente ou de versão anterior
  /// mostra o onboarding; erro de leitura não mostra nada.
  Future<void> load() async {
    try {
      final prefs = await _preferences();
      final done = prefs.getInt(onboardingVersionKey) ?? 0;
      _regionId = _knownRegion(prefs.getString(onboardingRegionKey));
      _shouldShow = done < onboardingVersion;
    } catch (_) {
      _shouldShow = false;
    }
    notifyListeners();
  }

  /// Conclui o onboarding. [regionId] null significa "Todas as regiões" e
  /// apaga uma escolha anterior. Não cria conta nem pede permissão alguma.
  Future<void> complete({String? regionId}) async {
    _regionId = _knownRegion(regionId);
    _shouldShow = false;
    notifyListeners();
    try {
      final prefs = await _preferences();
      await prefs.setInt(onboardingVersionKey, onboardingVersion);
      if (_regionId == null) {
        await prefs.remove(onboardingRegionKey);
      } else {
        await prefs.setString(onboardingRegionKey, _regionId!);
      }
    } catch (_) {
      // Segue sem persistir: o usuário já está explorando.
    }
  }

  /// Só aceita ids da lista atual; valor antigo ou corrompido vira null.
  String? _knownRegion(String? id) =>
      onboardingRegions.any((r) => r.id == id) ? id : null;
}
