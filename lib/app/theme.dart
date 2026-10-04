import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Light, airy palette in the spirit of the Nusuk app: soft grey canvas,
/// white rounded cards, a warm sand glow at the top, ink-black primary
/// actions, amber-gold highlights and pastel accents.
abstract final class BColors {
  static const bg = Color(0xFFF2F2F4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFE8E8EB);
  static const stroke = Color(0x12000000);

  static const ink = Color(0xFF141416);
  static const onInk = Color(0xFFFFFFFF);
  static const text = ink;
  static const textMuted = Color(0xFF6C6C74);
  static const textFaint = Color(0xFFA2A2AA);

  static const sand = Color(0xFFEBDBB8);
  static const sandSoft = Color(0xFFF7EFDF);

  static const gold = Color(0xFFE6A935);
  static const goldDeep = Color(0xFFB57D1E);

  // Pastel bubbles
  static const mint = Color(0xFFE2F3E7);
  static const mintInk = Color(0xFF2E6B45);
  static const beige = Color(0xFFF7ECDA);
  static const beigeInk = Color(0xFFB27D2A);
  static const lilac = Color(0xFFEEE6FA);
  static const lilacInk = Color(0xFF7446C2);

  /// Gold for strokes and marks drawn on light backgrounds.
  static const goldGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFF2C85E), gold, Color(0xFFA9711A)],
  );

  /// Gold for marks drawn on the deep "photo" covers.
  static const goldOnDark = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFFFFF3C4), Color(0xFFF3D98B), Color(0xFFD4AF37), Color(0xFF9A7216)],
    stops: [0, .28, .62, 1],
  );
}

/// Typography: IBM Plex Sans Arabic throughout (large, regular-weight titles
/// as in Nusuk), Reem Kufi for the wordmark and website titles, the King
/// Fahd Complex's Hafs font for verses, and Amiri for hadith.
abstract final class BText {
  static TextStyle brand(double size, {Color? color}) =>
      GoogleFonts.reemKufi(fontSize: size, fontWeight: FontWeight.w700, color: color ?? BColors.ink, height: 1.2);

  static TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color ?? BColors.ink, height: 1.35);

  static TextStyle title(double size, {Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color ?? BColors.ink, height: 1.45);

  static TextStyle body(double size, {Color? color, FontWeight weight = FontWeight.w400, double height = 1.8}) =>
      GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color ?? BColors.ink, height: height);

  static TextStyle label(double size, {Color? color, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color ?? BColors.textMuted, height: 1.3);

  /// Verses in the King Fahd Complex's Hafs font (V30), which draws the
  /// Mushaf text's open tanween (U+0657, U+065E, U+0656 in the QuranEnc
  /// text) as in the printed Mushaf; Amiri Quran drew them as other marks.
  static TextStyle quran(double size, {Color? color}) =>
      TextStyle(fontFamily: 'KFGQPCHafs', fontSize: size, color: color ?? const Color(0xFF3A2A12), height: 2.15);

  static TextStyle hadith(double size, {Color? color}) =>
      GoogleFonts.amiri(fontSize: size, color: color ?? BColors.ink, height: 1.95);
}

/// A colour-coded answer card family (pastel card + saturated accent).
class Tone {
  const Tone({
    required this.title,
    required this.titleEn,
    required this.explain,
    required this.explainEn,
    required this.icon,
    required this.accent,
    required this.top,
    required this.bottom,
  });

  final String title;
  final String titleEn;
  final String explain;
  final String explainEn;
  final IconData icon;
  final Color accent;
  final Color top;
  final Color bottom;

  String titleFor(String lang) => lang == 'en' ? titleEn : title;
  String explainFor(String lang) => lang == 'en' ? explainEn : explain;
}

