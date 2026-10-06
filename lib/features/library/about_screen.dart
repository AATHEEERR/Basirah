import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/ask_service.dart';
import '../../core/lang.dart';
import '../../core/config.dart';
import '../../core/kb_provider.dart';
import '../../core/meaning.dart';
import '../../shared/brand.dart';
import '../../shared/widgets.dart';
import 'page_scaffold.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.tr('عن بصيرة', 'About Basirah'),
      child: KbBuilder(
        builder: (context, kb) {
          final verse = kb.evidence['q_12_108'];
          final en = context.isEn;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: BrandLogo(size: 92, tile: true)),
              const SizedBox(height: 12),
              Center(child: GoldText(context.tr('بصيرة', 'Basirah'), style: BText.display(40))),
              if (verse != null) ...[
                const SizedBox(height: 10),
                Text('﴿${verse.text}﴾', style: BText.quran(19), textAlign: TextAlign.center),
                Text('[${verse.reference}]', style: BText.label(12.5, color: BColors.gold), textAlign: TextAlign.center),
                if (en && verse.translation != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '“${verse.translation}”',
                    style: BText.body(13.5, color: BColors.textMuted, height: 1.6).copyWith(fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    verse.translationSource ?? '',
                    style: BText.label(11, color: BColors.textFaint, weight: FontWeight.w400),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
              const SizedBox(height: 18),
              _Block(
                title: context.tr('لماذا «بصيرة»؟', 'Why “Basirah”?'),
                body: context.tr(
                  'البصيرة هي العلم الواضح المبني على الدليل. وهذا وعدنا: أن تكون كل إجابة «على بصيرة» — من مرجع معتمد يمكنك التحقق منه، '
                      'وأن نقول «لا أعلم» حين لا نجد دليلاً، وأن نحيلك إلى أهل العلم حين يكون سؤالك عن حالتك الخاصة.',
                  'Basirah means clear knowledge built on evidence. That is our promise: every answer given “with clear insight” — from an '
                      'approved reference you can verify; saying “I don’t know” when we find no evidence; and referring you to scholars '
                      'when your question is about your own situation.',
                ),
              ),
              _Block(
                title: context.tr('لمن بصيرة؟', 'Who is Basirah for?'),
                body: context.tr(
                  'لكل من يسأل عن الإسلام، ومصمَّمة بعين المسلم في سنته الأولى: أسئلة الهوية والأسرة والعبادة والحياة اليومية والشبهات الشائعة، '
                      'مع التفريق الدائم بين ما يقرّره الدين وما هو عادة وثقافة.',
                  'Anyone asking about Islam — designed through the eyes of a Muslim in their first year: identity, family, worship, daily '
                      'life and common misconceptions, always separating what the religion establishes from what is custom and culture.',
                ),
              ),
              _Block(
                title: context.tr('نطاق الأسئلة', 'Scope'),
                body: context.tr(
                  'تجيب بصيرة عن الأسئلة المتعلقة بالإسلام فقط. أما الأسئلة العامة (كالطعام والأخبار والتقنية) أو عن تعاليم الأديان الأخرى '
                      'فتعتذر عنها بوضوح. وإن كان سؤالك عن حكم شيء في الإسلام فهو داخل النطاق.',
                  'Basirah only answers questions about Islam. General questions (food, news, technology) or questions about the teachings '
                      'of other religions are politely declined. If you are asking what Islam says about something, it is in scope.',
                ),
              ),
              _Block(
                title: context.tr('هدفنا', 'Our aim'),
                body: context.tr(
                  'أن يجد المسلم الجديد إجابة صحيحة وواضحة عن سؤاله في الإسلام، تناسب وضعه وخلفيته، ويستطيع أن يتتبعها بنفسه '
                      'إلى مصدر معتمد؛ وأن تمتنع بصيرة أو تحيله إلى مختص حين لا يكفي المرجع أو تكون المسألة حالة شخصية.',
                  'That a new Muslim finds a correct, clear answer to their question about Islam, suited to their situation and '
                      'background, which they can trace to an approved source themselves; and that Basirah declines or refers them to a '
                      'specialist when the reference is not enough or the matter is a personal case.',
                ),
              ),
              _Block(
                title: context.tr('كيف نتحقق من كل إجابة؟', 'How do we check every answer?'),
                body: context.tr(
                  'كل إجابة تمرّ بخطوات ثابتة: نعرف لغة سؤالك، وهل هو حالة شخصية تُحال إلى مختص شرعي. ثم يبحث النموذج في المصحف كاملاً، '
                      'ويقرأ تفسير الآية في الدرر السنية قبل أن يستشهد بها، ويبحث في موسوعة الأحاديث عن الصحيح والحسن، ويكتب الإجابة من هذه المصادر وحدها. '
                      'وقبل أن تظهر يفحصها حارس من الكود: نص الآية يُنسخ من المصحف لا من ذاكرة النموذج، ولا حديث بلا مصدره ودرجته. '
                      'وتصلك الإجابة بإيصال يبيّن ما فُحص فيها، ولكل دليل رابط تتحقق منه بنفسك.',
                  'Every answer goes through fixed steps: we detect your question’s language, and whether it is a personal case to refer to a Sharia specialist. '
                      'The model then searches the whole Mushaf, reads the verse’s tafsir on Dorar before citing it, searches the hadith encyclopedia for sahih and hasan hadith, and writes the answer from these sources only. '
                      'Before it is shown, a guard in code checks it: the verse text is copied from the Mushaf, not the model’s memory, and no hadith appears without its source and grading. '
                      'The answer comes with a receipt of what was checked, and every piece of evidence has a link to check it yourself.',
                ),
                links: [
                  (context.tr('المسار كاملاً بالرسم', 'The full path, drawn'), '/pipeline'),
                  (context.tr('المقارنة والدليل بالأرقام', 'The comparison, and the proof in numbers'), '/baseline'),
                ],
              ),
              _Block(
                title: context.tr('الشفافية', 'Transparency'),
                body: context.tr(
                  'بصيرة أداة مدعومة بالذكاء الاصطناعي، وليست مفتياً ولا عالماً. كل إجابة تبيّن مصدرها: قاعدة المعرفة الموثقة، '
                      'أو إجابة مولَّدة بالذكاء الاصطناعي مقيّدة بتلك القاعدة، أو وضع المراجع المحلية.',
                  'Basirah is an AI-powered tool, not a mufti or a scholar. Every answer shows where it comes from: the documented '
                      'knowledge base, a live AI answer restricted to the approved references, or the local references mode.',
                ),
              ),
              _Block(
                title: context.tr('الخصوصية', 'Privacy'),
                body: context.tr(
                  'لا تسجيل دخول ولا حسابات. لا يحفظ خادم بصيرة نص أسئلتك، ويسجّل فقط أعداداً عامة (نوع الإجابة ومستواها وزمنها) لـ«لوحة الأثر». '
                      'لتوليد الإجابة الحية يُرسَل السؤال إلى مزوّد النموذج: Anthropic (Claude)، ثم Google (Gemini) إن تعذّر الأول، وفق شروط كل منهما؛ '
                      'وفي الفئة المجانية من Gemini قد تستخدم Google المحتوى لتحسين منتجاتها. '
                      'وإذا طلبت التحدث مع مختص شرعي، لا يُرسَل إلا ما توافق عليه وتراه قبل الإرسال، ويُحذف من الخادم بعد 30 يوماً. '
                      'المحفوظات تبقى على جهازك وحدك. لا تكتب بيانات شخصية في سؤالك.',
                  'No sign-in and no accounts. The Basirah server does not store the text of your questions; it only keeps general '
                      'counts (answer type, level and time) for the impact board. To produce a live answer, the question is sent to the '
                      'model provider: Anthropic (Claude), then Google (Gemini) if the first is unavailable, under each one’s terms; on the '
                      'Gemini free tier, Google may use the content to improve its products. If you ask to talk to a specialist, only what '
                      'you approve, and see before sending, is sent, and it is deleted from the server after 30 days. Saved answers stay on '
                      'your device. Do not write personal data in your question.',
                ),
              ),
              _TechBlock(kb: kb),
            ],
          );
        },
      ),
    );
  }
}

