/// «سياقي»: what the asker chose to tell Basirah about themselves, so an
/// answer can fit «سياق السائل وخلفيته» (participant guide, Track 1).
///
/// Every field is optional and comes from a fixed list — never free text —
/// so it cannot carry instructions or personal details. It stays on the
/// device and travels only with a question; the server neither logs nor
/// stores it. It changes how an answer is explained (words, depth,
/// examples), never the ruling, the content level or the evidence.
library;

enum AskerRole {
  /// A Muslim who embraced Islam recently.
  newMuslim,

  /// Learning about Islam / considering it.
  exploring,

  /// Grew up Muslim.
  bornMuslim;

  static AskerRole? parse(Object? v) => values.where((e) => e.name == v).firstOrNull;
}

/// How long ago a new Muslim embraced Islam.
enum AskerSince {
  under3Months,
  under1Year,
  over1Year;

  static AskerSince? parse(Object? v) => values.where((e) => e.name == v).firstOrNull;
}

enum AskerSetting {
  /// Lives in a Muslim-majority society.
  muslimSociety,

  /// Lives with or near family who are not Muslim.
  nonMuslimFamily;

  static AskerSetting? parse(Object? v) => values.where((e) => e.name == v).firstOrNull;
}

enum AnswerStyle {
  simple,
  detailed;

  static AnswerStyle? parse(Object? v) => values.where((e) => e.name == v).firstOrNull;
}

class AskerContext {
  const AskerContext({this.role, this.since, this.setting, this.style});

  final AskerRole? role;
  final AskerSince? since;
  final AskerSetting? setting;
  final AnswerStyle? style;

  static const none = AskerContext();

  bool get isEmpty => role == null && since == null && setting == null && style == null;

  AskerContext copyWith({
    AskerRole? role,
    AskerSince? since,
    AskerSetting? setting,
    AnswerStyle? style,
    bool clearSince = false,
  }) => AskerContext(
    role: role ?? this.role,
    since: clearSince ? null : (since ?? this.since),
    setting: setting ?? this.setting,
    style: style ?? this.style,
  );

  /// Unknown values are dropped, never passed on.
  factory AskerContext.fromJson(Object? j) {
    if (j is! Map) return none;
    final role = AskerRole.parse(j['role']);
    return AskerContext(
      role: role,
      since: role == AskerRole.newMuslim ? AskerSince.parse(j['since']) : null,
      setting: AskerSetting.parse(j['setting']),
      style: AnswerStyle.parse(j['style']),
    );
  }

  Map<String, String> toJson() => {
    if (role != null) 'role': role!.name,
    if (since != null) 'since': since!.name,
    if (setting != null) 'setting': setting!.name,
    if (style != null) 'style': style!.name,
  };

  /// Stable key for the answer cache: the same question with a different
  /// context is a different answer.
  String get key => [role?.name, since?.name, setting?.name, style?.name].map((v) => v ?? '-').join('.');

  /// For the model, in English (the prompt's language).
  String describe() => [
    switch (role) {
      AskerRole.newMuslim => 'a new Muslim${switch (since) {
        AskerSince.under3Months => ' (embraced Islam less than 3 months ago)',
        AskerSince.under1Year => ' (embraced Islam less than a year ago)',
        AskerSince.over1Year => ' (embraced Islam more than a year ago)',
        null => '',
      }}',
      AskerRole.exploring => 'someone learning about Islam who is not (yet) Muslim',
      AskerRole.bornMuslim => 'someone who grew up Muslim',
      null => null,
    },
    switch (setting) {
      AskerSetting.muslimSociety => 'lives in a Muslim-majority society',
      AskerSetting.nonMuslimFamily => 'lives with or near family who are not Muslim',
      null => null,
    },
    switch (style) {
      AnswerStyle.simple => 'wants short answers in plain words',
      AnswerStyle.detailed => 'wants fuller answers that name the terms and explain the reasoning',
      null => null,
    },
  ].whereType<String>().join('; ');
}
