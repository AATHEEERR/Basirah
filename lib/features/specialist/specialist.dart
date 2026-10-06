import 'dart:async';
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
  final day = context.tr(_weekdaysAr[t.weekday - 1], _weekdaysEn[t.weekday - 1]);
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return '$day ${t.day}/${t.month} · $hm';
}

/// How the asker talks to the specialist: a written message, or a call (in
/// the call room each side chooses voice only or voice and video). 'audio'
/// and 'video' are the older kinds of call, still read back.
String _modeLabel(BuildContext context, String mode) => switch (mode) {
  'call' || 'audio' || 'video' => context.tr('مكالمة', 'Call'),
  _ => context.tr('رسالة مكتوبة', 'Written message'),
};

IconData _modeIcon(String mode) => mode == 'message' ? Icons.mail_outline_rounded : Icons.call_rounded;

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
              'أرسل سؤالك ومحادثتك برسالة، أو احجز مكالمة في الوقت الذي يناسبك. لا يُرسل إلا ما توافق عليه.',
              'Send your question and this conversation as a message, or book a call at a time that suits you. Only what you approve is sent.',
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
/// prepared case summary. With no [answer], the asker writes their question
/// and the details of their case for a specialist directly («اطلب فتوى»).
Future<void> showSpecialistRequest(BuildContext context, BasirahAnswer? answer, {String? caseFile}) {
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

  /// Null for a fatwa asked directly, with no answer before it.
  final BasirahAnswer? answer;
  final ScrollController controller;
  final String? caseFile;

  @override
  ConsumerState<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<_RequestForm> {
  late final _question = TextEditingController(text: widget.answer?.question ?? '');
  String _mode = 'message';
  DateTime? _day;
  int? _hour;
  late bool _withConversation = widget.answer != null || widget.caseFile != null;
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
    final answer = widget.answer;
    if (answer == null) return '';
    final earlier = [
      for (final m in ref.read(chatProvider))
        if (m.fromUser && m.text != answer.question) m.text,
    ];
    final body = AnswerView.plainText(answer, lang).split('\n').skip(2).join('\n').trim();
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
              Expanded(
                child: Text(
                  widget.answer == null && widget.caseFile == null
                      ? context.tr('اطلب فتوى من مختص', 'Ask a specialist for a fatwa')
                      : context.tr('تحدّث مع مختص شرعي', 'Talk to a Sharia specialist'),
                  style: BText.display(22),
                ),
              ),
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
                  for (final m in const ['message', 'call'])
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
                        label: Text('${context.tr(_weekdaysAr[d.weekday - 1], _weekdaysEn[d.weekday - 1])} ${d.day}/${d.month}'),
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
                    'المكالمة في غرفة خاصة بطلبك تُفتح في المتصفح بلا تطبيق، بالصوت وحده أو بالصوت والصورة كما تختار. يؤكد المختص الموعد أو يقترح غيره في «طلباتي مع المختص»، ويفتح الغرفة في الموعد ثم تدخلها.',
                    'The call is in a private room for your request that opens in the browser with no app, by voice only or with video, as you choose. The specialist confirms the time, or suggests another, in “My requests”, and opens the room at that time; then you join.',
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
                  labelText: widget.answer == null && widget.caseFile == null
                      ? context.tr('سؤالك وتفاصيل حالتك', 'Your question and the details of your case')
                      : context.tr(
                          'سؤالك (يمكنك تعديله وإضافة تفاصيل حالتك)',
                          'Your question (you can edit it and add details of your case)',
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              if (widget.answer != null || widget.caseFile != null)
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

class _Thread extends ConsumerStatefulWidget {
  const _Thread({required this.r});

  final MyReferral r;

  @override
  ConsumerState<_Thread> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<_Thread> {
  /// What the server last said, kept on the device: readable with no
  /// connection.
  late Map<String, dynamic>? _live = widget.r.lastSeen;
  late bool _loading = _live == null;

  /// The last refresh could not reach the server.
  bool _offline = false;
  final _reply = TextEditingController();
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    // The specialist's reply appears without a reload.
    // Live: the specialist's reply and status changes appear within seconds.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final live = await ReferralApi.read(widget.r);
    if (!mounted) return;
    // A missed refresh keeps what is on screen (the copy on the device).
    setState(() {
      if (live != null) _live = live;
      _offline = live == null;
      _loading = false;
    });
    if (live != null) await ref.read(myReferralsProvider.notifier).remember(widget.r.id, live);
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
          if (_offline && _live != null)
            Text(
              context.tr('بلا اتصال الآن: هذه آخر نسخة محفوظة على جهازك.', 'No connection right now: this is the last copy saved on your device.'),
              style: BText.label(11.5, color: Tones.abstain.accent, weight: FontWeight.w500),
            ),
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
                  icon: const Icon(Icons.call_rounded, size: 18),
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
/// context the asker approved, and the reply. A specialist signs in with the
/// username and password of the account the team made for them (there is
/// no sign-up).
class SpecialistPanelScreen extends StatefulWidget {
  const SpecialistPanelScreen({super.key});

  @override
  State<SpecialistPanelScreen> createState() => _SpecialistPanelScreenState();
}

class _SpecialistPanelScreenState extends State<SpecialistPanelScreen> {
  /// The session, kept for this visit only (never stored on the device), so
  /// leaving the panel and coming back does not ask again.
  static String? _session;

  final _user = TextEditingController();
  final _password = TextEditingController();
  final _find = TextEditingController();
  List<Map<String, dynamic>>? _items;

  /// Why the sign-in failed ('invalid', 'too_many', 'closed', 'unreachable').
  String? _error;
  bool _loading = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // After the first frame: loading changes the state.
    if (_session != null) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    // Live: new requests, the askers' messages and status changes appear
    // within seconds, with no reload.
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_items != null && !_loading) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _user.dispose();
    _password.dispose();
    _find.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_user.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final (:token, :error) = await ReferralApi.signIn(_user.text.trim(), _password.text);
    if (!mounted) return;
    _password.clear();
    if (token == null) {
      setState(() {
        _loading = false;
        _error = error;
      });
      return;
    }
    _session = token;
    await _load();
  }

  Future<void> _signOut() async {
    final s = _session;
    _session = null;
    setState(() => _items = null);
    if (s != null) await ReferralApi.signOut(s);
  }

  Future<void> _load({bool quiet = false}) async {
    final session = _session;
    if (session == null) return;
    if (!quiet) setState(() => _loading = true);
    final (:items, :unreachable) = await ReferralApi.all(session);
    if (!mounted) return;
    // A missed refresh keeps what is on screen.
    if (quiet && items == null && unreachable) return;
    // Not unreachable and no list: the session ended; sign in again.
    if (items == null && !unreachable) _session = null;
    setState(() {
      // Waiting requests first, then calls by their time, then the rest.
      _items = items == null ? null : ([...items]..sort(_order));
      _error = unreachable ? 'unreachable' : (items == null ? 'expired' : null);
      _loading = false;
    });
  }

  static int _order(Map<String, dynamic> a, Map<String, dynamic> b) {
    int rank(Map<String, dynamic> r) => switch (r['status']) {
      'new' => 0,
      'booked' => 1,
      'answered' => 2,
      _ => 3,
    };
    final byStatus = rank(a).compareTo(rank(b));
    if (byStatus != 0) return byStatus;
    final sa = a['slot'] as String?;
    final sb = b['slot'] as String?;
    if (sa != null && sb != null) return sa.compareTo(sb);
    if (sa != null) return -1;
    if (sb != null) return 1;
    return (b['created'] as String? ?? '').compareTo(a['created'] as String? ?? '');
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
            Text(
              context.tr(
                'يدخل المختص المعتمد باسم المستخدم وكلمة المرور اللذين أنشأهما له فريق بصيرة. لا يوجد تسجيل ذاتي، وتُرفض أي محاولة دخول بغير حساب أنشأه الفريق.',
                'An approved specialist signs in with the username and password the Basirah team made for them. There is no sign-up, and any sign-in without an account the team made is refused.',
              ),
              style: BText.body(14, height: 1.7),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _user,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: InputDecoration(
                labelText: context.tr('اسم المستخدم', 'Username'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _signIn(),
              decoration: InputDecoration(
                labelText: context.tr('كلمة المرور', 'Password'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else
              PrimaryButton(label: context.tr('دخول', 'Sign in'), onTap: _signIn),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  switch (_error) {
                    'unreachable' => context.tr('تعذّر الوصول إلى الخادم الآن. تحقّق من الاتصال وحاول بعد قليل.', 'Could not reach the server right now. Check the connection and try again shortly.'),
                    'too_many' => context.tr('محاولات خاطئة كثيرة من هذا الجهاز. انتظر ربع ساعة ثم حاول مجدداً.', 'Too many wrong attempts from this device. Wait a quarter of an hour, then try again.'),
                    'closed' => context.tr('لا توجد حسابات مختصين على هذا الخادم بعد.', 'There are no specialist accounts on this server yet.'),
                    'expired' => context.tr('انتهت الجلسة. سجّل الدخول مجدداً.', 'The session ended. Please sign in again.'),
                    _ => context.tr('اسم المستخدم أو كلمة المرور غير صحيحة.', 'The username or password is wrong.'),
                  },
                  style: BText.label(13, color: Tones.refer.accent),
                ),
              ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(
                      '${items.length} طلباً · ${items.where((r) => r['status'] == 'new').length} بانتظار الرد · ${items.where((r) => r['status'] == 'booked').length} مكالمات مؤكَّدة',
                      '${items.length} requests · ${items.where((r) => r['status'] == 'new').length} waiting · ${items.where((r) => r['status'] == 'booked').length} confirmed calls',
                    ),
                    style: BText.title(15),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: context.tr('تحديث', 'Refresh'),
                ),
                IconButton(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: context.tr('خروج', 'Sign out'),
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
            const _PanelGuide(),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text(context.tr('لا طلبات الآن.', 'No requests right now.'), style: BText.body(14, color: BColors.textMuted)),
            for (final r in items)
              if (_find.text.trim().isEmpty ||
                  (r['id'] as String).contains(_find.text.trim().toUpperCase()) ||
                  (r['question'] as String).contains(_find.text.trim()))
                _PanelItem(r: r, panelKey: _session ?? '', onChanged: _load),
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
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => launchUrl(Uri.parse(r['meetUrl'] as String), mode: LaunchMode.externalApplication),
                    style: FilledButton.styleFrom(backgroundColor: Tones.guidance.accent),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(context.tr('افتح غرفة المكالمة', 'Open the call room')),
                  ),
                  Text(
                    context.tr('افتحها أنت أولاً في الموعد، ثم يدخل السائل.', 'Open it first at the time; then the asker joins.'),
                    style: BText.label(12, weight: FontWeight.w400),
                  ),
                ],
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

/// How to answer from the panel, in four steps.
class _PanelGuide extends StatelessWidget {
  const _PanelGuide();

  @override
  Widget build(BuildContext context) {
    final steps = [
      context.tr(
        'اقرأ الطلب: السؤال، وما وافق السائل على إرساله من محادثته و«سياقه».',
        'Read the request: the question, and what the asker agreed to send of the conversation and “context”.',
      ),
      context.tr(
        'اكتب ردّك واضغط «أرسل الرد»: يظهر للسائل في «طلباتي مع المختص» على جهازه، ويستطيع أن يضيف تفصيلاً فيصلك هنا.',
        'Write your reply and press “Send reply”: the asker sees it in “My requests” on their device, and can add a detail that reaches you here.',
      ),
      context.tr(
        'للمكالمة: «أكّد الموعد»، أو اكتب موعداً آخر في ردّك. وفي الموعد افتح الغرفة أولاً؛ قد يطلب موقع Jitsi أن يسجّل منشئ الغرفة دخوله (Google أو GitHub أو Facebook).',
        'For a call: “Confirm the time”, or suggest another in your reply. At the time, open the room first; Jitsi may ask whoever creates the room to sign in (Google, GitHub or Facebook).',
      ),
      context.tr(
        '«أغلق الطلب» حين تنتهي. تُحذف الطلبات من الخادم بعد 30 يوماً، والقائمة تتحدّث وحدها كل 30 ثانية.',
        '“Close” when done. Requests are deleted from the server after 30 days; the list refreshes by itself every 30 seconds.',
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Tones.guidance.top, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('دور المختص في أربع خطوات', 'The specialist’s part, in four steps'),
            style: BText.title(14.5, color: Tones.guidance.accent),
          ),
          const SizedBox(height: 6),
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${i + 1}. $step', style: BText.body(13, color: BColors.ink, height: 1.6)),
            ),
        ],
      ),
    );
  }
}
