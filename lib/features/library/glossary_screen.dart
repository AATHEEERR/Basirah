import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/kb_provider.dart';
import '../../shared/widgets.dart';
import 'page_scaffold.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: context.tr('قاموس المصطلحات', 'Glossary'),
      subtitle: context.tr(
        'المقابل الإنجليزي المعتمد وضابط الاستخدام — من الحزمة العلمية للتحدي وموسوعة الجمهرة',
        "The approved English equivalent and its usage rule — from the challenge's reference pack and the Jamhara encyclopedia",
      ),
      child: KbBuilder(
        builder: (context, kb) {
          final q = normalizeArabic(_q);
          final terms = kb.glossary.where((g) {
            if (q.isEmpty) return true;
            return normalizeArabic('${g.term} ${g.english} ${g.keys.join(' ')}').contains(q) ||
                g.english.toLowerCase().contains(_q.trim().toLowerCase());
          }).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                onChanged: (v) => setState(() => _q = v),
                style: BText.body(15, height: 1.3),
                decoration: InputDecoration(
                  hintText: context.tr('ابحث عن مصطلح… Tawhid، الشريعة', 'Search a term… Tawhid, الشريعة'),
                  hintStyle: BText.body(14, color: BColors.textFaint, height: 1.3),
                  prefixIcon: const Icon(Icons.search_rounded, color: BColors.ink),
                  filled: true,
                  fillColor: BColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              for (final (i, g) in terms.indexed)
                Reveal(
                  delay: Duration(milliseconds: 40 * i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: BColors.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GoldText(g.term, style: BText.display(22)),
                            const Spacer(),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(g.english, style: BText.title(14, color: Tones.culture.accent, weight: FontWeight.w500)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(g.rule, style: BText.body(14.5, color: BColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              if (terms.isEmpty)
                EmptyNote(icon: Icons.search_off_rounded, title: context.tr('لا يوجد مصطلح مطابق', 'No matching term'), body: ''),
            ],
          );
        },
      ),
    );
  }
}
