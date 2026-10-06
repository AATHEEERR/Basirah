# بصيرة · Basirah

> «قُلْ هَٰذِهِ سَبِيلِي أَدْعُو إِلَى اللَّهِ ۚ عَلَىٰ بَصِيرَةٍ» — يوسف: 108

**Basirah** answers the questions of people in their first year of Islam, in their own language, **only from approved references**. Every answer separates what Islam teaches from what is culture, shows its evidence with a way to check it, refers personal cases to a scholar, and says so plainly when there is no documented answer.

## How an answer is made

```
question ─► language: Arabic and English use the curated knowledge base; any other
             language is answered in that language, with approved translations
         ─► scope check (not about Islam? polite refusal, no model call)
         ─► safety signals (personal case, request to produce a hadith, hostile tone)
         ─► research by the model, with tools only:
               search_quran   the whole Quran (King Fahd Complex Mushaf text)
               read_tafsir    the verse's tafsir in Dorar's tafsir encyclopedia
               search_hadith  graded hadith from HadeethEnc (the association's MCP server)
               submit_answer  a strict schema
         ─► guard: a verse is shown only if its tafsir was read, and its text comes from
                   the Mushaf dataset, never from the model; hadith only with source and
                   an accepted grading; level D → referral; no evidence → abstention
```

The model chooses a verse by its number only; its text is copied from the Mushaf.

## Features

* Colour-coded answer cards: principle, culture, practical guidance, evidence; scholarly difference, referral and abstention cards.
* «سياقي»: optional, on-device context (who is asking, since when, answer style) that adapts the explanation, never the ruling.
* Ask in your language: the answer is written in it, and each cited verse shows QuranEnc's approved translation of its meaning in that language (25 languages) and each HadeethEnc hadith its approved translation when there is one. `server/bin/languages_eval.dart` checks this on the test questions ([eval/LANGUAGES_REPORT.md](eval/LANGUAGES_REPORT.md)).
* The interface in 26 languages: Arabic and English written by the team, the other 24 (the languages of QuranEnc's approved translations) machine-translated with Claude by `server/tool/translate_ui.dart` from the strings `server/tool/extract_ui_strings.dart` finds in the code; every translation is checked to keep its value slots, and anything missing stays in English. They are not yet human-reviewed. The reviewed answers stay in Arabic and English.
* Verse recitation by real reciters (repeat, slower speed), and «اسمعها بلغتك»: the approved translation of the meaning in 25 languages, 13 of them in a recorded voice, with the association's own introductions to Islam on IslamHouse in that language (through its MCP server).
* A partly cited verse is shown whole, with the cited words highlighted; every verse links to its own page on QuranEnc.
* Clarifying questions: when the answer in the sources depends on a detail the asker did not give, Basirah asks one short question back with options to tap (at most two), then answers that case with its evidence. A personal case or fatwa request is never clarified: it is referred to a Sharia specialist at once. The guard enforces both.
* When the AI is unavailable or too slow, the stored documented answer (or a referral or abstention) is chosen by fixed rules in code and shown with a notice; the knowledge base works in the app without the server.
* «تحدّث مع مختص شرعي»: under a scholarly difference or a referral, the asker sends their question and conversation (only what they approve) as a message, or books a voice or video call; specialists reply from a panel (`/#/specialist`, each specialist signs in with a username and password the team made: `server/tool/specialist_account.dart`, stored as `SPECIALIST_ACCOUNTS`; there is no sign-up). Requests are deleted after 30 days.
* «إيصال بصيرة»: under each answer, the checks that ran, what the guard removed and why, and the research steps.
* A share card with the Mushaf text and a QR code to the verse's own page.
* Anonymous ratings and an impact board (counts only; no question text, IP or user id is stored).
* The baseline comparison in the app: the same model as a general chatbot and inside Basirah, on the same 31 questions ([eval/BASELINE_COMPARISON.md](eval/BASELINE_COMPARISON.md)).

## Run it

Requirements: Flutter 3.41.9 (Dart 3.11.5). Put the AI key(s) in `server/.env` (copy `server/.env.example`; never commit it).

```powershell
cd server; dart pub get; dart test; cd ..          # server tests
flutter pub get; flutter test                       # app tests
powershell -ExecutionPolicy Bypass -File tool\start_live.ps1   # build, serve, public link
```

`server/bin/eval.dart` runs the evaluation set; `server/bin/baseline.dart` compares Basirah with a general chatbot on the same model.

Deploy: `render.yaml` (one service: the API and the web app), built by the root `Dockerfile`; build the web app first with `tool\build_web_for_deploy.ps1`. Restore and backup: [docs/RESTORE.md](docs/RESTORE.md).

## Sources

Quran text and approved translations of the meanings: QuranEnc and Quranpedia. Tafsir: dorar.net/tafseer. Hadith: HadeethEnc (graded), verified on dorar.net. Recitation and the IslamHouse library: the association's MCP server. Details and licences: [docs/SOURCES_AND_LICENSES.md](docs/SOURCES_AND_LICENSES.md).

Basirah is an AI tool, not a mufti. Code: MIT.