abstract final class Tones {
  static const principle = Tone(
    title: 'الأصل الشرعي',
    titleEn: 'The Islamic principle',
    explain: 'ما يقرّره الإسلام في المسألة، مستنداً إلى القرآن والسنة.',
    explainEn: 'What Islam teaches on the matter, based on the Quran and Sunnah.',
    icon: Icons.auto_stories_rounded,
    accent: Color(0xFFB0741A),
    top: Color(0xFFFFF4DC),
    bottom: Color(0xFFFBE7BE),
  );
  static const culture = Tone(
    title: 'العرف والثقافة',
    titleEn: 'Custom & culture',
    explain: 'ما هو عادة أو ثقافة أو إجراء إداري، وليس شرطاً دينياً.',
    explainEn: 'What is custom, culture or an administrative step — not a religious requirement.',
    icon: Icons.public_rounded,
    accent: Color(0xFF237A4D),
    top: Color(0xFFE9F7EE),
    bottom: Color(0xFFD5EFDF),
  );
  static const guidance = Tone(
    title: 'الإرشاد العملي',
    titleEn: 'What to do next',
    explain: 'خطوات عملية تساعدك فيما تفعله بعد ذلك.',
    explainEn: 'Practical steps to help you with what to do next.',
    icon: Icons.route_rounded,
    accent: Color(0xFF2B62C0),
    top: Color(0xFFEBF2FE),
    bottom: Color(0xFFD7E6FC),
  );
  static const evidence = Tone(
    title: 'الأدلة والمصادر',
    titleEn: 'Evidence & sources',
    explain: 'النصوص الشرعية كما وردت، مع مصدرها ودرجتها ورابط التحقق.',
    explainEn: 'The religious texts as they are, with their source, grading and a link to verify them.',
    icon: Icons.verified_rounded,
    accent: Color(0xFF7A5A26),
    top: Color(0xFFFFFDF8),
    bottom: Color(0xFFF6EFE2),
  );
  static const khilaf = Tone(
    title: 'مسألة خلافية',
    titleEn: 'Scholarly difference',
    explain: 'اختلف فيها العلماء المعتبرون؛ نبيّن المتفق عليه ولا نرجّح بين الأقوال.',
    explainEn: 'Recognised scholars differ; we show what is agreed and do not choose between the views.',
    icon: Icons.balance_rounded,
    accent: Color(0xFF6B3EC0),
    top: Color(0xFFF4EEFD),
    bottom: Color(0xFFE6DAFA),
  );
  static const refer = Tone(
    title: 'يحتاج إلى مختص',
    titleEn: 'Needs a specialist',
    explain: 'حالة شخصية أو فتوى؛ نوضّح العام ونحيلك إلى أهل العلم.',
    explainEn: 'A personal case or fatwa; we explain the general principle and refer you to a scholar.',
    icon: Icons.support_agent_rounded,
    accent: Color(0xFFC0385A),
    top: Color(0xFFFDEEF1),
    bottom: Color(0xFFF9DAE2),
  );
  static const abstain = Tone(
    title: 'لا تتوفر إجابة موثقة',
    titleEn: 'No documented answer',
    explain: 'لم نجد مرجعاً كافياً، فنمتنع بدلاً من التخمين.',
    explainEn: 'We found no sufficient reference, so we hold back instead of guessing.',
    icon: Icons.pan_tool_alt_rounded,
    accent: Color(0xFF65605A),
    top: Color(0xFFF4F3F0),
    bottom: Color(0xFFE6E4DF),
  );
  static const offTopic = Tone(
    title: 'خارج نطاق بصيرة',
    titleEn: "Outside Basirah's scope",
    explain: 'بصيرة تجيب عن الأسئلة المتعلقة بالإسلام فقط.',
    explainEn: 'Basirah only answers questions about Islam.',
    icon: Icons.do_not_disturb_alt_rounded,
    accent: Color(0xFF3F5A73),
    top: Color(0xFFEFF3F7),
    bottom: Color(0xFFDDE6EE),
  );

