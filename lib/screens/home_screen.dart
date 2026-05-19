import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// Recognize the YouTube / Piped URL shapes the daemon already accepts.
/// Used to decide whether to auto-fill the cast-URL sheet from clipboard;
/// the server still does the authoritative parse via extract_video_id.
final _kYoutubeUrlPattern = RegExp(
  r'(youtube\.com/watch\?v=|youtu\.be/|piped\.[^/]+/watch\?v=|/watch\?v=)',
  caseSensitive: false,
);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Image.asset(
                'assets/grod_mascot.png',
                width: 32,
                height: 32,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const Text('Grod'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: !state.configured
          ? _notConfigured(context)
          : RefreshIndicator(
              onRefresh: state.refresh,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _NowPlayingCard(state: state),
                  const SizedBox(height: 12),
                  _PlaybackControls(state: state),
                  const SizedBox(height: 16),
                  _QueueList(state: state),
                  // Padding so FAB doesn't overlap the last queue item.
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: state.configured
          ? FloatingActionButton.extended(
              onPressed: () => _openCastUrlSheet(context),
              icon: const Icon(Icons.add_link),
              label: const Text('Cast URL'),
            )
          : null,
    );
  }

  void _openCastUrlSheet(BuildContext context) {
    final appState = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        // Lift the sheet above the keyboard when the URL field has focus.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ChangeNotifierProvider.value(
          value: appState,
          child: const _CastUrlSheet(),
        ),
      ),
    );
  }

  Widget _notConfigured(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No server configured'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              child: const Text('Configure server'),
            ),
          ],
        ),
      );
}

class _NowPlayingCard extends StatefulWidget {
  final AppState state;
  const _NowPlayingCard({required this.state});

  @override
  State<_NowPlayingCard> createState() => _NowPlayingCardState();
}

class _NowPlayingCardState extends State<_NowPlayingCard> {
  /// Position from the most recent status poll, in seconds.
  int? _basePosition;
  /// When the most recent status arrived. Used to extrapolate the live
  /// position between polls so the progress bar animates smoothly instead
  /// of stepping every 3s.
  DateTime? _baseAt;
  /// State at the last poll — interpolation only runs while playing.
  DeviceState? _baseState;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _sync();
    // 250ms is fast enough that the bar moves visibly without burning CPU.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(_NowPlayingCard old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Capture the latest poll values as the extrapolation baseline. Only
  /// resets the baseline when the position from the server actually changed
  /// — otherwise every parent rebuild would reset _baseAt and freeze the bar.
  void _sync() {
    final s = widget.state.status;
    if (s == null) return;
    final pos = s.position;
    if (pos == null) {
      _basePosition = null;
      _baseAt = null;
      _baseState = null;
      return;
    }
    if (pos != _basePosition || s.state != _baseState) {
      _basePosition = pos;
      _baseAt = DateTime.now();
      _baseState = s.state;
    }
  }

  /// Position-to-display = server position + seconds elapsed since the poll
  /// landed (only while playing — paused/buffering hold the bar still).
  int? _livePosition(int? duration) {
    final base = _basePosition;
    final at = _baseAt;
    if (base == null || at == null) return null;
    if (_baseState != DeviceState.playing) return base;
    final elapsed = DateTime.now().difference(at).inMilliseconds / 1000.0;
    final live = (base + elapsed).round();
    if (duration != null && duration > 0 && live > duration) return duration;
    return live;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final status = state.status;
    final cs = Theme.of(context).colorScheme;

    final (icon, color, label) = switch (status?.state) {
      DeviceState.playing => (Icons.play_arrow, cs.primary, 'Playing'),
      DeviceState.paused => (Icons.pause, cs.secondary, 'Paused'),
      DeviceState.buffering => (Icons.hourglass_top, cs.tertiary, 'Buffering'),
      _ => (Icons.tv_off, cs.outline, 'Idle'),
    };

    final title = status?.nowPlaying?.title ?? (status?.state != DeviceState.idle ? 'Cast outside grod' : 'Nothing playing');
    final quality = status?.quality;

    final duration = status?.duration;
    final position = _livePosition(duration);
    final showProgress = position != null && duration != null && duration > 0;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                              if (quality != null) ...[
                                const SizedBox(width: 8),
                                _QualityBadge(quality: quality),
                              ],
                            ],
                          ),
                          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (state.error != null)
                      Icon(Icons.wifi_off, color: cs.error),
                  ],
                ),
                if (showProgress) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (position / duration).clamp(0.0, 1.0),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatSeconds(position),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        formatSeconds(duration),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (state.error != null) _ErrorBanner(error: state.error!),
      ],
    );
  }
}

