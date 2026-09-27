import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Ponte pro objeto `window.FinancasBiometric` definido em web/index.html —
/// Face ID/Touch ID/Windows Hello via WebAuthn, usados só como destravamento
/// local do bloqueio por PIN (ver app_lock_provider.dart e a nota no bridge
/// JS: não há verificação de assinatura no servidor, é o mesmo nível de
/// confiança que o PIN já tinha).
class BiometricUnlockService {
  const BiometricUnlockService();

  JSObject? get _bridge {
    final value = globalContext.getProperty('FinancasBiometric'.toJS);
    if (value.isUndefinedOrNull) return null;
    return value as JSObject;
  }

  Future<bool> isSupported() async {
    final bridge = _bridge;
    if (bridge == null) return false;
    try {
      final promise = bridge.callMethod('isSupported'.toJS) as JSPromise<JSAny?>;
      final result = await promise.toDart;
      return (result as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }

  /// Cria a credencial nesse dispositivo (pede a biometria uma vez, na
  /// hora de ativar) e devolve o id pra guardar localmente.
  Future<String> register() async {
    final bridge = _bridge!;
    final promise = bridge.callMethod('register'.toJS) as JSPromise<JSAny?>;
    final result = await promise.toDart;
    return (result as JSString).toDart;
  }

  /// Pede a biometria de novo, contra a credencial já registrada. `false`
  /// (nunca uma exceção pro chamador) tanto pra "cancelou" quanto pra
  /// "falhou" — quem chama sempre cai de volta pro PIN nesses casos.
  Future<bool> authenticate(String credentialId) async {
    final bridge = _bridge;
    if (bridge == null) return false;
    try {
      final promise =
          bridge.callMethod('authenticate'.toJS, credentialId.toJS) as JSPromise<JSAny?>;
      final result = await promise.toDart;
      return (result as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }
}