  static const all = [principle, culture, guidance, evidence, khilaf, refer, abstain, offTopic];
}

extension LevelStyle on ContentLevel {
  Color get color => switch (this) {
    ContentLevel.a => const Color(0xFF237A4D),
    ContentLevel.b => const Color(0xFFB0741A),
    ContentLevel.c => const Color(0xFF6B3EC0),
    ContentLevel.d => const Color(0xFFC0385A),
  };

  /// «أ/ب/ج/د» in Arabic, A/B/C/D in English.
  String letterFor(String lang) => lang == 'en' ? code : letterAr;

  String shortLabelFor(String lang) => switch (this) {
    ContentLevel.a => lang == 'en' ? 'Settled' : 'أصلي مستقر',
    ContentLevel.b => lang == 'en' ? 'Explanation' : 'شرح واستدلال',
    ContentLevel.c => lang == 'en' ? 'Disputed or sensitive' : 'خلافي أو حساس',
    ContentLevel.d => lang == 'en' ? 'Fatwa or personal case' : 'فتوى أو حالة شخصية',
  };
}

extension OriginStyle on AnswerOrigin {
  String labelFor(String lang) => switch (this) {
    AnswerOrigin.kb => lang == 'en' ? 'From the documented knowledge base' : 'من قاعدة المعرفة الموثقة',
    AnswerOrigin.ai => lang == 'en' ? 'Live AI answer from approved sources' : 'مولَّدة بالذكاء الاصطناعي من المراجع المعتمدة',
    AnswerOrigin.offline => lang == 'en' ? 'Local references mode' : 'وضع المراجع المحلية',
  };

  IconData get icon => switch (this) {
    AnswerOrigin.kb => Icons.library_books_outlined,
    AnswerOrigin.ai => Icons.auto_awesome_outlined,
    AnswerOrigin.offline => Icons.offline_bolt_outlined,
  };
}

/// Icon for a category id (quick-access row, tiles).
/// A category's colours, in the same family as the answer cards ([Tones]):
/// a very light two-stop wash and a deeper accent for icons and labels.
extension CategoryStyle on Category {
  Color get accent => HSLColor.fromAHSL(1, hue, .52, .36).toColor();
  Color get top => HSLColor.fromAHSL(1, hue, .78, .955).toColor();
  Color get bottom => HSLColor.fromAHSL(1, hue, .62, .895).toColor();
  IconData get iconData => categoryIcon(icon);
}

IconData categoryIcon(String icon) => switch (icon) {
  'badge' => Icons.badge_outlined,
  'family' => Icons.family_restroom_rounded,
  'mosque' => Icons.mosque_outlined,
  'star' => Icons.lightbulb_outline_rounded,
  'daily' => Icons.wb_sunny_outlined,
  'balance' => Icons.balance_rounded,
  'help' => Icons.help_outline_rounded,
  _ => Icons.circle_outlined,
};

abstract final class BasirahTheme {
  static ThemeData light() {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    final text = GoogleFonts.ibmPlexSansArabicTextTheme(base.textTheme)
        .apply(bodyColor: BColors.ink, displayColor: BColors.ink);
    return base.copyWith(
      scaffoldBackgroundColor: BColors.bg,
      canvasColor: BColors.bg,
      colorScheme: const ColorScheme.light(
        primary: BColors.ink,
        onPrimary: BColors.onInk,
        secondary: BColors.gold,
        surface: BColors.surface,
        onSurface: BColors.ink,
        outline: BColors.stroke,
      ),
      textTheme: text,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: BColors.ink,
        titleTextStyle: BText.title(17),
      ),
      dividerTheme: const DividerThemeData(color: BColors.stroke, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BColors.ink,
        contentTextStyle: BText.body(14, color: BColors.onInk, height: 1.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: BColors.bg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: BColors.textFaint,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: BColors.ink,
        selectionColor: Color(0x55E6A935),
        selectionHandleColor: BColors.gold,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
