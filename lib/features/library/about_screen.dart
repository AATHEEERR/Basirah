import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/config.dart';
import '../../core/kb_provider.dart';
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
                      'فتعتذر عنها بوضوح. وإن كان سؤالك عن حكم شيء في الإسلام — مثل «هل السوشي حلال؟» — فهو داخل النطاق.',
                  'Basirah only answers questions about Islam. General questions (food, news, technology) or questions about the teachings '
                      'of other religions are politely declined. If you are asking what Islam says about something — e.g. “Is sushi halal?” — '
                      'it is in scope.',
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
                  'لا تسجيل دخول ولا حسابات. لا يحفظ خادم بصيرة نص أسئلتك، ويسجّل فقط بيانات تشغيلية عامة (نوع الإجابة ومستواها وزمنها). '
                      'لتوليد الإجابة الحية يُرسَل السؤال إلى مزوّد نموذج الذكاء الاصطناعي (Google Gemini أو Anthropic Claude) وفق شروطه؛ '
                      'وفي الفئة المجانية من Gemini قد تستخدم Google المحتوى لتحسين منتجاتها. '
                      'المحفوظات تبقى على جهازك وحدك. لا تكتب بيانات شخصية في سؤالك.',
                  'No sign-in and no accounts. The Basirah server does not store the text of your questions; it only logs general '
                      'operational data (answer type, level and time). To produce a live answer, the question is sent to the AI model '
                      'provider (Google Gemini or Anthropic Claude) under its terms; on the Gemini free tier, Google may use the content '
                      'to improve its products. Saved answers stay on your device. Do not write personal data in your question.',
                ),
              ),
              _Block(
                title: context.tr('معلومات تقنية', 'Technical information'),
                body: en
                    ? 'Version ${AppConfig.version} · knowledge base ${kb.version} (${kb.entries.length} questions, ${kb.evidence.length} texts)\n'
                          'Connection: ${AppConfig.hasApi ? 'Basirah server (AI model restricted to the references)' : 'local references on the device'}'
                    : 'الإصدار ${AppConfig.version} · قاعدة المعرفة ${kb.version} (${kb.entries.length} سؤالاً، ${kb.evidence.length} دليلاً)\n'
                          'وضع الاتصال: ${AppConfig.hasApi ? 'متصل بخادم بصيرة (نموذج ذكاء اصطناعي مقيّد بالمراجع)' : 'المراجع المحلية على الجهاز'}',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.body});

  final String title;
  final String body;

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
      ],
    ),
  );
}
