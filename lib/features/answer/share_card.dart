import 'dart:ui' as ui;

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../shared/brand.dart';
import '../../shared/save_image.dart';

/// Whether an answer can be shared as a card: it must say something and
/// carry evidence to verify (abstentions, referrals and off-topic replies
/// are not shared).
bool canShareCard(BasirahAnswer a) =>
    (a.kind == AnswerKind.answer || a.kind == AnswerKind.khilaf) && a.evidence.isNotEmpty;

/// «بطاقة آمنة للمشاركة»: the answer as an image for the family chat — the
/// verse in the Mushaf text (or the hadith with its grade) and its source,
/// the explanation labelled as Basirah's, and a QR code to the approved
/// platform where the source can be checked.
Future<void> showShareCard(BuildContext context, BasirahAnswer a) => showDialog<void>(
  context: context,
  builder: (context) => _ShareDialog(answer: a),
);

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.answer});

  final BasirahAnswer answer;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final done = context.tr('جاهزة للمشاركة', 'Ready to share');
    final failed = context.tr('تعذّر حفظ البطاقة', 'The card could not be saved');
    final nav = Navigator.of(context);
    try {
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final ok = await saveOrShareImage(bytes, 'basirah-card.png');
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(ok ? done : failed)));
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    backgroundColor: BColors.bg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('بطاقة آمنة للمشاركة', 'A safe card to share'), style: BText.title(17)),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'شاركها بدل الرسائل المتداولة: النص من مصدره، ورمز للتحقق منه.',
                'Share this instead of forwarded messages: the text from its source, and a code to check it.',
              ),
              style: BText.label(12.5, weight: FontWeight.w400),
            ),
            const SizedBox(height: 12),
            RepaintBoundary(key: _key, child: ShareCard(answer: widget.answer, lang: context.lang)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _share,
              style: FilledButton.styleFrom(
                backgroundColor: BColors.ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(context.tr('حفظ أو مشاركة الصورة', 'Save or share the image'), style: BText.label(14, color: Colors.white)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The card itself (also rendered to the image).
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.answer, required this.lang});

  final BasirahAnswer answer;
  final String lang;

  String _t(String ar, String en) => lang == 'en' ? en : ar;

  @override
  Widget build(BuildContext context) {
    final a = answer;
    final verse = a.evidence.where((e) => e.isQuran).firstOrNull;
    final hadith = a.evidence.where((e) => !e.isQuran).firstOrNull;
    final e = verse ?? hadith!;
    // The page where the source can be checked: the hadith on HadeethEnc,
    // otherwise the approved platform's page for the text.
    final checkUrl = !e.isQuran && (e.tafsirUrl?.contains('hadeethenc') ?? false) ? e.tafsirUrl! : e.urlFor(lang);
    var text = a.kind == AnswerKind.khilaf ? a.khilafAgreed : a.principle;
    // Keep the card short: end on a whole sentence when one fits, and mark
    // the cut so the excerpt is never read as the whole answer.
    const max = 420;
    if (text.length > max) {
      final sentence = text.lastIndexOf(RegExp('[.؟!]'), max);
      final clause = text.lastIndexOf(RegExp('[،؛]'), max);
      text = sentence > 150
          ? '${text.substring(0, sentence + 1)} …'
          : '${text.substring(0, clause > 250 ? clause : max).trimRight()} …';
    }
    final ai = a.origin == AnswerOrigin.ai;
    return Directionality(
      textDirection: lang == 'en' ? TextDirection.ltr : TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFDF8), Color(0xFFF7EFDF)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: BColors.gold.withValues(alpha: .35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const BrandLogo(size: 30, tile: true),
                const SizedBox(width: 8),
                Text(_t('بصيرة', 'Basirah'), style: BText.brand(22)),
                const Spacer(),
                Text(_t('إجابة موثّقة المصدر', 'A sourced answer'), style: BText.label(11.5, color: BColors.goldDeep)),
              ],
            ),
            const SizedBox(height: 14),
            Text(a.question, style: BText.title(16.5), textDirection: textDirectionOf(a.question)),
            const SizedBox(height: 10),
            if (e.isQuran) ...[
              Text('﴿${e.text}﴾', style: BText.quran(18.5), textAlign: TextAlign.center, textDirection: TextDirection.rtl),
              Text('[${e.reference}] · ${_t('نص مصحف مجمع الملك فهد', 'King Fahd Complex Mushaf text')}',
                  textAlign: TextAlign.center, style: BText.label(11.5, color: Tones.evidence.accent)),
              if (lang == 'en' && e.translation != null) ...[
                const SizedBox(height: 6),
                Text('“${e.translation}”', style: BText.body(12.5, color: BColors.textMuted, height: 1.5), textAlign: TextAlign.center),
              ],
            ] else ...[
              if (e.narrator case final n?)
                Text(n, style: BText.label(12, color: BColors.textMuted), textDirection: textDirectionOf(n)),
              Text(e.text.contains('«') ? e.text : '«${e.text}»', style: BText.hadith(16), textDirection: TextDirection.rtl),
              Text('${e.source ?? ''}${e.grade == null ? '' : ' · ${e.grade}'}',
                  style: BText.label(11.5, color: Tones.evidence.accent), textDirection: textDirectionOf(e.source ?? '')),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Tones.principle.top, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ai
                        ? _t('شرح بصيرة · مولَّد بالذكاء الاصطناعي من المراجع', 'Basirah’s explanation · AI-generated from the references')
                        : _t('من قاعدة المعرفة الموثقة', 'From the documented knowledge base'),
                    style: BText.label(11, color: Tones.principle.accent),
                  ),
                  const SizedBox(height: 4),
                  Text(text, style: BText.body(13.5, height: 1.65), textDirection: textDirectionOf(text)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: QrImageView(data: checkUrl, size: 84, padding: EdgeInsets.zero, backgroundColor: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_t('امسح الرمز للتحقق من المصدر', 'Scan to check the source'), style: BText.title(13.5)),
                      const SizedBox(height: 2),
                      Text(Uri.parse(checkUrl).host, style: BText.label(11.5, color: BColors.goldDeep)),
                      const SizedBox(height: 6),
                      Text(
                        _t('بصيرة أداة ذكاء اصطناعي وليست مفتياً. للحالات الشخصية اسأل أهل العلم.',
                            'Basirah is an AI tool, not a mufti. For personal cases, ask a scholar.'),
                        style: BText.label(10.5, weight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
