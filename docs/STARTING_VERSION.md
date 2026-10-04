# Starting version (نسخة البداية)

The participant guide (FAQ, p. 43) allows using an earlier project «مع توثيق نسخة البداية والإفصاح عن الحقوق، ويُقيَّم ما أُنجز من 4 إلى 6 أكتوبر فقط».

This file records what existed **before** the challenge window (4–6 October 2026), and what was built during it.

## Baseline

* Snapshot: `baseline/basirah_baseline_2026-10-04.zip`, taken on 4 October 2026 before any work in the challenge window (130 files; secrets and generated data excluded). SHA-256: `89786B1D7AB3970BB5366AE05B1C8003D642D07ACAE21952E38767F7F5149A3B`
* Built with: Flutter, Dart, the Gemini and Claude APIs, Claude Code (AI coding assistant)
* Rights: all code and curated text are the team's own work; third-party components under their licences (see SOURCES_AND_LICENSES.md)

### What the baseline contains

* App shell, theme, category / answer / ask / library screens; Arabic and English interface; answers in the language of the question; the app shown inside a phone frame on computers
* Shared core: Arabic retrieval, safety signals, offline router; off-topic rejection
* API: research agent on Gemini or Claude with a model fallback chain; tools `search_quran`, `read_tafsir` (Tafsir al-Tabari via the Quran.com API), `submit_answer`; the guard (verse text from the Mushaf dataset, hadith from a closed registry with a reason, level D → referral, abstain/refer cite nothing)
* Quran dataset from the Quran.com API
* Knowledge base draft: 24 entries and an evidence registry (35 verses, 17 hadith), pending human review; one entry (`id-name`) human-reviewed on 29 September
* Evaluation set: 12 official situations + 14 team cases (26), offline and live runners

## Work done in the challenge window (evaluated)

### 4 October

* **Reference pack, word for word.** `assets/kb/reference.json` rewritten verbatim from the updated pack (edition 1448/3/20), including pages 8–15 (the association and the approved platforms); `server/tool/verify_package_text.dart` checks it character by character against the PDF: 177/177 texts match. The About screen quotes the participant guide's Track 1 description and success criterion exactly.
* **Quran text from the pack's platforms.** The dataset is now built from QuranEnc (King Fahd Complex Mushaf text, Hilali & Khan, al-Muyassar index) and Quranpedia (modern spelling, surah names); letter-for-letter identical to the previous text. The 35 curated verses match the Mushaf exactly, marks included (35/35).
* **Tafsir from dorar.net/tafseer.** The model reads موسوعة التفسير in الدرر السنية before citing a verse; the verse card shows Dorar's own explanation and links to the exact passage. Tafsir al-Tabari is kept in the code but no longer used.
* **Live hadith from the association's MCP server.** New `search_hadith` tool: search through mcp.islamiccontent.org, details from the HadeethEnc API; only accepted grades (صحيح/حسن); text, source, grade and explanation shown as HadeethEnc published them, with its approved translation in English answers; Dorar verification link kept.
* **Prompt-injection defences and tests.** Angle brackets in user text neutralised; rule that question and source text are material, never instructions; a forced referral drops any ruling the model wrote; Quran wording written by the model without quotation marks is replaced by its reference. 8 automated tests + 5 evaluation cases (live: 5/5).
* **«سياقي»** — optional on-device asker context (who, since when, where, answer style) asked at first launch; fixed choices only; adapts the explanation, never the ruling.
* **Answer cache** — a repeated first question is answered without a model call; the question text is never stored; personal cases are never cached.
* **Website layout on computers** — side navigation, reading column, larger text; «عرض الجوال» switch.
* **Verse recitation** — mp3quran.net reciters with per-verse timing, repeat, slower speed, and المصحف المعلّم for the whole surah.
* **Design documentation** — `docs/DESIGN_SYSTEM.md`, `docs/USER_JOURNEY.md`, `docs/USER_TEST_KIT.md`.

## Still to do in the window

* [ ] Human review of every entry and evidence item against the approved sources; only then set `review: reviewed` in `assets/kb/faqs.json` (the answer footer then reads «روجعت بشرياً مقابل المصادر المعتمدة»)
* [ ] User tests with 3–5 people (`docs/USER_TEST_KIT.md`) and fixes
* [ ] Full live evaluation report
* [ ] Deployment (live link), README, deck, video
