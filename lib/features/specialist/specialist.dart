import 'dart:convert';

import 'package:basirah_core/basirah_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/lang.dart';
import '../../core/referral.dart';
import '../../core/state.dart';
import '../../shared/web_frame.dart';
import '../../shared/widgets.dart';
import '../answer/answer_screen.dart';
import '../library/page_scaffold.dart';
import '../welcome/context_screen.dart';

const _weekdaysAr = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _weekdaysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// «الخميس 8/10 · 16:00», in the device's time.
String slotLabel(BuildContext context, DateTime slot) {
  final t = slot.toLocal();
  final day = context.isEn ? _weekdaysEn[t.weekday - 1] : _weekdaysAr[t.weekday - 1];
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return '$day ${t.day}/${t.month} · $hm';
}

String _modeLabel(BuildContext context, String mode) => switch (mode) {
  'audio' => context.tr('مكالمة صوتية', 'Voice call'),
  'video' => context.tr('مكالمة فيديو', 'Video call'),
  _ => context.tr('رسالة مكتوبة', 'Written message'),
};

IconData _modeIcon(String mode) => switch (mode) {
  'audio' => Icons.call_rounded,
  'video' => Icons.videocam_rounded,
  _ => Icons.mail_outline_rounded,
};

String _statusLabel(BuildContext context, String status) => switch (status) {
  'answered' => context.tr('ردّ المختص', 'The specialist replied'),
  'booked' => context.tr('الموعد مؤكَّد', 'Appointment confirmed'),
  'closed' => context.tr('مغلق', 'Closed'),
  _ => context.tr('بانتظار المختص', 'Waiting for the specialist'),
};

/// Under a scholarly difference or a referral: the way to a person.
class SpecialistCta extends StatelessWidget {
  const SpecialistCta({super.key, required this.answer, required this.tone});

  final BasirahAnswer answer;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasApi) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .8), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent_rounded, size: 20, color: tone.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('تريد جواباً لحالتك من مختص شرعي؟', 'Want an answer for your case from a Sharia specialist?'),
                  style: BText.title(14, color: tone.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(
              'أرسل سؤالك ومحادثتك برسالة، أو احجز مكالمة صوتية أو فيديو في الوقت الذي يناسبك. لا يُرسل إلا ما توافق عليه.',
              'Send your question and this conversation as a message, or book a voice or video call at a time that suits you. Only what you approve is sent.',
            ),
            style: BText.body(13, color: BColors.textMuted, height: 1.6),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => showSpecialistRequest(context, answer),
                style: FilledButton.styleFrom(backgroundColor: tone.accent, visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.forum_rounded, size: 18),
                label: Text(
                  context.tr('تحدّث مع مختص شرعي', 'Talk to a Sharia specialist'),
                  style: BText.label(13, color: Colors.white, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// [caseFile]: what is sent instead of the answer and the chat, e.g. a
/// prepared case summary.
Future<void> showSpecialistRequest(BuildContext context, BasirahAnswer answer, {String? caseFile}) {
  // The website: a centred window, whole on screen. A phone: a sheet.
  if (isWebsite(context)) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 620, maxHeight: MediaQuery.of(context).size.height * .86),
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _RequestForm(answer: answer, controller: ScrollController(), caseFile: caseFile),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      maxChildSize: .95,
      builder: (_, controller) => _RequestForm(answer: answer, controller: controller, caseFile: caseFile),
    ),
  );
}

class _RequestForm extends ConsumerStatefulWidget {
  const _RequestForm({required this.answer, required this.controller, this.caseFile});

  final BasirahAnswer answer;
  final ScrollController controller;
  final String? caseFile;

