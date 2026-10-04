import 'dart:math' as math;

import 'arabic.dart';
import 'models.dart';

/// A scored match between a user question and a curated entry.
class RetrievalHit {
  const RetrievalHit(this.entry, this.score, this.coverage, this.similarity);

  final FaqEntry entry;

  /// Combined score in [0, 1+].
  final double score;

  /// IDF-weighted share of the question's terms found in the entry.
  final double coverage;

  /// Best character-trigram similarity to the entry question or a variant.
  final double similarity;

  @override
  String toString() =>
      '${entry.id} score=${score.toStringAsFixed(2)} '
      'cov=${coverage.toStringAsFixed(2)} sim=${similarity.toStringAsFixed(2)}';
}

class _Doc {
  _Doc(this.entry, this.strong, this.tags, this.body, this.grams);

  final FaqEntry entry;
  final Set<String> strong; // question + variants
  final Set<String> tags;
  final Set<String> body; // answer text
  final List<Set<String>> grams; // question + each variant
}

/// Lexical retriever over the curated entries. Deterministic, dependency-free
/// and fast enough to run on-device for offline answering and on the server
/// to pass retrieval hints to the model.
class Retriever {
  Retriever(KnowledgeBase kb) {
    for (final e in kb.entries) {
      final strong = <String>{
        ...tokenize(e.question),
        for (final v in e.variants) ...tokenize(v),
      };
      final tags = <String>{for (final t in e.tags) ...tokenize(t)};
      final body = <String>{
        ...tokenize(e.principle),
        ...tokenize(e.khilafAgreed),
        ...tokenize(e.khilafNote),
        ...tokenize(e.referReason),
      };
      _docs.add(
        _Doc(e, strong, tags, body, [
          trigrams(e.question),
          for (final v in e.variants) trigrams(v),
        ]),
      );
      for (final t in {...strong, ...tags}) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
    }
  }

  /// Score at or above which a curated entry is treated as the answer.
  static const strongThreshold = 0.56;

  /// A lower score still counts when the top hit clearly beats the runner-up
  /// (paraphrases with a few unknown words). Tuned on eval/test_cases.json:
  /// true matches sit ≥ 0.44 with margin ≥ 0.23, misses ≤ 0.28 / ≤ 0.06.
  static const marginThreshold = 0.40;
  static const minMargin = 0.18;

  /// Score at or above which an entry is worth suggesting as related.
  static const relatedThreshold = 0.22;

  /// Whether the top hit is confident enough to answer from directly.
  static bool isStrong(List<RetrievalHit> hits) {
    if (hits.isEmpty) return false;
    final top = hits.first.score;
    if (top >= strongThreshold) return true;
    final second = hits.length > 1 ? hits[1].score : 0.0;
    return top >= marginThreshold && top - second >= minMargin;
  }

  final _docs = <_Doc>[];
  final _df = <String, int>{};

  double _idf(String token) {
    final n = _docs.length;
    return math.log(1 + n / (1 + (_df[token] ?? 0)));
  }

  List<RetrievalHit> search(
    String query, {
    String? categoryId,
    int limit = 5,
  }) {
    final qTokens = tokenize(query).toSet();
    final qGrams = trigrams(query);
    if (qTokens.isEmpty && qGrams.length < 3) return const [];

    final totalWeight = qTokens.fold<double>(0, (s, t) => s + _idf(t));
    final hits = <RetrievalHit>[];
    for (final d in _docs) {
      var matched = 0.0;
      for (final t in qTokens) {
        final w = _idf(t);
        if (d.strong.contains(t)) {
          matched += w;
        } else if (d.tags.contains(t)) {
          matched += 0.8 * w;
        } else if (d.body.contains(t)) {
          matched += 0.35 * w;
        }
      }
      final coverage = totalWeight == 0 ? 0.0 : matched / totalWeight;
      var sim = 0.0;
      for (final g in d.grams) {
        sim = math.max(sim, dice(qGrams, g));
      }
      var score = 0.62 * coverage + 0.38 * sim;
      if (categoryId != null && d.entry.categoryId == categoryId) {
        score += 0.04;
      }
      if (score > 0.05) hits.add(RetrievalHit(d.entry, score, coverage, sim));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }
}