class _QualityBadge extends StatelessWidget {
  final String quality;
  const _QualityBadge({required this.quality});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        quality,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner({required this.error});

  String get _short {
    if (error.contains('Connection refused') || error.contains('SocketException')) {
      return 'Cannot reach server';
    }
    if (error.contains('401') || error.contains('Unauthorized')) {
      return 'Wrong PIN';
    }
    if (error.contains('TimeoutException') || error.contains('timed out')) {
      return 'Connection timed out';
    }
    // Strip "Exception:" prefix noise
    return error.replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showFullError(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.wifi_off, size: 16, color: cs.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _short,
                    style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.info_outline, size: 16, color: cs.onErrorContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullError(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Connection error'),
        content: SingleChildScrollView(child: Text(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

class _PlaybackControls extends StatelessWidget {
  final AppState state;
  const _PlaybackControls({required this.state});

  void _act(BuildContext ctx, Future<void> Function(dynamic) fn) =>
      ctx.read<AppState>().act(fn);

  @override
  Widget build(BuildContext context) {
    final isPlaying = state.status?.state == DeviceState.playing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  onPressed: () => _act(context, (a) => a.back()),
                ),
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 36),
                  onPressed: () => _act(context, (a) => a.playPause()),
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10),
                  onPressed: () => _act(context, (a) => a.forward()),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: () => _act(context, (a) => a.skip()),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_down),
                  onPressed: () => _act(context, (a) => a.volumeDown()),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_mute),
                  onPressed: () => _act(context, (a) => a.mute()),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => _act(context, (a) => a.volumeUp()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  final AppState state;
  const _QueueList({required this.state});

  @override
  Widget build(BuildContext context) {
    final queue = state.status?.queue ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Queue (${queue.length})', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (queue.isNotEmpty)
              TextButton(
                onPressed: () => context.read<AppState>().act((a) => a.clearQueue()),
                child: const Text('Clear'),
              ),
          ],
        ),
        if (queue.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Queue is empty')),
          )
        else
          ...queue.map(
            (e) => ListTile(
              leading: Text('${e.pos}', style: Theme.of(context).textTheme.bodySmall),
              title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => context.read<AppState>().act((a) => a.removeFromQueue(e.pos)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Bottom-sheet for casting/queueing a pasted YouTube URL.
class _CastUrlSheet extends StatefulWidget {
  const _CastUrlSheet();

  @override
  State<_CastUrlSheet> createState() => _CastUrlSheetState();
}

class _CastUrlSheetState extends State<_CastUrlSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;
  /// YouTube URL detected in the clipboard at sheet open. Shown as a
  /// dismissible chip the user can tap to populate the field. We don't
  /// auto-fill: pre-populating a stale URL from a previous session is more
  /// annoying than the one extra tap.
  String? _clipboardSuggestion;

  @override
  void initState() {
    super.initState();
    _detectClipboardSuggestion();
  }

  Future<void> _detectClipboardSuggestion() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || !_kYoutubeUrlPattern.hasMatch(text)) return;
    if (!mounted) return;
    setState(() => _clipboardSuggestion = text);
  }

  void _applyClipboardSuggestion() {
    final url = _clipboardSuggestion;
    if (url == null) return;
    setState(() {
      _ctrl.text = url;
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: url.length),
      );
      _clipboardSuggestion = null;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool castNow}) async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Paste a YouTube URL first');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<AppState>().api;
      if (api == null) throw Exception('Not connected');
      if (castNow) {
        // force=true so "Cast now" interrupts whatever's playing instead
        // of silently queueing behind it.
        await api.cast(url, force: true);
      } else {
        await api.queue(url);
      }
      if (!mounted) return;
      // Refresh now-playing/queue display immediately.
      context.read<AppState>().refresh();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(castNow ? 'Casting...' : 'Queued')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cast or queue URL',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'YouTube URL',
              hintText: 'https://youtu.be/...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
            onSubmitted: _busy ? null : (_) => _submit(castNow: true),
          ),
          if (_clipboardSuggestion != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.content_paste, size: 18),
                label: const Text('Use clipboard URL'),
                onPressed: _applyClipboardSuggestion,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _submit(castNow: false),
                  icon: const Icon(Icons.queue),
                  label: const Text('Queue'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _submit(castNow: true),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_circle_outline),
                  label: const Text('Cast now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