  @override
  ConsumerState<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<_RequestForm> {
  late final _question = TextEditingController(text: widget.answer.question);
  String _mode = 'message';
  DateTime? _day;
  int? _hour;
  bool _withConversation = true;
  bool _withContext = true;
  bool _consent = false;
  bool _sending = false;
  bool _failed = false;
  MyReferral? _sent;

  static const _hours = [10, 13, 16, 19, 21];

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  /// This answer in short, and the questions asked before it in the chat.
  String _conversation(String lang) {
    if (widget.caseFile case final file?) return file;
    final earlier = [
      for (final m in ref.read(chatProvider))
        if (m.fromUser && m.text != widget.answer.question) m.text,
    ];
    final body = AnswerView.plainText(widget.answer, lang).split('\n').skip(2).join('\n').trim();
    final short = body.length > 900 ? '${body.substring(0, 900)} …' : body;
    return [
      if (earlier.isNotEmpty) '${lang == 'en' ? 'Earlier questions' : 'أسئلة سابقة'}: ${earlier.take(3).join(' / ')}',
      '${lang == 'en' ? 'Basirah’s answer (short)' : 'إجابة بصيرة (مختصرة)'}:\n$short',
    ].join('\n\n');
  }

  DateTime? get _slot => _day == null || _hour == null ? null : DateTime(_day!.year, _day!.month, _day!.day, _hour!);

  bool get _ready => _consent && _question.text.trim().isNotEmpty && (_mode == 'message' || (_slot?.isAfter(DateTime.now()) ?? false));

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _failed = false;
    });
    final lang = context.lang;
    final r = await ReferralApi.send(
      question: _question.text.trim(),
      conversation: _withConversation ? _conversation(lang) : '',
      context: _withContext ? contextSummary(context, ref.read(askerContextProvider)) : '',
      lang: questionLang(_question.text) == 'en' ? 'en' : 'ar',
      mode: _mode,
      slot: _mode == 'message' ? null : _slot,
    );
    if (!mounted) return;
    if (r != null) await ref.read(myReferralsProvider.notifier).add(r);
    setState(() {
      _sending = false;
      _sent = r;
      _failed = r == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sent case final r?) return _Sent(r: r, controller: widget.controller);
    final asker = ref.watch(askerContextProvider);
    final summary = contextSummary(context, asker);
    final days = [for (var i = 1; i <= 7; i++) DateUtils.dateOnly(DateTime.now()).add(Duration(days: i))];
    final send = FilledButton.icon(
      onPressed: _ready && !_sending ? _send : null,
      style: FilledButton.styleFrom(backgroundColor: BColors.ink, padding: const EdgeInsets.symmetric(vertical: 14)),
      icon: _sending
          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.send_rounded, size: 18),
      label: Text(
        _mode == 'message' ? context.tr('أرسل إلى المختص', 'Send to the specialist') : context.tr('اطلب الموعد', 'Request the appointment'),
        style: BText.title(14.5, color: Colors.white),
      ),
    );
    // The title and the send button stay in view; the form scrolls between.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text(context.tr('تحدّث مع مختص شرعي', 'Talk to a Sharia specialist'), style: BText.display(22))),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: context.tr('إغلاق', 'Close'),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Text(
                context.tr(
                  'يصل طلبك إلى لوحة المختصين في بصيرة، وتجد الرد في «طلباتي مع المختص». بلا حساب ولا اسم.',
                  'Your request reaches the specialists’ panel in Basirah, and you find the reply in “My requests”. No account, no name.',
                ),
                style: BText.body(13.5, color: BColors.textMuted, height: 1.6),
              ),
              const SizedBox(height: 16),
              Text(context.tr('كيف تحب أن تتواصل؟', 'How would you like to talk?'), style: BText.title(15)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in const ['message', 'audio', 'video'])
                    ChoiceChip(
                      selected: _mode == m,
                      onSelected: (_) => setState(() => _mode = m),
                      avatar: Icon(_modeIcon(m), size: 18),
                      label: Text(_modeLabel(context, m)),
                    ),
                ],
              ),
              if (_mode != 'message') ...[
                const SizedBox(height: 14),
                Text(context.tr('اختر اليوم', 'Pick a day'), style: BText.title(14)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in days)
                      ChoiceChip(
                        selected: _day == d,
                        onSelected: (_) => setState(() => _day = d),
                        label: Text('${context.isEn ? _weekdaysEn[d.weekday - 1] : _weekdaysAr[d.weekday - 1]} ${d.day}/${d.month}'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(context.tr('والساعة (بتوقيت جهازك)', 'And the time (your device’s time)'), style: BText.title(14)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final h in _hours)
                      ChoiceChip(
                        selected: _hour == h,
                        onSelected: (_) => setState(() => _hour = h),
                        label: Text('${h.toString().padLeft(2, '0')}:00'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'المكالمة في غرفة خاصة بطلبك تُفتح في المتصفح، بلا تطبيق ولا حساب. يؤكد المختص الموعد أو يقترح غيره في «طلباتي مع المختص».',
                    'The call is in a private room for your request that opens in the browser, with no app or account. The specialist confirms the time, or suggests another, in “My requests”.',
                  ),
                  style: BText.label(12.5, weight: FontWeight.w400),
                ),
              ],
              const SizedBox(height: 18),
              Text(context.tr('ما الذي سيصل إلى المختص', 'What the specialist will receive'), style: BText.title(15)),
              const SizedBox(height: 8),
              TextField(
                controller: _question,
                minLines: 2,
                maxLines: 6,
                maxLength: 1200,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.tr(
                    'سؤالك (يمكنك تعديله وإضافة تفاصيل حالتك)',
                    'Your question (you can edit it and add details of your case)',
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _withConversation,
                onChanged: (v) => setState(() => _withConversation = v),
                title: Text(
                  widget.caseFile != null
                      ? context.tr(
                          'أرسل معه ملف حالتك (إجاباتك ونص المسألة من الموسوعة الفقهية)',
                          'Also send your case file (your answers and the matter from the fiqh encyclopedia)',
                        )
                      : context.tr(
                          'أرسل معه إجابة بصيرة مختصرة وأسئلتك السابقة',
                          'Also send Basirah’s answer in short and your earlier questions',
                        ),
                  style: BText.body(13.5, height: 1.4),
                ),
              ),
              if (_withConversation)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: BColors.bg, borderRadius: BorderRadius.circular(12)),
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: Text(_conversation(context.lang), style: BText.label(12, weight: FontWeight.w400)),
                  ),
                ),
              if (summary.isNotEmpty)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _withContext,
                  onChanged: (v) => setState(() => _withContext = v),
                  title: Text(context.tr('أرسل «سياقي»: $summary', 'Send “My context”: $summary'), style: BText.body(13.5, height: 1.4)),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                title: Text(
                  context.tr(
                    'أوافق على إرسال ما سبق إلى المختص، ويُحذف من الخادم بعد 30 يوماً.',
                    'I agree to send the above to the specialist; it is deleted from the server after 30 days.',
                  ),
                  style: BText.body(13.5, height: 1.5),
                ),
              ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.tr('تعذّر الإرسال الآن. حاول بعد قليل.', 'Could not send right now. Try again shortly.'),
                    style: BText.label(13, color: Tones.refer.accent),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: BColors.stroke)),
          ),
          child: SafeArea(top: false, child: send),
        ),
      ],
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.r, required this.controller});

  final MyReferral r;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) => ListView(
    controller: controller,
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
    children: [
      Icon(Icons.check_circle_rounded, size: 52, color: Tones.guidance.accent),
      const SizedBox(height: 8),
      Text(
        context.tr('وصل طلبك إلى المختصين', 'Your request reached the specialists'),
        textAlign: TextAlign.center,
        style: BText.display(21),
      ),
      const SizedBox(height: 6),
      SelectableText(
        context.tr('رمز الطلب: ${r.id}', 'Request code: ${r.id}'),
        textAlign: TextAlign.center,
        style: BText.title(16, color: BColors.goldDeep),
      ),
      const SizedBox(height: 12),
      if (r.slot != null) ...[
        _Line(icon: _modeIcon(r.mode), text: '${_modeLabel(context, r.mode)} · ${slotLabel(context, r.slot!)}'),
        if (r.meetUrl != null)
          _Line(
            icon: Icons.link_rounded,
            text: context.tr(
              'رابط المكالمة محفوظ في «طلباتي مع المختص»، ويعمل في الموعد بعد تأكيد المختص.',
              'The call link is kept in “My requests”, and works at the time once the specialist confirms.',
            ),
          ),
      ] else
        _Line(
          icon: Icons.mail_outline_rounded,
          text: context.tr('يصل الرد إلى «طلباتي مع المختص» على هذا الجهاز.', 'The reply arrives in “My requests” on this device.'),
        ),
      _Line(
        icon: Icons.lock_outline_rounded,
        text: context.tr(
          'الطلب مرتبط بهذا الجهاز وحده، ويُحذف من الخادم بعد 30 يوماً.',
          'The request is tied to this device only, and is deleted from the server after 30 days.',
        ),
      ),
      const SizedBox(height: 16),
      PrimaryButton(
        label: context.tr('طلباتي مع المختص', 'My requests'),
        icon: Icons.arrow_forward_rounded,
        expand: true,
        onTap: () {
          Navigator.of(context).pop();
          context.push('/referrals');
        },
      ),
    ],
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: BColors.goldDeep),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: BText.body(13.5, color: BColors.textMuted, height: 1.6)),
        ),
      ],
    ),
  );
}