/// «Claude Sonnet 5.5» from `claude-sonnet-5-5`, «Gemini 3.5 Flash» from
/// `gemini-3.5-flash`.
String modelName(String id) {
  final parts = id.split('-');
  final words = <String>[];
  final digits = <String>[];
  for (final p in parts) {
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(p)) {
      digits.add(p);
    } else {
      if (digits.isNotEmpty) {
        words.add(digits.join('.'));
        digits.clear();
      }
      words.add(p.isEmpty ? p : p[0].toUpperCase() + p.substring(1));
    }
  }
  if (digits.isNotEmpty) words.add(digits.join('.'));
  return words.join(' ');
}

/// «معلومات تقنية»: what is actually running, read from the server's
/// `/health` (models, verses) and from the app itself, so it always matches.
class _TechBlock extends ConsumerWidget {
  const _TechBlock({required this.kb});

  final KnowledgeBase kb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(serverStatusProvider).valueOrNull;
    final reviewed = kb.entries.where((e) => e.review == 'reviewed').length;
    // The version reads left to right inside Arabic text.
    String ltr(String s) => '${String.fromCharCode(0x2066)}$s${String.fromCharCode(0x2069)}';
    // Claude by name; the Gemini fallbacks as one last resort.
    final ids = server?.models ?? const <String>[];
    final models = [
      for (final m in ids)
        if (!m.startsWith('gemini')) modelName(m),
      if (ids.any((m) => m.startsWith('gemini'))) 'Gemini',
    ];
    final rows = [
      (context.tr('إصدار التطبيق', 'App version'), ltr(AppConfig.version)),
      (
        context.tr('قاعدة المعرفة', 'Knowledge base'),
        context.tr(
          'الإصدار ${ltr(kb.version)} · ${kb.entries.length} سؤالاً · ${kb.evidence.length} دليلاً · روجع بشرياً: $reviewed من ${kb.entries.length}',
          'version ${kb.version} · ${kb.entries.length} questions · ${kb.evidence.length} texts · human-reviewed: $reviewed of ${kb.entries.length}',
        ),
      ),
      if (server?.reachable ?? false) ...[
        (
          context.tr('نص المصحف', 'Mushaf text'),
          context.tr(
            '${server!.quranVerses} آية من موسوعة القرآن الكريم (مصحف مجمع الملك فهد)',
            '${server.quranVerses} verses from QuranEnc (the King Fahd Complex Mushaf)',
          ),
        ),
        if (models.isNotEmpty)
          (
            context.tr('نموذج الذكاء الاصطناعي', 'AI model'),
            models.length == 1
                ? ltr(models.first)
                : context.tr(
                    '${ltr(models.first)}، وعند تعذّره: ${models.skip(1).map(ltr).join(' ثم ')}',
                    '${models.first}; if unavailable: ${models.skip(1).join(', then ')}',
                  ),
          ),
        (
          context.tr('المصادر الحية', 'Live sources'),
          context.tr(
            'خادم MCP لجمعية خدمة المحتوى الإسلامي باللغات (موسوعة القرآن الكريم، وموسوعة الأحاديث النبوية، ودار الإسلام)، وموسوعة التفسير في الدرر السنية',
            'The MCP server of the association serving Islamic content in languages (QuranEnc, HadeethEnc, IslamHouse), and Dorar.net’s tafsir encyclopedia',
          ),
        ),
      ],
      (
        context.tr('معنى الآية بلغتك', 'Verse meaning in your language'),
        context.tr(
          '${meaningLanguages.length} لغة من ترجمات موسوعة القرآن الكريم المعتمدة، منها ${meaningLanguages.where((l) => l.$6).length} بصوت مسجَّل',
          '${meaningLanguages.length} languages from QuranEnc’s approved translations, ${meaningLanguages.where((l) => l.$6).length} with a recorded voice',
        ),
      ),
      (
        context.tr('لغات الواجهة', 'Interface languages'),
        context.tr(
          '${uiLanguages.length} لغة: العربية والإنجليزية كتبهما الفريق، والبقية مترجمة آلياً بـClaude ولم تُراجَع بشرياً بعد. الإجابات المراجَعة بالعربية والإنجليزية.',
          '${uiLanguages.length} languages: Arabic and English written by the team, the others machine-translated with Claude and not yet human-reviewed. The reviewed answers are in Arabic and English.',
        ),
      ),
      (
        context.tr('الاتصال', 'Connection'),
        !AppConfig.hasApi
            ? context.tr('المراجع المحلية على الجهاز', 'Local references on the device')
            : server == null
            ? '…'
            : server.reachable
            ? context.tr('متصل بخادم بصيرة', 'Connected to the Basirah server')
            : context.tr('الخادم غير متاح الآن: تُعرض الإجابات المحفوظة', 'Server unavailable: stored answers are shown'),
      ),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.tr('معلومات تقنية', 'Technical information'), style: BText.title(15.5, color: BColors.goldDeep)),
          const SizedBox(height: 8),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 132, child: Text(k, style: BText.label(13, color: BColors.ink, weight: FontWeight.w600))),
                  Expanded(child: Text(v, style: BText.body(13.5, color: BColors.textMuted, height: 1.6))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.body, this.links = const []});

  final String title;
  final String body;

  /// (label, route) of pages that say more.
  final List<(String, String)> links;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: BColors.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: BText.title(15.5, color: BColors.goldDeep)),
        const SizedBox(height: 6),
        Text(body, style: BText.body(14, color: BColors.textMuted)),
        if (links.isNotEmpty)
          Wrap(
            spacing: 4,
            children: [
              for (final (label, route) in links)
                TextButton.icon(
                  onPressed: () => context.push(route),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: BColors.goldDeep),
                  label: Text(label, style: BText.label(13, color: BColors.goldDeep, weight: FontWeight.w600)),
                ),
            ],
          ),
      ],
    ),
  );
}
