import 'dart:convert';

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/lang.dart';

/// One player for the whole app: starting a verse stops any other.
final recitationPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// What is loaded in the player (a verse key, or «teacher:60»).
final nowPlayingProvider = StateProvider<String?>((ref) => null);

/// The chosen reciter (the MCP server's reciter name) for this session.
final reciterProvider = StateProvider<String>((ref) => 'husary');

/// Reciters offered by the server (id, Arabic, English).
final recitersProvider = StateProvider<List<(String, String, String)>>((ref) => const [
  ('husary', 'محمود خليل الحصري', 'Mahmoud Khalil Al-Husary'),
]);

/// Listen to a verse: one MP3 per verse from the association's MCP server
/// (`get_quran_audio`), real reciters only — never a synthetic voice — with
/// repeat and a slower speed for learning to pronounce, and «المصحف
/// المعلّم» (the teaching recitation) for the whole surah from المكتبة
/// الصوتية للقرآن الكريم (mp3quran.net).
class RecitationBar extends ConsumerStatefulWidget {
  const RecitationBar({super.key, required this.evidence});

  final Evidence evidence;

  @override
  ConsumerState<RecitationBar> createState() => _RecitationBarState();
}

class _RecitationBarState extends ConsumerState<RecitationBar> {
  bool _loading = false;
  bool _repeat = false;
  bool _slow = false;
  String? _teacherUrl;
  String? _error;

  /// «8» or «1–4» → first and last verse.
  (int, int) get _range {
    final parts = (widget.evidence.ayah ?? '').split(RegExp('[–-]')).map((s) => int.tryParse(s.trim())).toList();
    final first = parts.first ?? 1;
    return (first, parts.length > 1 ? (parts.last ?? first) : first);
  }

  String get _key => '${widget.evidence.surah}:${_range.$1}-${_range.$2}';

