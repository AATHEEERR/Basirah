import 'dart:convert';

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/lang.dart';
import '../../core/meaning.dart';

/// One player for the whole app: starting a verse stops any other.
final recitationPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// What is loaded in the player (a verse range key).
final nowPlayingProvider = StateProvider<String?>((ref) => null);

/// The chosen reciter (the MCP server's reciter name) for this session.
final reciterProvider = StateProvider<String>((ref) => 'husary');

/// Reciters offered by the server (id, Arabic, English).
final recitersProvider = StateProvider<List<(String, String, String)>>((ref) => const [
  ('husary', 'محمود خليل الحصري', 'Mahmoud Khalil Al-Husary'),
]);

/// Listen to a verse: one MP3 per verse from the association's MCP server
/// (`get_quran_audio`), real reciters only — never a synthetic voice — with
/// repeat and a slower speed for learning to pronounce. Only the cited
/// verses are played.
class RecitationBar extends ConsumerStatefulWidget {
  const RecitationBar({super.key, required this.evidence, this.answerLang});

  final Evidence evidence;

  /// The language the answer is written in: when it has an approved
  /// translation of the meanings (and is neither Arabic nor English), the
  /// meaning is heard and shown in it until the asker picks another.
  final String? answerLang;

  @override
  ConsumerState<RecitationBar> createState() => _RecitationBarState();
}

class _RecitationBarState extends ConsumerState<RecitationBar> {
  bool _loading = false;
  bool _repeat = false;
  bool _slow = false;
  String? _error;

  /// «اسمعها بلغتك»: the approved translation of this verse (range) in the
  /// chosen language, and which language it is for.
  Map<String, dynamic>? _meaning;
  String? _meaningFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMeaning(_chosen(ref.read(meaningLangProvider)));
    });
  }

  /// The asker's choice in this bar, else the answer's own language when it
  /// is neither Arabic nor English, else the page's language (English page:
  /// the English meaning; French page: the French one; Arabic page: the
  /// recitation alone).
  String? _chosen(String? picked) {
    if (picked != null) return picked;
    final answer = widget.answerLang == 'ar' || widget.answerLang == 'en' ? null : widget.answerLang;
    final page = context.getInheritedWidgetOfExactType<UiLangScope>()?.lang;
    for (final lang in [answer, page]) {
      if (lang == null || lang == 'ar') continue;
      final key = meaningLanguages.where((l) => l.$2 == lang).firstOrNull?.$1;
      if (key != null) return key;
    }
    return null;
  }

  Future<void> _loadMeaning(String? lang) async {
    if (lang == null) {
      if (mounted) setState(() => _meaning = _meaningFor = null);
      return;
    }
    if (_meaningFor == lang && _meaning != null) return;
    _meaningFor = lang;
    final (first, last) = _range;
    try {
      final res = await http
          .get(Uri.parse('${AppConfig.apiBase}/api/meaning?key=${widget.evidence.surah}:$first&to=$last&lang=$lang'))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200 || !mounted || _meaningFor != lang) return;
      setState(() => _meaning = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
    } on Exception {
      // The recitation still works without the meaning.
    }
  }

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
      await player.stop();
      final lang = _chosen(ref.read(meaningLangProvider));
      if (lang != null) await _loadMeaning(lang);
      final meaning = lang == null ? null : _meaning;
      // One small file per verse, played in order; then, when a language is
      // chosen, the approved meaning of each verse in that language.
      await player.setAudioSources([
        for (final v in (a['verses'] as List).cast<Map<String, dynamic>>()) AudioSource.uri(Uri.parse(v['url'] as String)),
        if (meaning != null)
          for (final v in (meaning['verses'] as List).cast<Map<String, dynamic>>())
            if (v['audio'] case final String audio) AudioSource.uri(Uri.parse(audio)),
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

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasApi || widget.evidence.surah == null) return const SizedBox.shrink();
    final player = ref.watch(recitationPlayerProvider);
    final mine = ref.watch(nowPlayingProvider) == _key;
    final read = ref.watch(reciterProvider);
    final names = ref.watch(recitersProvider);
    final name = names.where((r) => r.$1 == read).map((r) => context.tr(r.$2, r.$3)).firstOrNull ??
        context.tr('الحصري', 'Al-Husary');
    ref.listen<String?>(meaningLangProvider, (_, next) => _loadMeaning(_chosen(next)));
    final lang = meaningLanguages.where((l) => l.$1 == _chosen(ref.watch(meaningLangProvider))).firstOrNull;
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snap) {
        final playing = mine && (snap.data?.playing ?? false) &&
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
                        : lang == null || !lang.$6
                        ? context.tr('استمع للآية', 'Listen')
                        : context.tr('استمع للآية ثم معناها', 'Listen, then the meaning'),
                    strong: true,
                    onTap: _loading ? null : _play,
                  ),
                  PopupMenuButton<String>(
                    tooltip: context.tr('اسمع معنى الآية بلغتك', 'Hear the meaning in your language'),
                    onSelected: (k) {
                      ref.read(meaningLangProvider.notifier).set(k.isEmpty ? null : k);
                      ref.read(nowPlayingProvider.notifier).state = null;
                      player.stop();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: '', child: Text(context.tr('بدون ترجمة', 'No translation'))),
                      for (final l in meaningLanguages)
                        PopupMenuItem(
                          value: l.$1,
                          child: Text(
                            '${context.isEn ? l.$3 : '${l.$3} · ${l.$4}'}${l.$6 ? '' : context.tr(' · نص', ' · text')}',
                          ),
                        ),
                    ],
                    child: _Pill(
                      icon: Icons.translate_rounded,
                      label: lang == null ? context.tr('المعنى بلغتك', 'Meaning in your language') : lang.$3,
                      selected: lang != null,
                    ),
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
                    'التلاوة آيةً آيةً بأصوات القراء عبر خادم جمعية خدمة المحتوى الإسلامي باللغات',
                    'Verse-by-verse recitation by real reciters, via the Islamic Content Service Association',
                  ),
                  style: BText.label(11, weight: FontWeight.w400),
                ),
              ),
              if (lang != null && _meaning != null && _meaningFor == lang.$1) _MeaningBox(lang: lang, meaning: _meaning!),
            ],
          ),
        );
      },
    );
  }
}

