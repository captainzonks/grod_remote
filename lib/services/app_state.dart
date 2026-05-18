import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'grod_api.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  static const _keyHost = 'server_host';
  static const _keyPort = 'server_port';
  static const _keyPin = 'server_pin';

  String host = '';
  int port = 7878;
  String pin = '';
  GrodApi? _api;
  Status? status;
  String? error;
  bool loading = false;
  Timer? _pollTimer;

  AppState() {
    _loadPrefs();
  }

  bool get configured => host.isNotEmpty;
  GrodApi? get api => _api;

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    host = prefs.getString(_keyHost) ?? '';
    port = prefs.getInt(_keyPort) ?? 7878;
    pin = prefs.getString(_keyPin) ?? '';
    if (configured) _connect();
    notifyListeners();
  }

  Future<void> saveServer(String h, int p, String pi) async {
    host = h;
    port = p;
    pin = pi;
    status = null;
    error = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost, h);
    await prefs.setInt(_keyPort, p);
    await prefs.setString(_keyPin, pi);
    _connect();
    notifyListeners();
  }

  void _connect() {
    _api = GrodApi(host, port, pin: pin);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
    refresh();
  }

  Future<void> refresh() async {
    if (_api == null) return;
    try {
      final s = await _api!.status();
      status = s;
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  Future<void> act(Future<void> Function(GrodApi) fn) async {
    if (_api == null) return;
    loading = true;
    notifyListeners();
    try {
      await fn(_api!);
      error = null;
      await refresh();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
