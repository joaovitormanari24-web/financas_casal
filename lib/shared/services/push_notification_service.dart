import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Ponte pro objeto `window.FinancasPush` definido em web/index.html —
/// mantém a lógica de Push API (que precisa de PushManager/Notification,
/// só existentes em JS) fora do Dart.
class PushNotificationService {
  const PushNotificationService();

  /// Chave pública VAPID — segura de embutir no cliente (é a metade
  /// pública do par; a privada só existe na Edge Function).
  static const vapidPublicKey =
      'BOrPBLNZHHLWP-CubwRlAhod3y_jHfJgxo4iRbt2laSP3UmS4tGCKZ1-Tdg4yCBZAEnGyPTYWFY7ILz1JVkbByc';

  JSObject? get _bridge {
    final value = globalContext.getProperty('FinancasPush'.toJS);
    if (value.isUndefinedOrNull) return null;
    return value as JSObject;
  }

  bool get isSupported {
    final bridge = _bridge;
    if (bridge == null) return false;
    try {
      final result = bridge.callMethod('isSupported'.toJS) as JSBoolean;
      return result.toDart;
    } catch (_) {
      return false;
    }
  }

  /// Pede permissão, registra o service worker de push e devolve a
  /// inscrição já decodificada (endpoint/p256dh/auth).
  Future<PushSubscriptionInfo> subscribe() async {
    final bridge = _bridge!;
    final promise =
        bridge.callMethod('register'.toJS, vapidPublicKey.toJS) as JSPromise<JSAny?>;
    final result = await promise.toDart;
    final jsonStr = (result as JSString).toDart;
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    final keys = decoded['keys'] as Map<String, dynamic>;
    return PushSubscriptionInfo(
      endpoint: decoded['endpoint'] as String,
      p256dh: keys['p256dh'] as String,
      auth: keys['auth'] as String,
    );
  }

  Future<String?> currentEndpoint() async {
    final bridge = _bridge;
    if (bridge == null) return null;
    final promise = bridge.callMethod('currentEndpoint'.toJS) as JSPromise<JSAny?>;
    final result = await promise.toDart;
    if (result.isUndefinedOrNull) return null;
    return (result as JSString).toDart;
  }

  Future<void> unsubscribe() async {
    final bridge = _bridge;
    if (bridge == null) return;
    final promise = bridge.callMethod('unregister'.toJS) as JSPromise<JSAny?>;
    await promise.toDart;
  }
}

class PushSubscriptionInfo {
  const PushSubscriptionInfo({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  final String endpoint;
  final String p256dh;
  final String auth;
}
