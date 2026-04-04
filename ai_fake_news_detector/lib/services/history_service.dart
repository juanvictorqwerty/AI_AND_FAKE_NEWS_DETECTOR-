import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum HistoryItemType { factCheck, mediaCheck }

class HistoryItem {
  final String id;
  final HistoryItemType type;
  final String? claim; // For fact-check items
  final String? verdict; // For fact-check items
  final String? confidence; // For fact-check items
  final String? reason; // For fact-check items
  final List<String>? sources; // For fact-check items
  final bool? isPhoto; // For media-check items
  final bool? isVideo; // For media-check items
  final List<String>? urlList; // For media-check items
  final int? score; // For media-check items
  final String createdAt;

  HistoryItem({
    required this.id,
    required this.type,
    required this.createdAt,
    this.claim,
    this.verdict,
    this.confidence,
    this.reason,
    this.sources,
    this.isPhoto,
    this.isVideo,
    this.urlList,
    this.score,
  });

  factory HistoryItem.fromFactCheckJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] ?? '',
      type: HistoryItemType.factCheck,
      claim: json['claim'] ?? '',
      verdict: json['verdict'] ?? 'unverified',
      confidence: json['confidence'] ?? 'low',
      reason: json['reason'] ?? '',
      sources:
          (json['sources'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList() ??
          [],
      createdAt: json['createdAt'] ?? '',
    );
  }

  factory HistoryItem.fromMediaCheckJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] ?? '',
      type: HistoryItemType.mediaCheck,
      isPhoto: json['isPhoto'] ?? false,
      isVideo: json['isVideo'] ?? false,
      urlList:
          (json['urlList'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList() ??
          [],
      score: json['score'] ?? 0,
      createdAt: json['createdAt'] ?? '',
    );
  }

  String get formattedDate {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown date';
    }
  }

  String get displayTitle {
    if (type == HistoryItemType.factCheck) {
      return this.claim ?? 'Unknown claim';
    } else {
      final mediaType = this.isVideo == true ? 'Video' : 'Image';
      final urlCount = this.urlList?.length ?? 0;
      return '$mediaType Analysis ($urlCount ${urlCount == 1 ? 'URL' : 'URLs'})';
    }
  }

  String get verdictText {
    if (type == HistoryItemType.factCheck) {
      switch (this.verdict?.toLowerCase()) {
        case 'true':
          return 'VERIFIED TRUE';
        case 'false':
          return 'VERIFIED FALSE';
        case 'unverified':
        default:
          return 'UNVERIFIED';
      }
    } else {
      // For media checks: score=1 means HUMAN, score=0 means AI
      if (this.score == 1) {
        return 'HUMAN';
      } else if (this.score == 0) {
        return 'AI';
      } else {
        return 'UNKNOWN';
      }
    }
  }

  Color get verdictColor {
    if (type == HistoryItemType.factCheck) {
      switch (this.verdict?.toLowerCase()) {
        case 'true':
          return Colors.green;
        case 'false':
          return Colors.red;
        default:
          return Colors.orange;
      }
    } else {
      // For media checks: score=1 means HUMAN (green), score=0 means AI (red)
      if (this.score == 1) {
        return Colors.green;
      } else if (this.score == 0) {
        return Colors.red;
      } else {
        return Colors.orange; // Unknown score
      }
    }
  }

  IconData get verdictIcon {
    if (type == HistoryItemType.factCheck) {
      switch (this.verdict?.toLowerCase()) {
        case 'true':
          return Icons.check_circle;
        case 'false':
          return Icons.cancel;
        default:
          return Icons.help;
      }
    } else {
      // For media checks: score=1 means HUMAN (person), score=0 means AI (android/robot)
      if (this.score == 1) {
        return Icons.person;
      } else if (this.score == 0) {
        return Icons.android;
      } else {
        return Icons.help; // Unknown score
      }
    }
  }

  String get mediaTypeText {
    if (this.isVideo == true) return 'Video';
    if (this.isPhoto == true) return 'Photo';
    return 'Media';
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] == 'factCheck'
        ? HistoryItemType.factCheck
        : HistoryItemType.mediaCheck;

    if (type == HistoryItemType.factCheck) {
      return HistoryItem.fromFactCheckJson(json);
    } else {
      return HistoryItem.fromMediaCheckJson(json);
    }
  }

  Map<String, dynamic> toJson() {
    final base = {
      'id': id,
      'type': type == HistoryItemType.factCheck ? 'factCheck' : 'mediaCheck',
      'createdAt': createdAt,
    };

    if (type == HistoryItemType.factCheck) {
      return {
        ...base,
        'claim': claim,
        'verdict': verdict,
        'confidence': confidence,
        'reason': reason,
        'sources': sources,
      };
    } else {
      return {
        ...base,
        'isPhoto': isPhoto,
        'isVideo': isVideo,
        'urlList': urlList,
        'score': score,
      };
    }
  }
}