/// «طلباتي مع المختص»: the requests from this device, each with its thread.
class MyReferralsScreen extends ConsumerWidget {
  const MyReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myReferralsProvider);
    return PageScaffold(
      title: context.tr('طلباتي مع المختص', 'My requests to a specialist'),
      subtitle: context.tr(
        'ما أرسلته إلى المختص الشرعي وردوده ومواعيدك. محفوظة على هذا الجهاز فقط.',
        'What you sent to the Sharia specialist, the replies and your appointments. Kept on this device only.',
      ),
      child: mine.isEmpty
          ? EmptyNote(
              icon: Icons.forum_outlined,
              title: context.tr('لا طلبات بعد', 'No requests yet'),
              body: context.tr(
                'تحت المسائل الخلافية والحالات الشخصية تجد «تحدّث مع مختص شرعي».',
                'Under scholarly differences and personal cases you will find “Talk to a Sharia specialist”.',
              ),
            )
          : Column(children: [for (final r in mine) _Thread(r: r)]),
    );
  }
}

class _Thread extends StatefulWidget {
  const _Thread({required this.r});

  final MyReferral r;

  @override
  State<_Thread> createState() => _ThreadState();
}

class _ThreadState extends State<_Thread> {
  Map<String, dynamic>? _live;
  bool _loading = true;
  final _reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final live = await ReferralApi.read(widget.r);
    if (mounted) {
      setState(() {
        _live = live;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    if (await ReferralApi.followUp(widget.r, text)) {
      _reply.clear();
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final status = _live?['status'] as String? ?? 'new';
    final messages = ((_live?['messages'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final booked = status == 'booked';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: BColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_modeIcon(r.mode), size: 18, color: BColors.goldDeep),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_modeLabel(context, r.mode)}${r.slot == null ? '' : ' · ${slotLabel(context, r.slot!)}'}',
                  style: BText.label(12.5, color: BColors.goldDeep, weight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: (booked || status == 'answered' ? Tones.guidance : Tones.abstain).top,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _loading ? '…' : (_live == null ? context.tr('غير متاح', 'Unavailable') : _statusLabel(context, status)),
                  style: BText.label(
                    11.5,
                    color: (booked || status == 'answered' ? Tones.guidance : Tones.abstain).accent,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded, size: 20), tooltip: context.tr('تحديث', 'Refresh')),
            ],
          ),
          Text(
            r.question,
            style: BText.title(14.5, weight: FontWeight.w500),
            textDirection: textDirectionOf(r.question),
          ),
          Text(context.tr('رمز الطلب: ${r.id}', 'Request code: ${r.id}'), style: BText.label(11.5, weight: FontWeight.w400)),
          for (final m in messages)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: m['from'] == 'specialist' ? Tones.guidance.top : BColors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['from'] == 'specialist' ? context.tr('المختص', 'Specialist') : context.tr('أنت', 'You'),
                    style: BText.label(
                      11.5,
                      color: m['from'] == 'specialist' ? Tones.guidance.accent : BColors.textMuted,
                      weight: FontWeight.w600,
                    ),
                  ),
                  SelectableText(
                    m['text'] as String,
                    style: BText.body(13.5, height: 1.65),
                    textDirection: textDirectionOf(m['text'] as String),
                  ),
                ],
              ),
            ),
          if (r.meetUrl != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton.icon(
                  onPressed: booked ? () => launchUrl(Uri.parse(r.meetUrl!), mode: LaunchMode.externalApplication) : null,
                  icon: Icon(r.mode == 'video' ? Icons.videocam_rounded : Icons.call_rounded, size: 18),
                  label: Text(
                    booked ? context.tr('ادخل المكالمة', 'Join the call') : context.tr('يُفتح بعد تأكيد الموعد', 'Opens once confirmed'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: r.meetUrl!)),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(context.tr('انسخ الرابط', 'Copy the link')),
                ),
              ],
            ),
          ],
          if (_live != null && status != 'closed') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _reply,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: context.tr('أضف تفصيلاً أو سؤالاً للمختص', 'Add a detail or a question for the specialist'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded), tooltip: context.tr('إرسال', 'Send')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The specialists' panel (/specialist): every request, the conversation and
