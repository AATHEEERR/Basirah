import 'dart:convert';
import 'dart:math';

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/lang.dart';
import '../../shared/web_frame.dart';
import '../../shared/widgets.dart';
import '../library/page_scaffold.dart';
import '../specialist/specialist.dart';

/// «مرشد الحالة» trees (`assets/kb/guides.json`, written from الموسوعة
/// الفقهية by `server/tool/build_guides.dart`).
final guidesProvider = FutureProvider<List<Map<String, dynamic>>>((_) async {
  final j = jsonDecode(await rootBundle.loadString('assets/kb/guides.json')) as Map<String, dynamic>;
  return (j['guides'] as List).cast<Map<String, dynamic>>();
});

/// «مرشد الحالة»: a few yes-or-no questions about the asker's own case. Where
/// الموسوعة الفقهية reports consensus or agreement, the answer is given,
/// verbatim, with its link. Where it reports a difference, Basirah does not
/// choose: the asker gets a case file to send to a Sharia specialist.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  /// The answered steps: (node id, the chosen label).
  final _path = <(String, String)>[];
  String? _at;
  final _caseNo = 'BG-${(Random().nextInt(9000) + 1000)}';

  @override
  Widget build(BuildContext context) {
    final guides = ref.watch(guidesProvider).valueOrNull;
    final guide = guides?.where((g) => g['id'] == widget.id).firstOrNull;
    if (guide == null) {
      return const PageScaffold(title: '', child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())));
    }
    final nodes = (guide['nodes'] as Map).cast<String, dynamic>();
    final at = _at ?? guide['start'] as String;
    final node = (nodes[at] as Map).cast<String, dynamic>();
    final isLeaf = node.containsKey('kind');

    void choose(String label, String to) => setState(() {
      _path.add((at, label));
      _at = to;
    });

    void backTo(int i) => setState(() {
      _at = _path[i].$1;
      _path.removeRange(i, _path.length);
    });

    return PageScaffold(
      title: context.tr(guide['title'] as String, guide['titleEn'] as String),
      subtitle: context.tr(
        '${guide['subtitle']}. كل جواب منقول بنصه من الموسوعة الفقهية في الدرر السنية، وما فيه خلاف يصير ملفاً لحالتك تُرسله إلى مختص شرعي إن شئت.',
        '${guide['subtitleEn']}. Every answer is quoted from Dorar.net’s fiqh encyclopedia; where scholars differ, you get a case file to send to a Sharia specialist if you wish.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The path so far: tap a step to change its answer.
          for (final (i, (id, label)) in _path.indexed)
            _Step(
              index: i + 1,
              question: context.tr(nodes[id]['q'] as String, nodes[id]['qEn'] as String),
              answer: label,
              onTap: () => backTo(i),
            ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(a), child: child),
            ),
            child: isLeaf
                ? _Leaf(
                    key: ValueKey(at),
                    guide: guide,
                    node: node,
                    path: [for (final (id, label) in _path) (context.tr(nodes[id]['q'] as String, nodes[id]['qEn'] as String), label)],
                    caseNo: _caseNo,
                    onRestart: () => setState(() {
                      _path.clear();
                      _at = null;
                    }),
                  )
                : _Question(
                    key: ValueKey(at),
                    step: _path.length + 1,
                    text: context.tr(node['q'] as String, node['qEn'] as String),
                    choices: node['options'] == null
                        ? [
                            (context.tr('نعم', 'Yes'), node['yes'] as String, Icons.check_rounded),
                            (context.tr('لا', 'No'), node['no'] as String, Icons.close_rounded),
                          ]
                        : [
                            for (final o in (node['options'] as List).cast<Map<String, dynamic>>())
                              (context.tr(o['label'] as String, o['labelEn'] as String), o['to'] as String, Icons.arrow_back_rounded),
                          ],
                    onChoose: choose,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.question, required this.answer, required this.onTap});

  final int index;
  final String question;
  final String answer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: BColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Tones.guidance.accent, shape: BoxShape.circle),
                child: Text('$index', style: BText.label(11.5, color: Colors.white, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(question, style: BText.body(13.5, color: BColors.textMuted, height: 1.4))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Tones.guidance.top, borderRadius: BorderRadius.circular(99)),
                child: Text(answer, style: BText.label(12.5, color: Tones.guidance.accent, weight: FontWeight.w700)),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: context.tr('غيّر الإجابة', 'Change the answer'),
                child: const Icon(Icons.edit_outlined, size: 16, color: BColors.textFaint),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Question extends StatelessWidget {
  const _Question({super.key, required this.step, required this.text, required this.choices, required this.onChoose});

  final int step;
  final String text;
  final List<(String, String, IconData)> choices;
  final void Function(String label, String to) onChoose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [Tones.principle.top, Tones.principle.bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.tr('السؤال $step', 'Question $step'), style: BText.label(12.5, color: Tones.principle.accent, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(text, style: BText.display(isWebsite(context) ? 24 : 20, weight: FontWeight.w600)),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (label, to, icon) in choices)
              FilledButton.icon(
                onPressed: () => onChoose(label, to),
                style: FilledButton.styleFrom(
                  backgroundColor: BColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
                icon: Icon(icon, size: 18),
                label: Text(label, style: BText.title(15, color: Colors.white)),
              ),
          ],
        ),
      ],
    ),
  );
}