  Future<Map<String, dynamic>> _fetch(int first, int last, String reciter) async {
    final res = await http
        .get(Uri.parse('${AppConfig.apiBase}/api/recitation?key=${widget.evidence.surah}:$first&to=$last&reciter=$reciter'))
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) throw http.ClientException('HTTP ${res.statusCode}');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> _play() async {
    final player = ref.read(recitationPlayerProvider);
    final playing = ref.read(nowPlayingProvider);
    if (playing == _key && player.playing) {
      await player.pause();
      setState(() {});
      return;
    }
    final failed = context.tr('تعذّر تحميل التلاوة الآن', 'The recitation could not be loaded right now');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (first, last) = _range;
      final a = await _fetch(first, last, ref.read(reciterProvider));
      ref.read(recitersProvider.notifier).state = [
        for (final r in (a['reciters'] as List).cast<Map<String, dynamic>>())
          (r['id'] as String, r['ar'] as String, r['en'] as String),
      ];
      _teacherUrl = a['teacherUrl'] as String?;
      await player.stop();
      // One small file per verse, played in order.
      await player.setAudioSources([
        for (final v in (a['verses'] as List).cast<Map<String, dynamic>>()) AudioSource.uri(Uri.parse(v['url'] as String)),
      ]);
      await player.setSpeed(_slow ? .75 : 1);
      await player.setLoopMode(_repeat ? LoopMode.all : LoopMode.off);
      ref.read(nowPlayingProvider.notifier).state = _key;
      player.play();
    } on Exception {
      _error = failed;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _teacher() async {
    final url = _teacherUrl ?? 'https://cdn.mp3quran.net/audio/muhammad-minshawi/r3/${widget.evidence.surah.toString().padLeft(3, '0')}.mp3';
    final player = ref.read(recitationPlayerProvider);
    await player.stop();
    await player.setAudioSource(AudioSource.uri(Uri.parse(url)));
    await player.setSpeed(1);
    await player.setLoopMode(LoopMode.off);
    ref.read(nowPlayingProvider.notifier).state = 'teacher:${widget.evidence.surah}';
    player.play();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasApi || widget.evidence.surah == null) return const SizedBox.shrink();
    final player = ref.watch(recitationPlayerProvider);
    final mine = ref.watch(nowPlayingProvider) == _key;
    final teacherMine = ref.watch(nowPlayingProvider) == 'teacher:${widget.evidence.surah}';
    final read = ref.watch(reciterProvider);
    final names = ref.watch(recitersProvider);
    final name = names.where((r) => r.$1 == read).map((r) => context.tr(r.$2, r.$3)).firstOrNull ??
        context.tr('الحصري', 'Al-Husary');
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snap) {
        final playing = (mine || teacherMine) && (snap.data?.playing ?? false) &&
            snap.data?.processingState != ProcessingState.completed;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Pill(
                    icon: _loading
                        ? null
                        : (playing && mine ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    label: playing && mine
                        ? context.tr('إيقاف', 'Pause')
                        : context.tr('استمع للآية', 'Listen'),
                    strong: true,
                    onTap: _loading ? null : _play,
                  ),
                  PopupMenuButton<String>(
                    tooltip: context.tr('اختر القارئ', 'Choose the reciter'),
                    onSelected: (r) {
                      ref.read(reciterProvider.notifier).state = r;
                      ref.read(nowPlayingProvider.notifier).state = null;
                      player.stop();
                    },
                    itemBuilder: (_) => [
                      for (final r in names.length > 1 ? names : const [('husary', 'محمود خليل الحصري', 'Mahmoud Khalil Al-Husary')])
                        PopupMenuItem(value: r.$1, child: Text(context.tr(r.$2, r.$3))),
                    ],
                    child: _Pill(icon: Icons.person_outline_rounded, label: name),
                  ),
                  _Pill(
                    icon: Icons.repeat_rounded,
                    label: context.tr('تكرار', 'Repeat'),
                    selected: _repeat,
                    onTap: () {
                      setState(() => _repeat = !_repeat);
                      if (mine) player.setLoopMode(_repeat ? LoopMode.all : LoopMode.off);
                    },
                  ),
                  _Pill(
                    icon: Icons.slow_motion_video_rounded,
                    label: context.tr('أبطأ', 'Slower'),
                    selected: _slow,
                    onTap: () {
                      setState(() => _slow = !_slow);
                      if (mine) player.setSpeed(_slow ? .75 : 1);
                    },
                  ),
                  _Pill(
                    icon: teacherMine && playing ? Icons.pause_rounded : Icons.school_outlined,
                    label: context.tr('المصحف المعلّم · السورة كاملة', 'Teaching recitation · whole surah'),
                    onTap: teacherMine && playing ? player.pause : _teacher,
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_error!, style: BText.label(12, color: BColors.textMuted)),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.tr(
                    'التلاوة آيةً آيةً عبر خادم جمعية خدمة المحتوى الإسلامي باللغات، والمصحف المعلّم من المكتبة الصوتية للقرآن الكريم',
                    'Verse-by-verse recitation via the Islamic Content Service Association; the teaching recitation from the Quran audio library (mp3quran.net)',
                  ),
                  style: BText.label(11, weight: FontWeight.w400),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.onTap, this.selected = false, this.strong = false});

  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final fill = strong ? BColors.goldDeep : (selected ? BColors.sand : Colors.white.withValues(alpha: .8));
    final ink = strong ? Colors.white : BColors.goldDeep;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: BColors.goldDeep.withValues(alpha: strong || selected ? .0 : .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == null)
            SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
          else
            Icon(icon, size: 16, color: ink),
          const SizedBox(width: 5),
          Text(label, style: BText.label(12, color: ink, weight: FontWeight.w600)),
        ],
      ),
    );
    return onTap == null ? body : InkWell(borderRadius: BorderRadius.circular(99), onTap: onTap, child: body);
  }
}
