import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Ponte pro widget Pluggy Connect (`window.FinancasPluggy`, definido em
/// web/index.html) — abre a tela deles de escolher banco/autenticar, e
/// devolve os dados do Item recém-conectado quando o usuário termina.
class PluggyConnectService {
  const PluggyConnectService();

  JSObject? get _bridge {
    final value = globalContext.getProperty('FinancasPluggy'.toJS);
    if (value.isUndefinedOrNull) return null;
    return value as JSObject;
  }

  Future<Map<String, dynamic>> open(String connectToken) async {
    final bridge = _bridge;
    if (bridge == null) throw Exception('pluggy_bridge_missing');
    final promise = bridge.callMethod('open'.toJS, connectToken.toJS) as JSPromise<JSAny?>;
    final result = await promise.toDart;
    final jsonStr = (result as JSString).toDart;
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}