/// The end of a path: the answer (clear), the difference and the case file
/// (khilaf), or nothing found (none).
class _Leaf extends StatelessWidget {
  const _Leaf({super.key, required this.guide, required this.node, required this.path, required this.caseNo, required this.onRestart});

  final Map<String, dynamic> guide;
  final Map<String, dynamic> node;
  final List<(String, String)> path;
  final String caseNo;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final kind = node['kind'] as String;
    final tone = switch (kind) {
      'clear' => Tones.guidance,
      'khilaf' => Tones.khilaf,
      _ => Tones.abstain,
    };
    final title = switch (kind) {
      'clear' => context.tr('الجواب واضح من المصادر', 'The sources give a clear answer'),
      'khilaf' => context.tr('في المسألة خلاف بين أهل العلم', 'Scholars differ on this'),
      _ => context.tr('لم يتبيّن سبب مما سألناك عنه', 'None of the causes we asked about applies'),
    };
    final source = context.tr(
      'الموسوعة الفقهية — الدرر السنية: ${node['source']}',
      'Dorar.net fiqh encyclopedia: ${node['source']}',
    );
    final caseFile = _caseFile(context);
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [tone.top, tone.bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconBubble(icon: tone.icon, color: tone.accent, fill: Colors.white.withValues(alpha: .8), size: 36),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, style: BText.title(17, color: tone.accent))),
                ],
              ),
              const SizedBox(height: 12),
              if (kind == 'none')
                Text(
                  context.tr(
                    'لم يتبيّن من إجاباتك سبب من الأسباب التي سألناك عنها. للمسألة تفصيل أوسع في الموسوعة الفقهية، وإن بقي عندك شك فأرسل حالتك إلى مختص شرعي.',
                    'From your answers, none of the causes we asked about applies. The fiqh encyclopedia covers the matter in more detail; if you are still unsure, send your case to a Sharia specialist.',
                  ),
                  style: BText.body(15, height: 1.75),
                )
              else ...[
                if (context.isEn)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(node['en'] as String, style: BText.body(15, height: 1.7)),
                  ),
                _Quote(text: node['answer'] as String, label: source),
                if (node['other'] case final String other) ...[
                  const SizedBox(height: 8),
                  _Quote(text: other, label: context.tr('ومن الموضع نفسه في الموسوعة', 'From the same entry')),
                ],
                if (node['more'] case final String more) ...[
                  const SizedBox(height: 8),
                  _Quote(text: more, label: context.tr('ومن الموضع نفسه في الموسوعة', 'From the same entry')),
                ],
                if (kind == 'khilaf') ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Icon(Icons.do_not_disturb_on_outlined, size: 16, color: tone.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr(
                              'بصيرة لا ترجّح بين الأقوال. القول في حالتك أنت لمختص شرعي، وملف حالتك جاهز له.',
                              'Basirah does not choose between the views. The ruling for your own case is for a Sharia specialist, and your case file is ready.',
                            ),
                            style: BText.label(12.5, color: tone.accent, weight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(node['url'] as String), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: Text(
                    context.tr('اقرأ المسألة بأدلتها في الموسوعة الفقهية', 'Read the matter with its evidence on Dorar.net'),
                    style: BText.label(12.5, color: BColors.goldDeep, weight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (kind != 'clear') ...[
          const SizedBox(height: 14),
          _CaseFile(
            caseNo: caseNo,
            path: path,
            point: kind == 'khilaf' ? [node['answer'], node['other']].whereType<String>().join(' ') : null,
            source: kind == 'none' ? null : source,
          ),
          const SizedBox(height: 10),
          if (AppConfig.hasApi)
            FilledButton.icon(
              onPressed: () => showSpecialistRequest(
                context,
                BasirahAnswer(
                  question: context.tr(guide['title'] as String, guide['titleEn'] as String),
                  kind: kind == 'khilaf' ? AnswerKind.khilaf : AnswerKind.refer,
                  level: kind == 'khilaf' ? ContentLevel.c : ContentLevel.d,
                  origin: AnswerOrigin.kb,
                ),
                caseFile: caseFile,
              ),
              style: FilledButton.styleFrom(backgroundColor: Tones.khilaf.accent, padding: const EdgeInsets.symmetric(vertical: 15)),
              icon: const Icon(Icons.support_agent_rounded, size: 20),
              label: Text(context.tr('أرسل ملف حالتك إلى مختص شرعي', 'Send your case file to a Sharia specialist'), style: BText.title(14.5, color: Colors.white)),
            ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SecondaryButton(label: context.tr('ابدأ من جديد', 'Start again'), icon: Icons.restart_alt_rounded, onTap: onRestart),
            SecondaryButton(
              label: kind == 'clear' ? context.tr('انسخ الجواب', 'Copy the answer') : context.tr('انسخ ملف الحالة', 'Copy the case file'),
              icon: Icons.copy_rounded,
              onTap: () {
                Clipboard.setData(ClipboardData(text: caseFile));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('نُسخ', 'Copied'))));
              },
            ),
            SecondaryButton(label: context.tr('اسأل بصيرة سؤالاً آخر', 'Ask Basirah something else'), icon: Icons.forum_outlined, onTap: () => context.go('/ask')),
          ],
        ),
      ],
    );
  }

  /// The case file as text: what the specialist receives.
  String _caseFile(BuildContext context) {
    final b = StringBuffer()
      ..writeln('${context.tr('ملف الحالة', 'Case file')} $caseNo · ${context.tr(guide['title'] as String, guide['titleEn'] as String)}')
      ..writeln();
    for (final (i, (q, a)) in path.indexed) {
      b.writeln('${i + 1}. $q — $a');
    }
    if (node['answer'] case final String answer) {
      b
        ..writeln()
        ..writeln('${context.tr('من الموسوعة الفقهية', 'From the fiqh encyclopedia')} (${node['url']}):')
        ..writeln(answer);
      if (node['other'] case final String other) b.writeln(other);
    }
    return b.toString().trim();
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.text, required this.label});

  final String text;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .82), borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 14, color: BColors.textMuted),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: BText.label(11.5, weight: FontWeight.w600))),
          ],
        ),
        const SizedBox(height: 4),
        SelectableText(text, textDirection: TextDirection.rtl, style: BText.body(15, height: 1.8)),
      ],
    ),
  );
}

