import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class GrodApi {
  final String baseUrl;
  final String pin;

  GrodApi(String host, int port, {this.pin = ''}) : baseUrl = 'http://$host:$port';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (pin.isNotEmpty) 'X-Grod-Pin': pin,
  };

  Future<Status> status() async {
    final res = await http.get(Uri.parse('$baseUrl/status'), headers: _headers);
    _check(res);
    return Status.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<SearchResult>> search(String query) async {
    final uri = Uri.parse('$baseUrl/search').replace(queryParameters: {'q': query});
    final res = await http.get(uri, headers: _headers);
    _check(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => SearchResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cast(String url) => _post('/cast', {'url': url});
  Future<void> queue(String url) => _post('/queue', {'url': url});
  Future<void> skip() => _post('/skip', {});
  Future<void> playPause() => _post('/play-pause', {});
  Future<void> volumeUp() => _post('/volume-up', {});
  Future<void> volumeDown() => _post('/volume-down', {});
  Future<void> mute() => _post('/mute', {});
  Future<void> unmute() => _post('/unmute', {});
  Future<void> forward([int seconds = 10]) => _post('/forward', {'seconds': seconds});
  Future<void> back([int seconds = 10]) => _post('/back', {'seconds': seconds});
  Future<void> removeFromQueue(int pos) async {
    final res = await http.delete(Uri.parse('$baseUrl/queue/$pos'), headers: _headers);
    _check(res);
  }
  Future<void> clearQueue() async {
    final res = await http.delete(Uri.parse('$baseUrl/queue'), headers: _headers);
    _check(res);
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _check(res);
  }

  void _check(http.Response res) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'HTTP ${res.statusCode}');
    }
  }
}
