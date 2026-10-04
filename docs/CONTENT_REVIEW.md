# Content review process

The reference pack requires human review when needed ("مراجعة بشرية عند الحاجة"). In Basirah every curated item carries a `review` field:

| Value | Meaning | Shown to users as |
|---|---|---|
| `pending` | Authored from approved references by the team; not yet signed off | «بانتظار مراجعة المختص الشرعي للفريق» |
| `reviewed` | Signed off by a qualified Sharia reviewer | «راجعها مختص شرعي» |
| `generated` | Produced at run time (Claude or router) — never reviewed | «إجابة مولَّدة آلياً، لم يراجعها مختص» |

## Checklist per entry (`assets/kb/faqs.json`)

1. **Level** (A/B/C/D) matches the reference pack's definitions.
2. **Kind** matches the level: C → `khilaf` unless a constrained answer about the agreed part is enough; D → `refer`.
3. **Principle** says only what the cited evidence and approved sources support; no automated preference between scholarly views.
4. **Culture** correctly separates custom from religion.
5. **Guidance** is practical, gentle and does not amount to a personal fatwa.
6. **Evidence ids** all exist and actually support the text.

## Checklist per evidence item (`assets/kb/evidence.json`)

* **Quran**: text matches the King Fahd Complex Mushaf; surah and verse numbers correct. **Automated:** `cd server && dart run tool/verify_registry.dart` checks every curated verse against the KFGQPC Uthmani text exactly, letters and marks (last run: 35/35 exact). The reviewer still confirms each verse is *relevant* to the point it supports.
* **Live answers**: verse text always comes from the KFGQPC dataset and a verse is shown only if the model read its tafsir; the reviewer can inspect the research trail («كيف وصلت بصيرة إلى الأدلة؟») and spot-check live answers with `dart run bin/eval.dart --ai`.
* **Hadith**: wording, source and numbering match; grade taken from dorar.net/hadith (الموسوعة الحديثية) or the approved editions on shamela.ws.

After sign-off, set `"review": "reviewed"` on the entry and bump `version` in `faqs.json`.

`dart test` in `packages/basirah_core` re-checks structural integrity (ids, card fields per kind, every curated question routing to itself) after any edit.