/// «ملف حالتك»: the asker's answers and the matter, ready for a specialist.
class _CaseFile extends StatelessWidget {
  const _CaseFile({required this.caseNo, required this.path, this.point, this.source});

  final String caseNo;
  final List<(String, String)> path;
  final String? point;
  final String? source;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFDF7),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: BColors.gold.withValues(alpha: .55), width: 1.4),
      boxShadow: [BoxShadow(color: BColors.gold.withValues(alpha: .12), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -8)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_shared_rounded, color: BColors.goldDeep, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text(context.tr('ملف حالتك · $caseNo', 'Your case file · $caseNo'), style: BText.title(16, color: BColors.goldDeep))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Tones.khilaf.accent.withValues(alpha: .6)),
              ),
              child: Text(context.tr('جاهز للمختص', 'Ready for a specialist'), style: BText.label(11.5, color: Tones.khilaf.accent, weight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final (i, (q, a)) in path.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}.', style: BText.label(13, color: BColors.goldDeep, weight: FontWeight.w700)),
                const SizedBox(width: 6),
                Expanded(child: Text(q, style: BText.body(13.5, height: 1.5))),
                const SizedBox(width: 8),
                Text(a, style: BText.label(13, color: BColors.ink, weight: FontWeight.w700)),
              ],
            ),
          ),
        if (point != null) ...[
          const Divider(height: 18),
          Text(context.tr('موضع الخلاف', 'Where scholars differ'), style: BText.label(12, color: BColors.goldDeep, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(point!, style: BText.body(13, color: BColors.textMuted, height: 1.6), textDirection: TextDirection.rtl),
        ],
        if (source != null) ...[
          const SizedBox(height: 6),
          Text(source!, style: BText.label(11.5, weight: FontWeight.w400)),
        ],
        const SizedBox(height: 6),
        Text(
          context.tr(
            'يبقى الملف على جهازك، ولا يُرسل إلا إذا ضغطت «أرسل» ووافقت.',
            'The file stays on your device, and is sent only if you press “Send” and agree.',
          ),
          style: BText.label(11.5, weight: FontWeight.w400),
        ),
      ],
    ),
  );
}

