/// Sliding-window limiter per client key (IP). In-memory: fine for a single
/// demo instance; swap for a shared store if the API is scaled out.
class RateLimiter {
  RateLimiter({this.limit = 12, this.window = const Duration(minutes: 1)});

  final int limit;
  final Duration window;
  final _hits = <String, List<DateTime>>{};

  bool allow(String key) {
    final now = DateTime.now();
    final list = _hits.putIfAbsent(key, () => []);
    list.removeWhere((t) => now.difference(t) > window);
    if (list.length >= limit) return false;
    list.add(now);
    if (_hits.length > 10000) {
      _hits.removeWhere((_, v) => v.isEmpty || now.difference(v.last) > window);
    }
    return true;
  }
}
