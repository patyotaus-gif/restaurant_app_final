import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
class TerminalProvider with ChangeNotifier {
  TerminalProvider() {
    _loadTerminalId();
  }

  String? _terminalId;

  String? get terminalId => _terminalId;

  Future<void> _loadTerminalId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('terminalId');
    if (stored == null) {
      _terminalId = null;
    } else {
      _terminalId = stored;
    }
    notifyListeners();
  }

  Future<void> setTerminalId(String? terminalId) async {
    final prefs = await SharedPreferences.getInstance();
    _terminalId = terminalId?.isEmpty == true ? null : terminalId;
    if (_terminalId == null) {
      await prefs.remove('terminalId');
    } else {
      await prefs.setString('terminalId', _terminalId!);
    }
    notifyListeners();
  }
}
