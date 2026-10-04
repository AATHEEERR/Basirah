# Starting version (نسخة البداية)

The participant guide (FAQ, p. 43) allows using an earlier project «مع توثيق نسخة البداية والإفصاح عن الحقوق، ويُقيَّم ما أُنجز من 4 إلى 6 أكتوبر فقط».

This file records what existed **before** the challenge window (4–6 October 2026), so the judges can see what was built during it.

## Baseline (fill in before 4 October)

* Date / git tag of the baseline: `__________` (e.g. `v0-baseline`, commit `______`)
* Built with: Flutter, Dart, the Claude API, Claude Code (AI coding assistant)
* Rights: all code and curated text are the team's own work; third-party components under their licences (see SOURCES_AND_LICENSES.md)

## What the baseline contains

* App shell, theme, category/answer/ask/library screens
* Shared core: Arabic retrieval, safety signals, offline router
* API: Claude integration, guard, rate limiting
* Knowledge base draft: 24 entries, evidence registry — **not yet Sharia-reviewed**
* Evaluation set (12 official cases + 10 team cases + 4 scope cases)
* Arabic / English interface; answers in the language of the question
* Off-topic rejection (questions not about Islam)
* Per-category sparkle art based on the logo

## Work planned for 4–6 October (evaluated)

* [ ] Human review of every entry and evidence item against the approved sources; only then set `review: reviewed` in `assets/kb/faqs.json`. This also fixes the answer footer: today it shows «من قاعدة المعرفة الموثقة» above «بانتظار المراجعة البشرية مقابل المصادر المعتمدة», which reads as a contradiction; once reviewed it shows «روجعت بشرياً مقابل المصادر المعتمدة» (user asked for this on 4 October). Done so far: `id-name` (29 September).
* [ ] Expand the knowledge base (target: ______ entries)
* [ ] Live evaluation through Claude (`dart run bin/eval.dart --ai`) and fixes
* [ ] ______