/// The approved translation of the verse in the chosen language, its
/// source, and the IslamHouse library in that language.
class _MeaningBox extends StatelessWidget {
  const _MeaningBox({required this.lang, required this.meaning});

  final (String, String, String, String, bool, bool) lang;
  final Map<String, dynamic> meaning;

  @override
  Widget build(BuildContext context) {
    final verses = (meaning['verses'] as List).cast<Map<String, dynamic>>();
    final title = meaning['title'] as String?;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .85), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(
              'ترجمة معاني معتمدة · ${lang.$4} · موسوعة القرآن الكريم${lang.$6 ? '' : ' · نص فقط، بلا تسجيل صوتي'}',
              'Approved translation of the meanings · ${lang.$3} · QuranEnc${lang.$6 ? '' : ' · text only, no recording'}',
            ),
            style: BText.label(11.5, color: BColors.goldDeep, weight: FontWeight.w600),
          ),
          if (title != null) Text(title, style: BText.label(11, weight: FontWeight.w400), textDirection: TextDirection.ltr),
          const SizedBox(height: 6),
          for (final v in verses)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                verses.length > 1 ? '(${v['ayah']}) ${v['text']}' : v['text'] as String,
                textDirection: lang.$5 ? TextDirection.rtl : TextDirection.ltr,
                style: BText.body(14, height: 1.6),
              ),
            ),
          _LibraryItems(iso: lang.$2, rtl: lang.$5),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => launchUrl(Uri.parse('https://islamhouse.com/${lang.$2}/main/'), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.local_library_outlined, size: 16, color: BColors.goldDeep),
              label: Text(
                context.tr('تعلّم أكثر بلغتك: مكتبة دار الإسلام كاملة', 'Learn more in your language: the whole IslamHouse library'),
                style: BText.label(12.5, color: BColors.goldDeep, weight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The association's introductions to Islam on IslamHouse in a language
/// (`/api/islamhouse`, through its MCP server).
final _libraryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, iso) async {
  try {
    final res = await http.get(Uri.parse('${AppConfig.apiBase}/api/islamhouse?lang=$iso')).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return const [];
    return ((jsonDecode(utf8.decode(res.bodyBytes)) as Map)['items'] as List).cast<Map<String, dynamic>>();
  } on Exception {
    return const [];
  }
});

class _LibraryItems extends ConsumerWidget {
  const _LibraryItems({required this.iso, required this.rtl});

  final String iso;
  final bool rtl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_libraryProvider(iso)).valueOrNull ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      decoration: BoxDecoration(color: BColors.sand.withValues(alpha: .5), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(
              'من مكتبة دار الإسلام بلغتك: إصدارات الفريق العلمي لجمعية خدمة المحتوى الإسلامي باللغات',
              'From the IslamHouse library in your language: published by the scientific team of the association',
            ),
            style: BText.label(11.5, color: BColors.goldDeep, weight: FontWeight.w600),
          ),
          for (final i in items.take(3))
            InkWell(
              onTap: () => launchUrl(Uri.parse(i['url'] as String), mode: LaunchMode.externalApplication),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      switch (i['type']) {
                        'audios' => Icons.headphones_rounded,
                        'videos' => Icons.ondemand_video_rounded,
                        _ => Icons.menu_book_rounded,
                      },
                      size: 16,
                      color: BColors.goldDeep,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        i['title'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                        style: BText.body(13, height: 1.5).copyWith(decoration: TextDecoration.underline, decorationColor: BColors.goldDeep.withValues(alpha: .4)),
                      ),
                    ),
                    const Icon(Icons.open_in_new_rounded, size: 14, color: BColors.textFaint),
                  ],
                ),
              ),
            ),
        ],
      ),
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
