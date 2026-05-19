class QueueEntry {
  final String id;
  final String title;

  const QueueEntry({required this.id, required this.title});

  factory QueueEntry.fromJson(Map<String, dynamic> j) =>
      QueueEntry(id: j['id'] as String, title: j['title'] as String);
}

class QueueEntryWithPos {
  final int pos;
  final String id;
  final String title;

  const QueueEntryWithPos({required this.pos, required this.id, required this.title});

  factory QueueEntryWithPos.fromJson(Map<String, dynamic> j) => QueueEntryWithPos(
        pos: j['pos'] as int,
        id: j['id'] as String,
        title: j['title'] as String,
      );
}

enum DeviceState { playing, paused, buffering, idle }

class Status {
  final DeviceState state;
  final QueueEntry? nowPlaying;
  final List<QueueEntryWithPos> queue;
  final bool daemon;
  final String quality;
  /// Current playback position in seconds. Null when no media is playing
  /// or duration is unknown.
  final int? position;
  /// Total media duration in seconds. Null in the same cases as [position].
  final int? duration;

  const Status({
    required this.state,
    required this.nowPlaying,
    required this.queue,
    required this.daemon,
    required this.quality,
    this.position,
    this.duration,
  });

  factory Status.fromJson(Map<String, dynamic> j) => Status(
        state: switch (j['state'] as String) {
          'playing' => DeviceState.playing,
          'paused' => DeviceState.paused,
          'buffering' => DeviceState.buffering,
          _ => DeviceState.idle,
        },
        nowPlaying: j['now_playing'] != null
            ? QueueEntry.fromJson(j['now_playing'] as Map<String, dynamic>)
            : null,
        queue: (j['queue'] as List<dynamic>)
            .map((e) => QueueEntryWithPos.fromJson(e as Map<String, dynamic>))
            .toList(),
        daemon: j['daemon'] as bool,
        quality: (j['quality'] as String?) ?? 'best',
        position: (j['position'] as num?)?.toInt(),
        duration: (j['duration'] as num?)?.toInt(),
      );
}

/// Format an integer number of seconds as `M:SS` or `H:MM:SS` for display.
String formatSeconds(int s) {
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final ss = sec.toString().padLeft(2, '0');
  if (h > 0) {
    final mm = m.toString().padLeft(2, '0');
    return '$h:$mm:$ss';
  }
  return '$m:$ss';
}

/// Allowed cast quality values. Order is display order in dropdowns.
const List<String> kQualityOptions = ['best', '1080p', '720p', '480p', '360p'];

class SearchResult {
  final String url;
  final String title;
  final String uploader;
  final int duration;
  final String thumbnail;

  const SearchResult({
    required this.url,
    required this.title,
    required this.uploader,
    required this.duration,
    required this.thumbnail,
  });

  factory SearchResult.fromJson(Map<String, dynamic> j) => SearchResult(
        url: (j['url'] as String?) ?? '',
        title: (j['title'] as String?) ?? '(no title)',
        uploader: (j['uploader'] as String?) ?? '',
        duration: (j['duration'] as int?) ?? 0,
        thumbnail: (j['thumbnail'] as String?) ?? '',
      );

  String get durationFormatted {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