/// context the asker approved, and the reply. Opens with the panel key.
class SpecialistPanelScreen extends StatefulWidget {
  const SpecialistPanelScreen({super.key});

  @override
  State<SpecialistPanelScreen> createState() => _SpecialistPanelScreenState();
}

class _SpecialistPanelScreenState extends State<SpecialistPanelScreen> {
  final _key = TextEditingController();
  final _find = TextEditingController();
  List<Map<String, dynamic>>? _items;
  bool _denied = false;
  bool _loading = false;

  @override
  void dispose() {
    _key.dispose();
    _find.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _denied = false;
    });
    final items = await ReferralApi.all(_key.text.trim());
    if (!mounted) return;
    setState(() {
      _items = items;
      _denied = items == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return PageScaffold(
      title: context.tr('لوحة المختصين', 'Specialists’ panel'),
      subtitle: context.tr(
        'طلبات السائلين إلى مختص شرعي: الرسائل والمواعيد. تُحذف الطلبات بعد 30 يوماً.',
        'Askers’ requests to a Sharia specialist: messages and appointments. Requests are deleted after 30 days.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items == null) ...[
            TextField(
              controller: _key,
              obscureText: true,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                labelText: context.tr('مفتاح اللوحة', 'Panel key'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            PrimaryButton(label: context.tr('افتح اللوحة', 'Open the panel'), onTap: _load),
            if (_denied)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  context.tr('المفتاح غير صحيح، أو اللوحة مغلقة على هذا الخادم.', 'Wrong key, or the panel is closed on this server.'),
                  style: BText.label(13, color: Tones.refer.accent),
                ),
              ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(
                      '${items.length} طلباً · ${items.where((r) => r['status'] == 'new').length} بانتظار الرد',
                      '${items.length} requests · ${items.where((r) => r['status'] == 'new').length} waiting',
                    ),
                    style: BText.title(15),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: context.tr('تحديث', 'Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Find a request by the code the asker was given.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _find,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: context.tr('ابحث برمز الطلب أو بكلمة من السؤال', 'Find by request code or a word of the question'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(items)));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('نُسخت كل الطلبات (JSON)', 'All requests copied (JSON)'))),
                    );
                  },
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: Text(context.tr('انسخ كل الطلبات', 'Copy all requests')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(context.tr('لا طلبات الآن.', 'No requests right now.'), style: BText.body(14, color: BColors.textMuted)),
            for (final r in items)
              if (_find.text.trim().isEmpty ||
                  (r['id'] as String).contains(_find.text.trim().toUpperCase()) ||
                  (r['question'] as String).contains(_find.text.trim()))
                _PanelItem(r: r, panelKey: _key.text.trim(), onChanged: _load),
          ],
        ],
      ),
    );
  }
}