class HistoryService extends GetxService {
  String get baseUrl =>
      dotenv.env['BASE_URL_NODE'] ?? 'http://192.168.1.152:4000';

  /// Fetch combined history (fact-check and media) for the authenticated user
  ///
  /// [token] - The authentication token
  ///
  /// Returns a Map with 'success' boolean, 'count', and 'results' (List<HistoryItem>)
  Future<Map<String, dynamic>> getCombinedHistory({
    required String token,
  }) async {
    try {
      // Fetch both fact-check and media history in parallel
      final factCheckFuture = _getFactCheckHistory(token);
      final mediaHistoryFuture = _getMediaCheckHistory(token);

      final results = await Future.wait([factCheckFuture, mediaHistoryFuture]);

      final factCheckResponse = results[0] as Map<String, dynamic>;
      final mediaResponse = results[1] as Map<String, dynamic>;

      // Combine results
      final allResults = <HistoryItem>[];
      if (factCheckResponse['success'] == true) {
        allResults.addAll(factCheckResponse['results'] as List<HistoryItem>);
      }
      if (mediaResponse['success'] == true) {
        allResults.addAll(mediaResponse['results'] as List<HistoryItem>);
      }

      // Sort by creation date (newest first)
      allResults.sort(
        (a, b) =>
            DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)),
      );

      final totalCount = allResults.length;

      return {'success': true, 'count': totalCount, 'results': allResults};
    } catch (e) {
      debugPrint('HistoryService: Error $e');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'count': 0,
        'results': <HistoryItem>[],
      };
    }
  }

  /// Fetch fact-check history for the authenticated user
  Future<Map<String, dynamic>> _getFactCheckHistory(String token) async {
    try {
      final url = '$baseUrl/fact-check/history';
      debugPrint('HistoryService: Calling fact-check history $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
        'HistoryService: Fact-check response status=${response.statusCode}',
      );

      if (response.body.isEmpty) {
        return {'success': false, 'count': 0, 'results': <HistoryItem>[]};
      }

      final body = jsonDecode(response.body);

      if (body['success'] == true) {
        final results =
            (body['results'] as List<dynamic>?)
                ?.map(
                  (item) => HistoryItem.fromFactCheckJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList() ??
            <HistoryItem>[];

        return {'success': true, 'count': results.length, 'results': results};
      } else {
        return {'success': false, 'count': 0, 'results': <HistoryItem>[]};
      }
    } catch (e) {
      debugPrint('HistoryService: Fact-check error $e');
      return {'success': false, 'count': 0, 'results': <HistoryItem>[]};
    }
  }

  /// Fetch media check history for the authenticated user
  Future<Map<String, dynamic>> _getMediaCheckHistory(String token) async {
    try {
      final url = '$baseUrl/fact-check/media-history';
      debugPrint('HistoryService: Calling media history $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
        'HistoryService: Media response status=${response.statusCode}',
      );

      if (response.body.isEmpty) {
        return {'success': false, 'count': 0, 'results': <HistoryItem>[]};
      }

      final body = jsonDecode(response.body);

      if (body['success'] == true) {
        final results =
            (body['results'] as List<dynamic>?)
                ?.map(
                  (item) => HistoryItem.fromMediaCheckJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList() ??
            <HistoryItem>[];

        return {'success': true, 'count': results.length, 'results': results};
      } else {
        return {'success': false, 'count': 0, 'results': <HistoryItem>[]};
      }
    } catch (e) {
      debugPrint('HistoryService: Media error $e');
      return {'success': false, 'count': 0, 'results': <HistoryItem>[]};
    }
  }
}
