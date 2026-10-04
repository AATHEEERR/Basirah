import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/state.dart';
import '../../shared/brand.dart';
import '../../shared/lang_toggle.dart';
import '../../shared/patterns.dart';
import '../../shared/widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // (tone, Arabic title, Arabic body, English title, English body)
  static const _promises = [
    (
      Tones.principle,
      'إجابات من مراجع معتمدة فقط',
      'القرآن والسنة الصحيحة والمصادر العلمية المعتمدة في التحدي، مع رابط للتحقق من كل دليل.',
      'Answers from approved references only',
      "The Quran, authentic Sunnah and the challenge's approved scholarly sources, with a link to verify every piece of evidence.",
    ),
    (
      Tones.culture,
      'نفرّق بين الدين والعادة',
      'ما يطلبه الإسلام شيء، وما اعتاده الناس في بلد ما شيء آخر.',
      'Religion is not the same as custom',
      'What Islam asks of you is one thing; what people are used to in a given country is another.',
    ),
    (
      Tones.khilaf,
      'نوضّح الخلاف ولا نرجّح',
      'في المسائل الاجتهادية نبيّن المتفق عليه ونترك الترجيح لأهل العلم.',
      'We explain differences, we do not choose',
      'On matters of ijtihad we show what is agreed and leave the choice between views to scholars.',
    ),
    (
      Tones.refer,
      'حالتك الشخصية لأهل العلم',
      'لا نُصدر فتوى في وقائع بعينها، بل نحيلك إلى المختص.',
      'Your personal case goes to scholars',
      'We do not issue fatwas on specific situations; we refer you to a specialist.',
    ),
    (
      Tones.offTopic,
      'أسئلة عن الإسلام فقط',
      'تجيب بصيرة عمّا يقوله الإسلام فقط، لا عن الوصفات أو الأخبار أو تعاليم الأديان الأخرى.',
      'Questions about Islam only',
      'Basirah only answers what Islam says, not recipes, news or the teachings of other religions.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const PatternBackdrop(height: 420),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                const Align(alignment: AlignmentDirectional.centerEnd, child: LangToggle(color: BColors.surface)),
                const Center(child: BrandLogo(size: 88, tile: true)),
                const SizedBox(height: 14),
                Center(child: Text(context.tr('بصيرة', 'Basirah'), style: BText.brand(context.isEn ? 38 : 44))),
                const SizedBox(height: 2),
                Text(
                  context.tr('رفيقك في أسئلة الإسلام الأولى', 'Your companion for your first questions about Islam'),
                  textAlign: TextAlign.center,
                  style: BText.title(17, color: BColors.textMuted, weight: FontWeight.w400),
                ),
                const SizedBox(height: 26),
                for (final (i, (tone, titleAr, bodyAr, titleEn, bodyEn)) in _promises.indexed)
                  Reveal(
                    delay: Duration(milliseconds: 150 + 110 * i),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [tone.top, tone.bottom]),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconBubble(icon: tone.icon, color: tone.accent, fill: Colors.white.withValues(alpha: .8), size: 42),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.tr(titleAr, titleEn), style: BText.title(15.5, color: tone.accent)),
                                const SizedBox(height: 2),
                                Text(context.tr(bodyAr, bodyEn), style: BText.body(13.5, color: BColors.ink, height: 1.65)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                SoftCard(
                  radius: 20,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_outlined, color: BColors.goldDeep, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr(
                            'بصيرة أداة ذكاء اصطناعي، وليست مفتياً ولا عالماً. لا نطلب تسجيل دخول، ولا يُحفظ نص أسئلتك على الخادم.',
                            'Basirah is an AI tool, not a mufti or a scholar. No sign-in, and the text of your questions is not stored on the server.',
                          ),
                          style: BText.body(13, color: BColors.textMuted, height: 1.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: context.tr('ابدأ', 'Start'),
                  icon: Icons.arrow_forward_rounded,
                  expand: true,
                  onTap: () async {
                    await Onboarding.markSeen();
                    if (context.mounted) context.go('/context?first=1');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
