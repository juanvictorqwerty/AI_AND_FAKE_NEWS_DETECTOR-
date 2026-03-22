class WebSearchResult {
  final String title;
  final String url;
  final String publisher;

  WebSearchResult({
    required this.title,
    required this.url,
    required this.publisher,
  });

  factory WebSearchResult.fromJson(Map<String, dynamic> json) {
    return WebSearchResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      publisher: json['publisher'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'publisher': publisher,
    };
  }
}

class FactCheckResult {
  final bool success;
  final String claimText;
  final String combinedVerdict;
  final String evidenceSummary;
  final int totalSources;
  final List<WebSearchResult> webSearchResults;

  FactCheckResult({
    required this.success,
    required this.claimText,
    required this.combinedVerdict,
    required this.evidenceSummary,
    required this.totalSources,
    required this.webSearchResults,
  });

  factory FactCheckResult.fromJson(Map<String, dynamic> json) {
    return FactCheckResult(
      success: json['success'] ?? false,
      claimText: json['claimText'] ?? '',
      combinedVerdict: json['combinedVerdict'] ?? 'unverified',
      evidenceSummary: json['evidenceSummary'] ?? '',
      totalSources: json['totalSources'] ?? 0,
      webSearchResults: (json['webSearchResults'] as List<dynamic>?)
              ?.map((item) =>
                  WebSearchResult.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'claimText': claimText,
      'combinedVerdict': combinedVerdict,
      'evidenceSummary': evidenceSummary,
      'totalSources': totalSources,
      'webSearchResults':
          webSearchResults.map((item) => item.toJson()).toList(),
    };
  }
}
