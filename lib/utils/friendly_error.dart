/// Map raw exceptions / error strings to short user-facing copy.
///
/// The daemon and the Dart networking stack throw a mix of `SocketException`,
/// `TimeoutException`, and bare `Exception('HTTP 401')` strings. None of them
/// are something a non-technical user should ever see — but we still want to
/// preserve the original `toString()` somewhere a curious user can drill into
/// (the connection-error dialog opened from `_ErrorBanner`).
///
/// Pass anything; this never throws. The output is a single short sentence,
/// no trailing punctuation, suitable for SnackBars, `errorText`, and inline
/// banner copy.
String friendlyError(Object? e) {
  if (e == null) return 'Something went wrong';
  final raw = e.toString();

  // Network reach errors — most common during first-time setup and when
  // Proton VPN is blocking LAN. See [[project-grod-remote-gotchas]].
  if (raw.contains('Connection refused') ||
      raw.contains('SocketException') ||
      raw.contains('Network is unreachable') ||
      raw.contains('No route to host')) {
    return 'Cannot reach server';
  }

  // Auth — daemon rejects when PIN is wrong or missing.
  if (raw.contains('401') || raw.contains('Unauthorized')) {
    return 'Wrong PIN';
  }
  if (raw.contains('403') || raw.contains('Forbidden')) {
    return 'Server refused the request';
  }

  // Slow LAN / sleeping daemon.
  if (raw.contains('TimeoutException') || raw.contains('timed out')) {
    return 'Connection timed out';
  }

  // Daemon couldn't parse what we sent — usually a malformed URL the user
  // pasted into the cast sheet or Piped instance field.
  if (raw.contains('400') || raw.contains('Bad Request')) {
    return 'Server rejected the request — check the URL';
  }

  // Daemon-side 5xx — Piped instance flapping, ffmpeg crash, etc. Worth
  // calling out so the user can try a different Piped instance.
  if (raw.contains('502') || raw.contains('503') || raw.contains('504')) {
    return 'Server is unavailable — try again or pick a different Piped instance';
  }
  if (raw.contains('500')) {
    return 'Server hit an error';
  }

  // Fall back to the daemon's own JSON `error` field (`grod_api._check`
  // surfaces it as `Exception(msg)`), stripping the `XxxException:` prefix.
  return raw.replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
}
