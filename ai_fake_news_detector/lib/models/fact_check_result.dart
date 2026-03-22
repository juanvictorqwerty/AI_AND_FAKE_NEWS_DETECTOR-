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

class FactCheckResult {
  final bool success;
  final String claim;
  final String type;
  final String searchQuery;
  final List<WebSearchResult> sources;

  FactCheckResult({
    required this.success,
    required this.claim,
    required this.type,
    required this.searchQuery,
    required this.sources,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'claim': claim,
      'type': type,
      'searchQuery': searchQuery,
      'sources': sources.map((item) => item.toJson()).toList(),
    };
  }

  // Helper getter to determine verdict based on type
  String get combinedVerdict {
    switch (type.toLowerCase()) {
      case 'true':
        return 'true';
      case 'false':
        return 'false';
      case 'controversial':
      case 'unverified':
      default:
        return 'unverified';
    }
  }

  // Helper getter for evidence summary
  String get evidenceSummary {
    if (sources.isEmpty) {
      return 'No sources found for this claim.';
    }
    return 'Found ${sources.length} sources related to this claim. '
        'The claim appears to be ${type.toLowerCase()}.';
  }

  // Helper getter for total sources
  int get totalSources => sources.length;
}
