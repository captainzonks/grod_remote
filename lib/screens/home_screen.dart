import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('grod remote'),
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
                ],
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

class _NowPlayingCard extends StatelessWidget {
  final AppState state;
  const _NowPlayingCard({required this.state});

  @override
  Widget build(BuildContext context) {
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

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
