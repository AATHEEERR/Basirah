# بصيرة · Basirah

> «قُلْ هَٰذِهِ سَبِيلِي أَدْعُو إِلَى اللَّهِ ۚ عَلَىٰ بَصِيرَةٍ» — يوسف: 108

**Basirah** is a bilingual (Arabic / English) conversational app for anyone asking about Islam, designed through the eyes of a Muslim in their first year. It answers the questions new Muslims (and people curious about Islam) actually ask — *"Do I have to change my name?"*, *"Can I visit my non-Muslim family?"* — **only from approved references**, in colour-coded cards that separate what Islam teaches from what is merely culture, and that **refuse to guess**: disputed matters are declared as disputed, personal cases are referred to a qualified mufti, and anything without documented grounding gets an honest "no documented answer".

Built for the **AI Challenge Serving Islamic Content** (تحدي الذكاء الاصطناعي في خدمة المحتوى الإسلامي — مؤسسة باذل الأهلية), **Track 1: Knowledge Dialogue & Reliable Answers** (الحوار المعرفي والإجابات الموثوقة).

---

## The problem

A new Muslim's first months are full of small, anxious questions. Answers come from forums, relatives and general-purpose chatbots that mix **religion with culture** ("you must take an Arabic name"), state **disputed matters as settled**, give **personal fatwas** without knowing the facts, and occasionally **invent hadith**. The challenge names these exact risks: hallucination, missing references, and automated rulings.

## The solution

