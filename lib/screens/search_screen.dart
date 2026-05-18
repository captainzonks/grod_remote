import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/app_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<SearchResult> _results = [];
  bool _searching = false;
  String? _error;

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    final api = context.read<AppState>().api;
    if (api == null) return;
    setState(() { _searching = true; _error = null; });
    try {
      final results = await api.search(q);
      setState(() { _results = results; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _searching = false; });
    }
  }

  Future<void> _addToQueue(SearchResult r) async {
    await context.read<AppState>().act((api) => api.queue(r.url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Queued: ${r.title}')),
      );
    }
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
            child: SearchBar(
              controller: _ctrl,
              hintText: 'Search YouTube...',
              trailing: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ],
              onSubmitted: (_) => _search(),
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
                  trailing: IconButton(
                    icon: const Icon(Icons.add_to_queue),
                    onPressed: () => _addToQueue(r),
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
