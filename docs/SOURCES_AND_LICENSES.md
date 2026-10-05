# Sources & licences registry

## Religious content

| Content | Source | Use in Basirah |
|---|---|---|
| Quran text | King Fahd Complex Mushaf (Uthmani Hafs) as published by **QuranEnc** (موسوعة القرآن الكريم, `arabic_text`) with surah names and the simple-script text from **Quranpedia** | `server/data/quran.json`, built by `server/tool/fetch_quran.dart` (not committed). Verse cards always copy their text from it |
| Search index (not a cited source) | **التفسير الميسر** (King Fahd Complex) via QuranEnc (`arabic_moyassar`) | Used **only** to index verses for search; never shown, cited or given to the model |
| Tafsir | **موسوعة التفسير — الدرر السنية** (dorar.net/tafseer) | The model reads a verse's explanation before it may cite it; the card shows Dorar's own explanation and links to the exact passage |
| Quran — English meaning | **The Noble Quran**, al-Hilali & Khan, King Fahd Complex, via QuranEnc (`english_hilali_khan`) | Shown under the verse in English answers, labelled as a translation of the meaning |
| Approved translations of the meanings, text and voice | **QuranEnc**, 25 languages. With a recorded voice (13): `english_rwwad`, `tagalog_rwwad`, `french_rashid`, `chinese_suliman`, `vietnamese_rwwad`, `sinhalese_mahir`, `tamil_omar_brief`, `somali_yacob`, `persian_ih`, `portuguese_nasr`, `dutch_center`, `azeri_musayev`, `assamese_rafeeq`. Text only (12, no recording on QuranEnc): `urdu_junagarhi`, `indonesian_complex`, `turkish_rwwad`, `spanish_garcia`, `german_bubenheim`, `hindi_omari`, `swahili_rwwad`, `hausa_gummi`, `bosnian_rwwad`, `albanian_rwwad`, `pashto_rwwad`, `japanese_saeedsato` | «اسمعها بلغتك», and the meaning of each cited verse in an answer written in that language: the text from the QuranEnc API and the audio from d.quranenc.com, unmodified (only a leading verse number and footnote markers are removed from the text) |
| Hadith (live) | **HadeethEnc** (موسوعة الأحاديث النبوية), searched through the association's MCP server (mcp.islamiccontent.org), details from the HadeethEnc API | Text, source, grading, explanation and approved translation as published (in the asker's language when HadeethEnc has it); only accepted gradings (صحيح/حسن) |
| Hadith (curated) | Sahih al-Bukhari, Sahih Muslim and the Sunan with grading; verification on dorar.net/hadith | Short verbatim excerpts with source number and grading |
| Recitation | Per-verse MP3s through the association's MCP server (`get_quran_audio`) | Played as published; only the cited verses |
| Further reading | **IslamHouse** (دار الإسلام): the association scientific team's own publications in the asker's language, through the association's MCP server (`browse_library`), and the per-language library page | Titles and links as published, opened on islamcontent.com / islamhouse.com |
| Fiqh («مرشد الحالة», ghusl and wudu) | **الموسوعة الفقهية — الدرر السنية** (dorar.net/feqhia), pages 397, 399, 422, 424, 446, 466, 471, 477, 479 | Each answer copied verbatim from the page's own question-and-answer summary by `server/tool/build_guides.dart`, with its link. Consensus or the agreement of the four schools → the answer is given; a stated difference → the views are quoted and the asker gets a case file for a Sharia specialist. English: the team's summary, labelled |
| Creed, fiqh, history, FAQ | dorar.net, dawa.center, islamic-content.com | Informs the curated explanations (paraphrased, not copied) |
| Terminology | islamic-content.com/dictionary (الجمهرة) and the approved glossary | `reference.json` glossary |
| Levels, standards, test cases | The approved reference document | `reference.json`, `eval/test_cases.json` |

Quran and hadith texts are scripture; excerpts are short and attributed, and every one links to the platform where it can be checked. Curated explanations are original writing by the team. **All curated content is pending human review** (see CONTENT_REVIEW.md).

## Software

| Component | Licence |
|---|---|
| Flutter, Dart SDK | BSD-3-Clause |
| flutter_riverpod, riverpod | MIT |
| go_router, shared_preferences, url_launcher, http, intl, shelf, shelf_router, test, web | BSD-3-Clause |
| just_audio | MIT |
| qr_flutter, qr | BSD-3-Clause |
| google_fonts (package) | Apache-2.0 |
| Fonts: Reem Kufi, IBM Plex Sans Arabic, Amiri | SIL Open Font License 1.1 |
| Font for the verses: KFGQPC Hafs V30 (King Fahd Glorious Qur'an Printing Complex, fonts.qurancomplex.gov.sa), bundled unmodified in `assets/fonts/` | Free to use, copy and distribute; not to be sold or modified. © KFGQPC |
| Logo | Drawn by the team from geometry (`lib/shared/brand.dart`, `tool/make_logo.ps1`); no third-party artwork |
| Claude API (Anthropic): Sonnet 5.5, then Haiku 4.5 | Commercial API, used under Anthropic's terms; key held server-side only |
| Gemini API (Google): last fallback | Used under Google's Gemini API terms; key held server-side only. On the free tier Google may use submitted content to improve its products |
| cloudflared (Cloudflare) | Apache-2.0; used only to open a temporary public link, not part of the app |
| Jitsi Meet (meet.jit.si, 8x8) | Free public service; a booked call with a specialist opens in a private room there, in the browser. Not embedded; Basirah sends it nothing |

## Tools used to build the project

| Tool | Use |
|---|---|
| Claude Code (Anthropic) | AI coding assistant used to write code, the knowledge-base drafts and documentation, under the team's direction |
| Flutter / Dart toolchain | Build, test, analysis |

## Data

No personal information is used. A request to a Sharia specialist holds only what the asker approved before sending, and is deleted after 30 days. Evaluation questions are the reference document's published test situations and synthetic team questions. The impact board stores counts only: no question text, IP address or user id.

## Project licence

MIT — see `LICENSE`.