| | |
|---|---|
| **Live answers that read the tafsir** | Every question typed in the Ask tab gets a **live** answer. The model (**Gemini** or **Claude** — one setting) researches it with three tools: `search_quran` (the whole Quran, King Fahd Complex text), `read_tafsir` (the verse's exact text + **Tafsir al-Tabari**, an early-centuries source as the reference pack requires) and `submit_answer`. It must read a verse's tafsir before it may cite it, and the tafsir decides whether the verse really fits. |
| **Stored answers stay** | 24 curated Q&As across 7 categories remain for browsing (Explore tab, categories, "most asked"), and serve as reference answers the model builds on. |
| **Card-shaped answers** | 🟨 **الأصل الشرعي** (Islamic principle) · 🟩 **العرف والثقافة** (culture vs. religion) · 🟦 **الإرشاد العملي** (practical next steps) · ⬜ **الأدلة** (verse in Quran script + al-Tabari's own statement of its meaning + "why this verse" + links to verify the verse, to read al-Tabari in full and to the surah in Dorar's tafsir encyclopedia) — plus 🟪 **مسألة خلافية** (scholarly difference, no preference), 🟥 **يحتاج إلى مختص** (referral), ⬛ **لا تتوفر إجابة موثقة** (abstention), 🔘 **خارج نطاق بصيرة** (not about Islam). |
| **Arabic and English** | A language switch (home screen, library, welcome screen, or a `?lang=en` link) changes the whole interface. The **answer always comes in the language of the question**: an English question gets English cards, with the verse still shown in Quran script and its meaning from the Hilali & Khan translation published by the King Fahd Complex, labelled as a translation of the meaning. |
| **Questions about Islam only** | Questions that are clearly not about Islam — food recommendations, prices, sport, technology, the beliefs and festivals of other religions — get a short «خارج نطاق بصيرة / Outside Basirah's scope» card instead of an answer, both on the device and on the server (the model is not called). A question about what Islam says on the same topic stays in scope: *"Is sushi halal?"*, *"Can I attend my Christian family's dinner?"*. Follow-ups («وماذا عن أمي؟») are judged with the previous question. |
| **The four levels (أ/ب/ج/د)** | Every answer carries the reference pack's content level and is handled exactly as that level prescribes. |
| **Deterministic guard** | After the model: a verse is shown only if it exists **and its tafsir was read in this run**, and its text always comes from the dataset, never from the model; hadith only from the verified registry; any ﴿…﴾ quotation that is not verbatim Quran is removed; ungrounded or low-confidence answers → abstain; level D → refer. Before the model: an on-device router detects personal cases, hadith-production requests and hostile tone. |
| **Honest fallback** | Without a server or key, or if the AI is down, the app shows the stored answer (or a referral/abstention) and says clearly that it is not a live answer. It never shows an unguarded answer. |
| **Transparency & privacy** | Every answer shows its origin (live AI / stored), review status, and a research trail («كيف وصلت بصيرة إلى الأدلة؟»). The mufassir's words and the AI's explanation are labelled separately from the Quran text. No login; the server never logs question text; bookmarks stay on the device. |

## Design

A calm, light interface in the spirit of the **Nusuk** app: soft grey canvas, a warm sand glow at the top of each screen, white rounded cards with pastel icon bubbles, ink-black primary buttons, amber highlights, and a white bottom bar with glyph tabs that fill with amber plus a «بصيرة AI •••» pill. Categories use the same visual language as the answer cards: a soft two-colour wash in the category's own hue (gold, green, blue, purple, teal, pink, coral), a faint eight-pointed-star lattice in the corner, and the category's icon in a white bubble — calm, readable, never glossy. The answer cards stay **colour-coded** (gold, green, blue, purple, rose, stone) as soft pastel cards with saturated accents. Typography: IBM Plex Sans Arabic (UI), Reem Kufi (wordmark), Amiri Quran (verses), Amiri (hadith). Full RTL in Arabic, LTR in English.

**Logo:** a four-point sparkle with two small companions, drawn from geometry in one flat gold (no shading): `BrandMarkPainter` in the app, and `tool/make_logo.ps1` for every icon (the app-icon tile is the gold mark on a dark rounded square — web loading screen, favicon, installable-web-app icons, Android launcher). **On a computer** the web app is shown inside an iPhone 15 Pro frame (393 × 852 pt screen, Dynamic Island, status bar, home indicator, iOS safe areas) that scales to the window; on a phone it is full-screen.

## Repository layout

```
basirah/
├── assets/kb/               ← the knowledge base (shared by app and API)
│   ├── faqs.json            24 curated, card-shaped answers
│   ├── evidence.json        52 verbatim verses/hadith with source & grade
│   ├── categories.json      7 categories
│   └── reference.json       levels, approved sources, standards, glossary
├── packages/basirah_core/   ← pure Dart: models, Arabic retrieval, safety router
├── server/                  ← Dart API: live research agent + guard (keeps the API key off the client)
│   ├── data/quran.json      Quran text + search index data (built on first start; gitignored)
│   └── tool/                fetch_quran, verify_registry, try_search, try_tafsir
├── lib/                     ← Flutter app (web + Android)
├── eval/test_cases.json     ← 12 official test cases + 10 team cases
└── docs/                    ← architecture, content review, sources & licences
```

## Going live (the AI chatbot)

The chatbot calls a real model; it only needs **one** key, in `server/.env` (gitignored — never commit it or paste it anywhere).

1. **Gemini (free tier):** create a key at <https://aistudio.google.com/apikey> and set `GEMINI_API_KEY=...`. Google states that free-tier content may be used to improve its products (the app already tells users not to share personal data).
   **or Claude (paid credits):** create a key at <https://platform.claude.com> → API Keys and set `ANTHROPIC_API_KEY=...`.
2. If both keys are set, `AI_PROVIDER=gemini|claude` chooses. Models: `GEMINI_MODEL`, `CLAUDE_MODEL` (default `claude-sonnet-5`).
   The Gemini free tier allows only a few requests **per model per day** (20 for `gemini-3.8-flash` when tested on 27 Sept 2026; one answer takes 1–4 requests). List several models, comma-separated, and Basirah moves to the next one when a model's daily quota runs out, e.g. `GEMINI_MODEL=gemini-3.8-flash,gemini-3.7-flash,gemini-3.6-flash,gemini-3.5-flash`. `dart run tool/gemini_models.dart` lists the models a key can use; `dart run tool/ask.dart "<question>"` asks one question live.
3. Run `powershell -ExecutionPolicy Bypass -File run_local.ps1` — it starts the API (downloading the Quran dataset once, ~15 s) and opens the app in Chrome. The Ask tab header turns green: «إجابات حية · تقرأ التفسير وتختار الآية المناسبة».

Each live answer is 3–5 model calls (search → read tafsir → submit), typically 20–60 s at `CLAUDE_EFFORT=high`; `medium` is faster. The system prompt and tools are prompt-cached. Follow-up questions work: the app sends the last four exchanges, so «وماذا عن أمي تحديداً؟» is understood in context.

## Run it

Requirements: Flutter 3.41+ (Dart 3.11+).

```bash
# 1) Tests (no network, no API key)
cd packages/basirah_core && dart pub get && dart test     # 57 tests: KB integrity, Arabic NLP, router, eval set
cd ../../server         && dart pub get && dart test     # 20 tests: guard, Quran search, scripted research loop
dart run bin/eval.dart                                    # 22/22 eval cases (offline mode)

# 2) API (optional — without a key it serves curated + offline answers)
export ANTHROPIC_API_KEY=sk-ant-...        # never commit this
dart run bin/server.dart                   # http://localhost:8080  (GET /health, POST /api/ask)
dart run bin/eval.dart --ai                # the eval set answered live (costs API credits)
dart run tool/verify_registry.dart          # check curated verses against the King Fahd text

# 3) App
cd ..
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
# or fully offline:
flutter run -d chrome
```

### Deploy

* **API → Render** (free): `render.yaml` + `server/Dockerfile`. Set `ANTHROPIC_API_KEY` in the dashboard.
* **Web → Netlify / Cloudflare Pages**: `flutter build web --release --dart-define=API_BASE=https://<your-api>.onrender.com`, then publish `build/web`.
* **Android**: `flutter build apk --release --dart-define=API_BASE=https://<your-api>`.

Environment variables for the API: `ANTHROPIC_API_KEY`, `CLAUDE_MODEL` (default `claude-opus-5`), `CLAUDE_EFFORT` (default `high`), `CLAUDE_FALLBACKS` (`default`|`off`), `ANTHROPIC_BASE_URL`, `QURAN_FILE`, `ALLOWED_ORIGIN`, `PORT`, `KB_DIR`.

## How an answer is produced

```
question ─► ScopeCheck (clearly not about Islam? ─► «outside Basirah's scope», no model call)
         ─► SafetySignals (personal case? hadith request? hostile? translation?)
         ─► Retriever over the 24 reference answers (hints for the model)
         ─► research loop on Gemini or Claude (manual tool loop, raw HTTP)
               search_quran ─► BM25 over the Quran (stems + char 4-grams; a plain-language
                               gloss of each verse is indexed too, never shown or cited)
               read_tafsir  ─► exact verse + Tafsir al-Tabari (live, cached)
               submit_answer (strict schema)
         ─► Guard: verse exists & tafsir was read · text from dataset · hadith ∈ registry
                   · ﴿quotes﴾ verified · level D → refer · ungrounded/low confidence → abstain
         └─ no server / no key / API error ──► stored answer or refer/abstain (labelled "not live")
```

Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Evaluation

`eval/test_cases.json` contains the **12 official test situations** from the reference pack (Kaaba worship, authorship of the Quran, "spread by the sword", scholarly difference, a personal marriage case in Germany, a request to produce a hadith, explaining Tawhid, translating Tawhid, a hostile question about alcohol, "do all Muslims agree", a misquoted verse, the meaning of Sharia) plus 10 team cases and 4 scope cases (a sushi restaurant and a question about karma are declined; "Is sushi halal?" and an English question are answered). The offline pipeline passes **26/26**; `dart run bin/eval.dart --ai --out ../eval/report.json` runs the same set through the configured model (Gemini or Claude) and saves every answer for review.

## Content status — please read

All curated content was **authored from the approved references** but is marked **`pending`** until the team's Sharia specialist reviews it.

* **Quran text: verified automatically.** `tool/verify_registry.dart` checks all 35 curated verses against the King Fahd Complex text — **35/35 match**. Live answers take verse text from the same dataset, never from the model.
* **Hadith, grades and explanations: still need a specialist** (dorar.net for every hadith and grade). See [docs/CONTENT_REVIEW.md](docs/CONTENT_REVIEW.md).

## Limitations

* The curated base is an MVP (24 entries); coverage grows by adding reviewed entries, not by loosening the guard.
* Live answers need the server and an API key; without them the app shows stored answers and says so.
* On the Gemini free tier, daily per-model quotas limit live answers to a few dozen questions a day even with several models in the chain; beyond that the app shows stored answers with the "busy" notice. A paid tier removes the limit.
* When there is no reliable answer, the card shows no verse and no hadith — only the reason and what to do next.
* English meanings of hadith and of the curated explanations are the team's own translation and are **pending Sharia review**, like the Arabic content; English verse meanings come from the King Fahd Complex (Hilali & Khan).
* The off-topic check is deliberately conservative: anything with an Islamic cue or asking for a ruling is kept in scope, so an odd question may reach the model, which can also decline it as off-topic.
* Hadith can only be cited from the 17-item verified registry (dorar.net blocks automated access, so hadith are not fetched live).
* Quran search is lexical (stems + 4-grams over the verse text and a plain-language gloss of it — al-Tafsir al-Muyassar, used **only** as a search index: never shown, cited or given to the model); the model compensates by trying several wordings and reading verses it expects, and every citation is checked against the al-Tabari text it read.
* The app links each verse to its surah in Dorar's tafsir encyclopedia (dorar.net/tafseer), not to the exact passage: Dorar's pages are organised by passage and it blocks automated access, so passage numbers cannot be computed.
* Basirah is an AI tool, not a mufti.

## Documentation map (what the participant guide asks for)

| Guide requirement | Where |
|---|---|
| p. 32 #06 «توثيق الفكرة والإعداد والتشغيل والاعتمادات، وإرفاق سجل المصادر والأدوات والتراخيص» | this README + [docs/SOURCES_AND_LICENSES.md](docs/SOURCES_AND_LICENSES.md) |
| p. 32 #04 «تراخيص المكونات وحقوق أصحابها» | [docs/SOURCES_AND_LICENSES.md](docs/SOURCES_AND_LICENSES.md) |
| p. 14 #05 «توثيق المحتوى والمصادر الشرعية والمعرفية وكيفية استخدامها والتحقق منها» | [docs/SOURCES_AND_LICENSES.md](docs/SOURCES_AND_LICENSES.md), [docs/CONTENT_REVIEW.md](docs/CONTENT_REVIEW.md) |
| p. 21 criterion 4 «…اختبارات محددة ومراجعة بشرية عند الحاجة» | [eval/test_cases.json](eval/test_cases.json), [docs/CONTENT_REVIEW.md](docs/CONTENT_REVIEW.md) |
| p. 31 #06 «شرح التقنية» (for the presentation) | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| p. 43 FAQ «توثيق نسخة البداية والإفصاح عن الحقوق» | [docs/STARTING_VERSION.md](docs/STARTING_VERSION.md) |

Code: MIT. No real user data is used anywhere.
