import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// A reciter of المكتبة الصوتية للقرآن الكريم (mp3quran.net — reference pack
/// p.12) whose surah recordings have per-verse timings.
class Reciter {
  const Reciter(this.read, this.ar, this.en, this.folder);

  /// mp3quran's timing id («read»).
  final int read;
  final String ar;
  final String en;
  final String folder;
}

/// The Hafs reciters offered in the app, all with per-verse timings.
const reciters = [
  Reciter(118, 'محمود خليل الحصري', 'Mahmoud Khalil Al-Husary', 'https://cdn.mp3quran.net/audio/mahmoud-husary/r1/'),
  Reciter(119, 'الحصري — المصحف المجوّد', 'Al-Husary — mujawwad', 'https://cdn.mp3quran.net/audio/mahmoud-husary/r2/'),
  Reciter(112, 'محمد صديق المنشاوي', 'Muhammad Siddiq Al-Minshawi', 'https://cdn.mp3quran.net/audio/muhammad-minshawi/r1/'),
  Reciter(123, 'مشاري العفاسي', 'Mishary Alafasy', 'https://cdn.mp3quran.net/audio/mishary-alafasy/r1/'),
  Reciter(74, 'علي بن عبدالرحمن الحذيفي', 'Ali Al-Hudhaifi', 'https://cdn.mp3quran.net/audio/ali-hudhaifi/r1/'),
  Reciter(54, 'عبدالرحمن السديس', 'Abdulrahman Al-Sudais', 'https://cdn.mp3quran.net/audio/abdulrahman-sudais/r1/'),
];

/// «المصحف المعلّم» (Al-Minshawi, with children repeating each verse after
/// him): whole surahs, for learning to pronounce.
const teacherFolder = 'https://cdn.mp3quran.net/audio/muhammad-minshawi/r3/';

/// One verse in a surah recording: play [url] from [startMs] to [endMs].
class VerseAudio {
  const VerseAudio({required this.url, required this.startMs, required this.endMs, required this.reciter});

  final String url;
  final int startMs;
  final int endMs;
  final Reciter reciter;

  Map<String, dynamic> toJson() => {
    'url': url,
    'start': startMs,
    'end': endMs,
    'reciter': {'read': reciter.read, 'ar': reciter.ar, 'en': reciter.en},
    'teacherUrl': '$teacherFolder${_three(_surahOf(url))}.mp3',
  };

  static int _surahOf(String url) => int.parse(RegExp(r'(\d{3})\.mp3$').firstMatch(url)![1]!);
}

String _three(int n) => n.toString().padLeft(3, '0');

/// Verse timings from mp3quran's ayat_timing API, cached on disk per surah
/// and reciter.
class RecitationSource {
  RecitationSource({http.Client? client, this.cacheDir = 'cache/ayat_timing'}) : _http = client ?? http.Client();

  final http.Client _http;
  final String cacheDir;
  final _memory = <String, List<Map<String, dynamic>>>{};

  Future<VerseAudio?> verse(int surah, int ayah, {int read = 118}) async {
    final reciter = reciters.where((r) => r.read == read).firstOrNull ?? reciters.first;
    final timings = await _timings(surah, reciter.read);
    final t = timings?.where((t) => t['ayah'] == ayah).firstOrNull;
    if (t == null) return null;
    return VerseAudio(
      url: '${reciter.folder}${_three(surah)}.mp3',
      startMs: (t['start_time'] as num).toInt(),
      endMs: (t['end_time'] as num).toInt(),
      reciter: reciter,
    );
  }

  Future<List<Map<String, dynamic>>?> _timings(int surah, int read) async {
    final key = '${read}_$surah';
    final hit = _memory[key];
    if (hit != null) return hit;
    final file = File('$cacheDir/$key.json');
    if (file.existsSync()) {
      return _memory[key] = (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>();
    }
    try {
      final res = await _http
          .get(Uri.parse('https://www.mp3quran.net/api/v3/ayat_timing?surah=$surah&read=$read'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final list = [
        for (final t in (jsonDecode(utf8.decode(res.bodyBytes)) as List).cast<Map<String, dynamic>>())
          {'ayah': t['ayah'], 'start_time': t['start_time'], 'end_time': t['end_time']},
      ];
      try {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(jsonEncode(list));
      } on FileSystemException {
        // Read-only filesystem: memory only.
      }
      return _memory[key] = list;
    } on Exception {
      return null;
    }
  }
}
