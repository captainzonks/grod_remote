import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import 'grod_api.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  static const _keyHost = 'server_host';
  static const _keyPort = 'server_port';
  static const _keyPin = 'server_pin';
  static const _keyDefaultQuality = 'default_quality';

  String host = '';
  int port = 7878;
  String pin = '';
  GrodApi? _api;
  Status? status;
  String? error;
  bool loading = false;
  Timer? _pollTimer;

  /// User's preferred cast quality, persisted locally. Source of truth for
  /// the Settings dropdown — kept independent of `status.quality`, which
  /// reflects the in-flight track's actual resolved height (and would
  /// otherwise overwrite the user's intent each time a low-bitrate stream
  /// resolved at 360p).
  String defaultQuality = 'best';

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
    defaultQuality = prefs.getString(_keyDefaultQuality) ?? 'best';
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
    // Re-assert the user's saved quality preference so the daemon does not
    // drift back to whatever it last reported in /status.
    unawaited(_pushDefaultQuality());
    notifyListeners();
  }

  /// Persist `q` locally and push it to the daemon as the new default.
  /// Used by Settings — keeps the dropdown selection sticky across
  /// disconnects and ignores transient `status.quality` updates.
  Future<void> setDefaultQuality(String q) async {
    defaultQuality = q;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultQuality, q);
    notifyListeners();
    if (_api != null) {
      try {
        await _api!.setQuality(q);
      } catch (e) {
        error = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> _pushDefaultQuality() async {
    if (_api == null) return;
    try {
      await _api!.setQuality(defaultQuality);
    } catch (_) {
      // Best-effort on reconnect. Surface via error only if user-triggered.
    }
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
