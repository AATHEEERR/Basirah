# Sources & licences registry

## Religious content

| Content | Source (per the challenge reference pack) | Use in Basirah |
|---|---|---|
| Quran text | King Fahd Complex Mushaf (KFGQPC Uthmani Hafs), obtained through the Quran.com API v4 (`text_uthmani`, `text_imlaei`); verification links to quranpedia.net | Full text in `server/data/quran.json` (built at start-up, not redistributed in the repo) for search and for every verse shown in live answers; short excerpts in `evidence.json`, all 35 verified against it by `tool/verify_registry.dart` |
| Search index (not a cited source) | **التفسير الميسر** — King Fahd Complex for the Printing of the Holy Quran, via the Quran.com API (tafsir id 16) | Used **only** to index verses for search (a plain-language gloss that helps find a verse from a concept). Never shown to users, never cited, never given to the model |
| Tafsir | **تفسير الطبري** (Jāmiʿ al-Bayān, al-Tabari 224–310 AH, written in the 3rd century AH — the reference pack: «أي مصادر إسلامية في القرون الثلاثة الأولى أو منصة dorar.net/tafseer»), via the Quran.com API (tafsir id 15); and **dorar.net/tafseer** (موسوعة التفسير) | Al-Tabari: read by the model before citing a verse; his own statement of the verse's meaning shown verbatim under it; linked in full (quran.com). Dorar: every cited verse links to its surah page |
| Quran — English meaning | **The Noble Quran** — translation of the meanings by Dr. Muhammad Taqi-ud-Din al-Hilali & Dr. Muhammad Muhsin Khan, **King Fahd Complex** (Quran.com API translation id 203) | English interface only: shown under the Arabic verse, labelled «translation of the meaning»; the Arabic text remains the evidence |
| English interface text | Team translation (`assets/kb/en.json`) of the curated answers, category texts, glossary rules, levels and standards; hadith meanings translated by the team | Labelled «Translation of the meaning — Basirah team, pending Sharia review» under each hadith; pending review like the Arabic content |
| Hadith | Sahih al-Bukhari, Sahih Muslim; Jami' al-Tirmidhi / Sunan Abi Dawud / al-Nasa'i with grade; verification via dorar.net/hadith, shamela.ws | Short verbatim excerpts with source number and grade |
| Creed, fiqh, tafsir, history | dorar.net (aqeeda, feqhia, tafseer, history) and classical sources | Informs the curated explanations (paraphrased, not copied) |
| Da'wah topics, FAQ, doubts | dawa.center (incl. «بيّنات» file 7937), islamic-content.com | Informs the curated explanations |
| Terminology | Challenge glossary; islamic-content.com/dictionary (الجمهرة) | `reference.json` glossary |
| Levels, standards, test cases | «المرجعية والحزمة العلمية والبيانات» (v. 20/3/1448) | `reference.json`, `eval/test_cases.json` |

Quran and hadith texts are in the public domain as scripture; excerpts are short and attributed. The Quran.com API is used as a free public API with attribution; the full dataset is downloaded by each deployment rather than committed. The reference pack names dorar.net/tafseer as an approved tafsir platform; it blocks automated access, so its text cannot be read by the model — the app links to it instead, and the model reads al-Tabari (an early-centuries source, the pack's other option). Curated explanations are original writing by the team. **All content is pending Sharia review** (see CONTENT_REVIEW.md).

## Software

| Component | Licence |
|---|---|
| Flutter, Dart SDK | BSD-3-Clause |
| flutter_riverpod, riverpod | MIT |
| go_router, shared_preferences, url_launcher, http, intl, shelf, shelf_router, test | BSD-3-Clause |
| google_fonts (package) | Apache-2.0 |
| Fonts: Reem Kufi, IBM Plex Sans Arabic, Amiri | SIL Open Font License 1.1 |
| Font for the verses: KFGQPC Hafs V30 (King Fahd Glorious Qur'an Printing Complex, fonts.qurancomplex.gov.sa), bundled unmodified in `assets/fonts/` | Free to use, copy and distribute; not to be sold or modified. © KFGQPC |
| Logo | Drawn by the team from geometry (`lib/shared/brand.dart`, `tool/make_logo.ps1`) — no third-party artwork |
| Inter (status-bar clock in the desktop iPhone frame) | SIL Open Font License 1.1 |
| Claude API (Anthropic) — `claude-sonnet-5` by default | Commercial API, used under Anthropic's terms; key held server-side only |
| Gemini API (Google) — free tier or paid | Used under Google's Gemini API terms; key held server-side only. On the free tier Google may use submitted content to improve its products |

## Tools used to build the project

| Tool | Use |
|---|---|
| Claude Code (Anthropic) | AI coding assistant used to write code, the knowledge-base drafts and documentation, under the team's direction |
| Flutter / Dart toolchain | Build, test, analysis |

Disclosed per the guide's requirement to attach «سجل المصادر والأدوات والتراخيص» and to disclose rights for work that predates the challenge (see STARTING_VERSION.md).

## Data

No real user data, conversations or personal information are used. Evaluation questions are the challenge's published test situations and synthetic team questions.

## Project licence

MIT — see `LICENSE`.
