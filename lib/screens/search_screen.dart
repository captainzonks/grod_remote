import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../utils/friendly_error.dart';

const _historyKey = 'search_history';
const _historyMax = 20;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = SearchController();
  List<SearchResult> _results = [];
  List<String> _history = [];
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList(_historyKey) ?? [];
    });
  }

  Future<void> _saveToHistory(String q) async {
    final updated = [q, ..._history.where((e) => e != q)].take(_historyMax).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, updated);
    setState(() => _history = updated);
  }

  Future<void> _removeFromHistory(String q) async {
    final updated = _history.where((e) => e != q).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, updated);
    setState(() => _history = updated);
    _refreshSuggestions();
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    setState(() => _history = []);
    _refreshSuggestions();
  }

  void _refreshSuggestions() {
    final text = _ctrl.text;
    _ctrl.text = '$text ';
    _ctrl.text = text;
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.isEmpty) return;
    final api = context.read<AppState>().api;
    if (api == null) return;
    _ctrl.closeView(q);
    await _saveToHistory(q);
    if (!mounted) return;
    setState(() { _searching = true; _error = null; _results = []; });
    try {
      final results = await api.search(q).timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addToQueue(SearchResult r) async {
    final state = context.read<AppState>();
    await state.act((api) => api.queue(r.url));
    if (!mounted) return;
    final err = state.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err == null
            ? 'Queued: ${r.title}'
            : 'Could not queue — ${friendlyError(err)}'),
      ),
    );
  }

  Future<void> _castNow(SearchResult r) async {
    final state = context.read<AppState>();
    // "Cast now" should interrupt current playback, not queue behind it.
    await state.act((api) => api.cast(r.url, force: true));
    if (!mounted) return;
    final err = state.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err == null
            ? 'Casting: ${r.title}'
            : 'Could not cast — ${friendlyError(err)}'),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SearchAnchor(
              searchController: _ctrl,
              viewOnSubmitted: (q) => _search(q),
              viewTrailing: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_ctrl.text),
                ),
              ],
              builder: (ctx, controller) => SearchBar(
                controller: controller,
                hintText: 'Search YouTube...',
                leading: const Icon(Icons.search),
                onTap: controller.openView,
                onChanged: (_) => controller.openView(),
                trailing: [
                  if (_ctrl.text.isNotEmpty || _results.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() { _results = []; _error = null; });
                      },
                    ),
                ],
              ),
              suggestionsBuilder: (ctx, controller) {
                final input = controller.text.trim();
                final filtered = input.isEmpty
                    ? _history
                    : _history.where((h) => h.toLowerCase().contains(input.toLowerCase())).toList();
                return [
                  if (filtered.isNotEmpty && input.isEmpty)
                    ListTile(
                      dense: true,
                      title: Text('Recent searches',
                          style: TextStyle(color: Theme.of(ctx).colorScheme.outline, fontSize: 12)),
                      trailing: TextButton(
                        onPressed: _clearHistory,
                        child: const Text('Clear all'),
                      ),
                    ),
                  ...filtered.map((h) => ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(h),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeFromHistory(h),
                    ),
                    onTap: () => _search(h),
                  )),
                ];
              },
            ),
          ),
          if (_searching) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (ctx, i) {
                final r = _results[i];
                return ListTile(
                  leading: r.thumbnail.isNotEmpty
                      ? Image.network(r.thumbnail, width: 80, fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => const Icon(Icons.video_library))
                      : const Icon(Icons.video_library),
                  title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${r.uploader} • ${r.durationFormatted}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline),
                        tooltip: 'Cast now',
                        onPressed: () => _castNow(r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_to_queue),
                        tooltip: 'Add to queue',
                        onPressed: () => _addToQueue(r),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