class _PanelItem extends StatefulWidget {
  const _PanelItem({required this.r, required this.panelKey, required this.onChanged});

  final Map<String, dynamic> r;
  final String panelKey;
  final VoidCallback onChanged;

  @override
  State<_PanelItem> createState() => _PanelItemState();
}

class _PanelItemState extends State<_PanelItem> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _reply({String? status}) async {
    setState(() => _busy = true);
    final ok = await ReferralApi.reply(widget.panelKey, widget.r['id'] as String, text: _text.text, status: status);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _text.clear();
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final mode = r['mode'] as String;
    final slot = r['slot'] == null ? null : DateTime.parse(r['slot'] as String);
    final messages = (r['messages'] as List).cast<Map<String, dynamic>>();
    final status = r['status'] as String;
    final question = r['question'] as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: status == 'new' ? Tones.refer.accent.withValues(alpha: .4) : BColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${r['id']} · ${_modeLabel(context, mode)}${slot == null ? '' : ' · ${slotLabel(context, slot)}'} · ${_statusLabel(context, status)} · ${(r['lang'] as String).toUpperCase()}',
            style: BText.label(12, color: BColors.goldDeep, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          SelectableText(
            question,
            style: BText.title(15, weight: FontWeight.w500),
            textDirection: textDirectionOf(question),
          ),
          if ((r['context'] as String).isNotEmpty)
            Text(
              context.tr('سياق السائل: ${r['context']}', 'Asker’s context: ${r['context']}'),
              style: BText.label(12.5, weight: FontWeight.w400),
            ),
          if ((r['conversation'] as String).isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: BColors.bg, borderRadius: BorderRadius.circular(12)),
              child: SelectableText(r['conversation'] as String, style: BText.label(12.5, weight: FontWeight.w400)),
            ),
          for (final m in messages)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${m['from'] == 'specialist' ? context.tr('المختص', 'Specialist') : context.tr('السائل', 'Asker')}: ${m['text']}',
                style: BText.body(13.5, height: 1.6),
              ),
            ),
          if (r['meetUrl'] != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(r['meetUrl'] as String), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: Text(context.tr('غرفة المكالمة', 'Call room')),
              ),
            ),
          if (status != 'closed') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              minLines: 2,
              maxLines: 8,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: context.tr('ردّك على السائل', 'Your reply to the asker'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton(onPressed: _busy ? null : () => _reply(), child: Text(context.tr('أرسل الرد', 'Send reply'))),
                if (mode != 'message')
                  OutlinedButton(
                    onPressed: _busy ? null : () => _reply(status: 'booked'),
                    child: Text(context.tr('أكّد الموعد', 'Confirm the time')),
                  ),
                TextButton(
                  onPressed: _busy ? null : () => _reply(status: 'closed'),
                  child: Text(context.tr('أغلق الطلب', 'Close')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
