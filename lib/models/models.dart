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

enum DeviceState { playing, paused, idle }

class Status {
  final DeviceState state;
  final QueueEntry? nowPlaying;
  final List<QueueEntryWithPos> queue;
  final bool daemon;

  const Status({
    required this.state,
    required this.nowPlaying,
    required this.queue,
    required this.daemon,
  });

  factory Status.fromJson(Map<String, dynamic> j) => Status(
        state: switch (j['state'] as String) {
          'playing' => DeviceState.playing,
          'paused' => DeviceState.paused,
          _ => DeviceState.idle,
        },
        nowPlaying: j['now_playing'] != null
            ? QueueEntry.fromJson(j['now_playing'] as Map<String, dynamic>)
            : null,
        queue: (j['queue'] as List<dynamic>)
            .map((e) => QueueEntryWithPos.fromJson(e as Map<String, dynamic>))
            .toList(),
        daemon: j['daemon'] as bool,
      );
}

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
        url: j['url'] as String,
        title: j['title'] as String,
        uploader: j['uploader'] as String,
        duration: j['duration'] as int,
        thumbnail: j['thumbnail'] as String,
      );

  String get durationFormatted {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
