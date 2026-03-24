class WebSearchResult {
  final String title;
  final String url;
  final String date;
  final String snippet;
  final String publisher;
  final bool isTrusted;

  WebSearchResult({
    required this.title,
    required this.url,
    required this.date,
    required this.snippet,
    required this.publisher,
    required this.isTrusted,
  });

  factory WebSearchResult.fromJson(Map<String, dynamic> json) {
    return WebSearchResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      date: json['date'] ?? '',
      snippet: json['snippet'] ?? '',
      publisher: json['publisher'] ?? '',
      isTrusted: json['isTrusted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'date': date,
      'snippet': snippet,
      'publisher': publisher,
      'isTrusted': isTrusted,
    };
  }
}

class Verdict {
  final String verdict;
  final String confidence;
  final String reason;

  Verdict({
    required this.verdict,
    required this.confidence,
    required this.reason,
  });

  factory Verdict.fromJson(Map<String, dynamic> json) {
    return Verdict(
      verdict: json['verdict'] ?? 'unverified',
      confidence: json['confidence'] ?? 'low',
      reason: json['reason'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'verdict': verdict,
        'confidence': confidence,
        'reason': reason,
      };
}

class FactCheckResult {
  final bool success;
  final String claim;
  final String type;
  final String searchQuery;
  final List<WebSearchResult> sources;
  final Verdict? verdict;

  FactCheckResult({
    required this.success,
    required this.claim,
    required this.type,
    required this.searchQuery,
    required this.sources,
    this.verdict,
  });

  factory FactCheckResult.fromJson(Map<String, dynamic> json) {
    return FactCheckResult(
      success: json['success'] ?? false,
      claim: json['claim'] ?? '',
      type: json['type'] ?? 'unverified',
      searchQuery: json['searchQuery'] ?? '',
      sources: (json['sources'] as List<dynamic>?)
              ?.map((item) =>
                  WebSearchResult.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      verdict: json['verdict'] != null
          ? Verdict.fromJson(json['verdict'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'claim': claim,
      'type': type,
      'searchQuery': searchQuery,
      'sources': sources.map((item) => item.toJson()).toList(),
      'verdict': verdict?.toJson(),
    };
  }

  String get combinedVerdict {
    if (verdict != null) {
      return verdict!.verdict.toLowerCase();
    }

    // Fallback to type-inference if verdict is missing
    final lowerType = type.toLowerCase();
    if (lowerType.contains('true') ||
        lowerType.contains('verified') ||
        lowerType.contains('correct')) {
      return 'true';
    } else if (lowerType.contains('false') ||
        lowerType.contains('debunked') ||
        lowerType.contains('incorrect')) {
      return 'false';
    } else {
      return 'unverified';
    }
  }

  String get evidenceSummary {
    if (sources.isEmpty) {
      return 'No sources found for this claim.';
    }
    return 'Found ${sources.length} sources related to this claim. '
        'The claim appears to be ${type.toLowerCase()}.';
  }

  int get totalSources => sources.length;
}