/// The two guides as tiles (home page and library): title and a line.
class GuideTiles extends ConsumerWidget {
  const GuideTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guides = ref.watch(guidesProvider).valueOrNull ?? const [];
    if (guides.isEmpty) return const SizedBox.shrink();
    final wide = isWebsite(context);
    final tiles = [
      for (final (i, g) in guides.indexed)
        _GuideTile(
          title: context.tr(g['title'] as String, g['titleEn'] as String),
          subtitle: context.tr(g['subtitle'] as String, g['subtitleEn'] as String),
          icon: i == 0 ? Icons.shower_outlined : Icons.water_drop_outlined,
          tone: i == 0 ? Tones.evidence : Tones.guidance,
          onTap: () => context.push('/guide/${g['id']}'),
        ),
    ];
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, t) in tiles.indexed) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: t),
              ],
            ],
          )
        : Column(children: [for (final (i, t) in tiles.indexed) ...[if (i > 0) const SizedBox(height: 10), t]]);
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.title, required this.subtitle, required this.icon, required this.tone, required this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final Tone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [tone.top, tone.bottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              IconBubble(icon: icon, color: tone.accent, fill: Colors.white.withValues(alpha: .8), size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: BText.title(17)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: BText.label(12.5, weight: FontWeight.w400)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Chip(context.tr('نعم أو لا', 'Yes or no'), tone),
                        _Chip(context.tr('من الموسوعة الفقهية', 'From the fiqh encyclopedia'), tone),
                        _Chip(context.tr('الخلاف ← ملف للمختص', 'Difference → file for a specialist'), tone),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: tone.accent),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.tone);

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(99)),
    child: Text(text, style: BText.label(11.5, color: tone.accent, weight: FontWeight.w600)),
  );
}
