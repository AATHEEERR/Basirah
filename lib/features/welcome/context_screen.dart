import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/lang.dart';
import '../../core/state.dart';
import '../../shared/patterns.dart';
import '../../shared/web_frame.dart';
import '../../shared/widgets.dart';

/// «سياقي»: three optional questions that let answers fit «سياق السائل
/// وخلفيته». Shown once after Welcome
/// ([firstRun]) and editable later. Every answer can be skipped; the
/// choices stay on this device and travel only with a question.
class ContextScreen extends ConsumerStatefulWidget {
  const ContextScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  ConsumerState<ContextScreen> createState() => _ContextScreenState();
}

class _ContextScreenState extends ConsumerState<ContextScreen> {
  late AskerContext _c = ref.read(askerContextProvider);

  void _finish(AskerContext value) {
    ref.read(askerContextProvider.notifier).set(value);
    if (widget.firstRun || !context.canPop()) {
      context.go('/home');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const PatternBackdrop(height: 300),
          SafeArea(
            child: ReadingWidth(
              maxWidth: 720,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Row(
                    children: [
                      if (!widget.firstRun)
                        IconButton(
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/home'),
                          icon: Icon(
                            context.isEn
                                ? Icons.arrow_back_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          tooltip: context.tr('رجوع', 'Back'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            _finish(widget.firstRun ? AskerContext.none : _c),
                        child: Text(
                          widget.firstRun
                              ? context.tr('تخطَّ', 'Skip')
                              : context.tr('تم', 'Done'),
                          style: BText.label(
                            14,
                            color: BColors.goldDeep,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GoldText(
                    context.tr('سياقي', 'My context'),
                    style: BText.display(30),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'ثلاثة أسئلة اختيارية لتُشرح الإجابة بما يناسبك: الكلمات والأمثلة ومقدار التفصيل. '
                          'لا تغيّر الحكم ولا الأدلة.',
                      'Three optional questions so answers are explained in a way that suits you: the words, the examples '
                          'and the level of detail. They never change the ruling or the evidence.',
                    ),
                    style: BText.body(
                      14,
                      color: BColors.textMuted,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Question(
                    title: context.tr('من أنت؟', 'Who are you?'),
                    options: [
                      (
                        AskerRole.newMuslim,
                        context.tr('مسلم جديد', 'A new Muslim'),
                      ),
                      (
                        AskerRole.exploring,
                        context.tr(
                          'أتعرّف على الإسلام',
                          'Learning about Islam',
                        ),
                      ),
                    ],
                    selected: _c.role,
                    onSelected: (v) => setState(
                      () => _c = AskerContext(
                        role: v,
                        since: v == AskerRole.newMuslim ? _c.since : null,
                        setting: _c.setting,
                        style: _c.style,
                      ),
                    ),
                  ),
                  if (_c.role == AskerRole.newMuslim)
                    _Question(
                      title: context.tr('منذ متى أسلمت؟', 'Since when?'),
                      options: [
                        (
                          AskerSince.under3Months,
                          context.tr('أقل من ٣ أشهر', 'Under 3 months'),
                        ),
                        (
                          AskerSince.under1Year,
                          context.tr('أقل من سنة', 'Under a year'),
                        ),
                        (
                          AskerSince.over1Year,
                          context.tr('أكثر من سنة', 'Over a year'),
                        ),
                      ],
                      selected: _c.since,
                      onSelected: (v) => setState(
                        () => _c = _c.copyWith(since: v, clearSince: v == null),
                      ),
                    ),
                  _Question(
                    title: context.tr('أين تعيش؟', 'Where do you live?'),
                    options: [
                      (
                        AskerSetting.muslimSociety,
                        context.tr('في مجتمع مسلم', 'In a Muslim society'),
                      ),
                      (
                        AskerSetting.nonMuslimFamily,
                        context.tr(
                          'مع أسرة غير مسلمة أو قربها',
                          'With or near non-Muslim family',
                        ),
                      ),
                    ],
                    selected: _c.setting,
                    onSelected: (v) => setState(
                      () => _c = AskerContext(
                        role: _c.role,
                        since: _c.since,
                        setting: v,
                        style: _c.style,
                      ),
                    ),
                  ),
                  _Question(
                    title: context.tr(
                      'كيف تحب الإجابة؟',
                      'How do you like answers?',
                    ),
                    options: [
                      (
                        AnswerStyle.simple,
                        context.tr('مختصرة وبسيطة', 'Short and simple'),
                      ),
                      (
                        AnswerStyle.detailed,
                        context.tr(
                          'مفصّلة مع المصطلحات',
                          'Detailed, with the terms',
                        ),
                      ),
                    ],
                    selected: _c.style,
                    onSelected: (v) => setState(
                      () => _c = AskerContext(
                        role: _c.role,
                        since: _c.since,
                        setting: _c.setting,
                        style: v,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SoftCard(
                    radius: 20,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: BColors.goldDeep,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.tr(
                              'تبقى اختياراتك على جهازك وحدك، وتُرسل مع السؤال فقط لتكييف الشرح، ولا يحفظها الخادم ولا يسجّلها. '
                                  'يمكنك تغييرها أو حذفها في أي وقت من «المكتبة».',
                              'Your choices stay on this device. They are sent only with a question, to fit the explanation; the '
                                  'server neither stores nor logs them. Change or clear them any time from the Library.',
                            ),
                            style: BText.body(
                              13,
                              color: BColors.textMuted,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: context.tr('احفظ', 'Save'),
                    icon: Icons.check_rounded,
                    expand: true,
                    onTap: () => _finish(_c),
                  ),
                  if (!widget.firstRun && !_c.isEmpty) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: () => _finish(AskerContext.none),
                        child: Text(
                          context.tr('امسح سياقي', 'Clear my context'),
                          style: BText.label(13, color: BColors.textMuted),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Question<T> extends StatelessWidget {
  const _Question({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: BText.title(16)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in options)
              ChoiceChip(
                label: Text(
                  label,
                  style: BText.label(
                    14,
                    color: selected == value ? Colors.white : BColors.ink,
                  ),
                ),
                selected: selected == value,
                // Tapping the chosen option again clears it (each answer is optional).
                onSelected: (on) => onSelected(on ? value : null),
                selectedColor: BColors.goldDeep,
                backgroundColor: BColors.surface,
                showCheckmark: false,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: BColors.goldDeep.withValues(alpha: .35),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// One line summarising the context, e.g. «مسلم جديد · أسرة غير مسلمة · مختصرة».
String contextSummary(BuildContext context, AskerContext c) => [
  switch (c.role) {
    AskerRole.newMuslim => context.tr('مسلم جديد', 'New Muslim'),
    AskerRole.exploring => context.tr(
      'أتعرّف على الإسلام',
      'Learning about Islam',
    ),
    AskerRole.bornMuslim => context.tr('نشأت مسلماً', 'Grew up Muslim'),
    null => null,
  },
  switch (c.setting) {
    AskerSetting.muslimSociety => context.tr('مجتمع مسلم', 'Muslim society'),
    AskerSetting.nonMuslimFamily => context.tr(
      'أسرة غير مسلمة',
      'Non-Muslim family',
    ),
    null => null,
  },
  switch (c.style) {
    AnswerStyle.simple => context.tr('مختصرة', 'Short'),
    AnswerStyle.detailed => context.tr('مفصّلة', 'Detailed'),
    null => null,
  },
].whereType<String>().join(' · ');
