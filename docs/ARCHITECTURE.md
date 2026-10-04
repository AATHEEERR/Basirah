# Architecture

## Components

| Component | Tech | Role |
|---|---|---|
| `packages/basirah_core` | Pure Dart | Knowledge-base models, Arabic normalisation/stemming, retriever, safety signals, offline router. Shared by app and API so both apply identical rules. |
| `server/` | Dart + shelf | `POST /api/ask`, `GET /health`. Holds the Anthropic API key, runs the live research agent and the guard, serves the Quran dataset (`data/quran.json`, built on first start) and the al-Tabari cache, rate-limits, logs metadata only. |
| `lib/` | Flutter (web + Android), Riverpod, go_router | UI, on-device routing, bookmarks (device-local). |
| `assets/kb/` | JSON | The single source of truth for content. Bundled into the app and loaded by the API. |

## Languages

* The app's interface language (`langProvider`, remembered on the device, or `?lang=en|ar` in the link) switches every screen; English runs left-to-right.
* The **answer language follows the question** (`questionLang`): an English question is routed with the English knowledge base (`KnowledgeBase.localized('en')`, which overlays `assets/kb/en.json` on the Arabic master without changing ids, levels or evidence) and the model is told to answer in English.
* Evidence stays Arabic. In English, a verse card adds the King Fahd Complex English meaning (Hilali & Khan) and a hadith card adds the team's translation — each labelled as a translation of the meaning.
* A test (`missingEnglish()`) fails if any curated item lacks its English overlay.

## Scope: questions about Islam only

`ScopeCheck.clearlyOffTopic` (in `basirah_core`, so app and server agree) declines a question when it has **no Islamic cue and asks for no ruling**, and either nothing in the curated base resembles it, or it is about another religion's teachings without a personal-life context («عائلتي»، "my family"). The check runs on the question plus the previous question, so follow-ups stay in scope. Declined questions get the `offTopic` card (no level, no evidence) and **never reach the model**; the model itself may also return `offTopic`, which the guard passes through with no citations.

## Response levels → behaviour

