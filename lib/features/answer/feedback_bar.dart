import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/feedback.dart';
import '../../core/lang.dart';

/// «هل أفادتك هذه الإجابة؟» under an answer: a rating and optional fixed
/// reasons, sent anonymously to «لوحة الأثر». Hidden without a server.
class FeedbackBar extends ConsumerStatefulWidget {
  const FeedbackBar({super.key, required this.answer, this.category});

  final BasirahAnswer answer;
  final String? category;

  @override
  ConsumerState<FeedbackBar> createState() => _FeedbackBarState();
}

class _FeedbackBarState extends ConsumerState<FeedbackBar> {
  bool? _helpful;
  final _reasons = <String>{};
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    final ok = await sendFeedback(
      answer: widget.answer,
      helpful: _helpful!,
      reasons: _reasons.toList(),
      category: widget.category,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      final rated = ref.read(ratedProvider);
      ref.read(ratedProvider.notifier).state = {...rated, widget.answer.key: _helpful!};
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('تعذّر إرسال رأيك، حاول مرة أخرى', 'Your rating could not be sent; try again'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasApi) return const SizedBox.shrink();
    final done = ref.watch(ratedProvider)[widget.answer.key];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(18)),
        child: done != null
            ? Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 20, color: Tones.culture.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('شكراً، رأيك يساعدنا في تحسين بصيرة. لا نحفظ سؤالك.', 'Thank you; your rating helps improve Basirah. Your question is not stored.'),
                      style: BText.label(13, color: BColors.ink, weight: FontWeight.w400),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(context.tr('هل أفادتك هذه الإجابة؟', 'Was this answer helpful?'), style: BText.title(14))),
                      _Choice(
                        icon: Icons.thumb_up_alt_outlined,
                        label: context.tr('نعم', 'Yes'),
                        selected: _helpful == true,
                        onTap: () => setState(() {
                          _helpful = true;
                          _reasons.clear();
                        }),
                      ),
                      const SizedBox(width: 8),
                      _Choice(
                        icon: Icons.thumb_down_alt_outlined,
                        label: context.tr('لا', 'No'),
                        selected: _helpful == false,
                        onTap: () => setState(() {
                          _helpful = false;
                          _reasons.clear();
                        }),
                      ),
                    ],
                  ),
                  if (_helpful != null) ...[
                    const SizedBox(height: 10),
                    Text(context.tr('لماذا؟ (اختياري)', 'Why? (optional)'), style: BText.label(12.5, weight: FontWeight.w400)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (id, ar, en) in _helpful! ? helpfulReasons : unhelpfulReasons)
                          FilterChip(
                            label: Text(context.tr(ar, en), style: BText.label(12.5, color: BColors.ink, weight: FontWeight.w500)),
                            selected: _reasons.contains(id),
                            onSelected: (on) => setState(() => on ? _reasons.add(id) : _reasons.remove(id)),
                            backgroundColor: BColors.bg,
                            selectedColor: BColors.sand,
                            showCheckmark: false,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('يُرسل التقييم وحده دون سؤالك.', 'Only the rating is sent, not your question.'),
                            style: BText.label(11.5, weight: FontWeight.w400),
                          ),
                        ),
                        FilledButton(
                          onPressed: _sending ? null : _send,
                          style: FilledButton.styleFrom(backgroundColor: BColors.ink, shape: const StadiumBorder()),
                          child: Text(context.tr('إرسال', 'Send'), style: BText.label(13, color: BColors.onInk, weight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? BColors.ink : BColors.bg,
    borderRadius: BorderRadius.circular(99),
    child: InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? BColors.onInk : BColors.ink),
            const SizedBox(width: 6),
            Text(label, style: BText.label(13, color: selected ? BColors.onInk : BColors.ink, weight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}