| Level | Reference pack handling | Basirah |
|---|---|---|
| **A** original, settled | Direct documented answer | `answer` card set with verbatim evidence |
| **B** explanation, argument | Answer from approved material, show reference, avoid categorical wording on disputable points | `answer` card set |
| **C** disputed / sensitive | Constrained answer, or declare the difference, or refer | `khilaf` card: what is agreed + declaration of difference, **no preference** |
| **D** fatwa / personal case | No independent ruling; general info + referral | `refer` card with who to contact |
| — no grounding | Abstain / refer rather than generate | `abstain` card |
| — not about Islam | (outside the track's scope) | `offTopic` card, no model call |

## Retrieval over the reference answers (on-device and server)

1. **Normalise**: strip tashkeel/tatweel, unify أ/إ/آ→ا, ى→ي, ة→ه, ؤ/ئ, remove punctuation.
2. **Tokenise**: drop stop words (Arabic particles and generic question verbs), light stemming (ال/وال/بال…, ـها/ـهم/ـات/ـون/ـين…, and the ـت of «صلاتي» so it meets «الصلاة»), English→Arabic bridge for common words.
3. **Score** each entry: IDF-weighted coverage of the query terms (question/variants ×1, tags ×0.8, answer body ×0.35) × 0.62 + character-trigram Dice similarity × 0.38.
4. **Decide**: strong if score ≥ 0.56, or ≥ 0.40 with a ≥ 0.18 margin over the runner-up. Thresholds are tuned on `eval/test_cases.json` (true matches ≥ 0.44 with margin ≥ 0.23; misses ≤ 0.28).

## The live research loop (`server/lib/src/agent.dart`)

Every question typed in the Ask tab is answered live (`mode: "live"`). A manual tool loop over raw HTTP, at most 6 rounds. The model is behind one interface (`LlmClient`, `lib/src/llm.dart`): `ClaudeClient` (Messages API) or `GeminiClient` (`generateContent`), chosen in `server/.env` (`lib/src/providers.dart`). The conversation is kept in the Messages format; `GeminiClient` translates tools to `functionDeclarations` (`parametersJsonSchema`), tool results to `functionResponse` parts, and sends Gemini's own parts back verbatim so its thought signatures are preserved. Free-tier rate limits (HTTP 429) are retried after the delay Google asks for. The Gemini free tier also caps requests **per model per day** (observed on 27 Sept 2026: `limit: 20` for `gemini-3.8-flash`); `GEMINI_MODEL` may list several models, and when one reports its daily quota exhausted the pipeline asks the question again, from the start, on the next model, skipping the exhausted one until midnight Pacific time. When every model is out of quota, the stored answer is shown with the "busy" notice.

| Tool | What it does |
|---|---|
| `search_quran {query}` | BM25 over all 6,236 verses — the verse text **and a plain-language gloss of it** (al-Tafsir al-Muyassar), indexed both by light stems and by character 4-grams (robust to Arabic clitics), plus an exact-phrase boost. The gloss lets a concept («زيارة الأهل غير المسلمين») reach the verse that expresses it in Quranic wording. It is a **search index only**: results return the verse text alone, and al-Muyassar is never shown, cited or given to the model. Returns up to 8 candidates. |
| `read_tafsir {refs ≤ 3}` | Exact verse (KFGQPC Uthmani) + the opening ~3,500 characters of **Tafsir al-Tabari** (fetched per verse from the Quran.com API, cached in memory and on disk). Records the verse as **read** — only when al-Tabari was actually available. |
| `submit_answer` (`strict: true`) | The cards: kind, level, confidence, texts, `quran: [{ref, why}]`, `hadithIds` (enum of the registry), `basedOnEntries` (enum of reference answers). |

Request details (Claude; Gemini receives the same system prompt as `systemInstruction`, the tools as function declarations with `mode: AUTO`):
* `model: claude-sonnet-5` (configurable), `output_config: {effort: "high"}`, adaptive thinking (the model's default), `tool_choice: auto`.
* `system`: behaviour rules + levels + glossary + the 24 reference answers + the hadith registry, with `cache_control: ephemeral`; tools render before it, so tools + system are cached across rounds and questions.
* Each assistant turn is appended **unchanged** (thinking blocks included) before the `tool_result` user turn; all results of a turn go back in one message.
* `fallbacks: "default"` with `anthropic-beta: server-side-fallback-2026-07-01`: if a safety classifier declines, the API retries on Anthropic's recommended model; a final `stop_reason: "refusal"` → abstain.
* A turn that ends in plain text is nudged once to call `submit_answer`; in the last rounds a "budget reached" note is appended. `max_tokens` truncation or no submission → offline fallback.

## The guard (`server/lib/src/guard.dart`)

Runs on every submission, deterministically:

1. **Quran:** keep a verse only if it exists **and** its al-Tabari tafsir was read with `read_tafsir` in this run; its text and surah name are taken from the dataset (never from the model). Under it the app shows al-Tabari's own statement of the meaning, verbatim (the paragraph before his chains of narration, `tabariSummary`), labelled «تفسير الطبري (ت 310هـ) — مقتطف», with links to al-Tabari in full and to the surah on dorar.net/tafseer. The model's `why` is shown labelled as AI-written. At most 3 verses.
2. **Hadith:** only ids in the verified registry, each submitted with the model's one-sentence reason (the point it supports), which the app shows labelled as AI-written. A hadith without a reason is dropped — this keeps loosely related citations out.
3. No verse wording typed by the model reaches the prose: a quotation in `﴿…﴾` or `«…»` whose words belong to exactly one verse is replaced by its reference, e.g. «(البقرة: 256)»; any other `﴿…﴾` is removed, and other `«…»` text is unquoted unless it is hadith text from the registry. Verse text appears only in the evidence cards, copied from the Mushaf dataset.
4. Level D → `refer`; personal-case signal + `answer` without curated backing → `refer`.
5. `answer` with no evidence and no reference answer, or with `confidence: low` → `abstain`. **An abstention carries no evidence** — any verse or hadith the model cited is dropped (and logged), and the offline router's abstentions cite nothing either: a verse next to "no reliable answer" would look like support for an answer that was not given.
6. Fill required card fields for the final kind; clear the rest. A referral (`refer`) cites nothing either, and a scholarly-difference answer is always level C.

Before the guard, the agent checks the **answer language**: every question carries `<answer_language>` (the question's language), and a submission written in the other language is sent back once to be rewritten. The server also **pre-reads al-Tabari** for the verses of the reference answer the question clearly matches (the same bar as a stored answer), so most answers need one model request; a loose match pre-reads nothing, so unrelated verses are never put in front of the model.

## Privacy

* No accounts, no analytics SDKs.
* Server logs: timestamp, route taken, kind, level, matched entry id, latency, guard actions, cache-read tokens. **Never the question text.**
* Bookmarks live in the browser/device (`shared_preferences`).

## Failure modes

| Failure | Behaviour |
|---|---|
| No API configured, or server without a key | App shows the stored answer (or refer / abstain) and labels it "not live". |
| API unreachable, 5xx, 429 | App shows the on-device result with a notice. |
| Model error / overload / Gemini quota exhausted | Server returns the offline router's verdict (`notice: ai_busy`). |
| Claude refusal, or Gemini `SAFETY` / `RECITATION` stop | `abstain`. |
| Truncation / no submission | Offline verdict. |
| al-Tabari unavailable for a verse | The model is told not to cite it, and the guard drops it if it does. |
