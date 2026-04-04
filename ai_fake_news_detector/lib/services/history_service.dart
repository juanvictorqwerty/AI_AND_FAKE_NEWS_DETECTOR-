import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HistoryItem {
  final String id;
  final String claim;
  final String verdict;
  final String confidence;
  final String reason;
  final List<String> sources;
  final String createdAt;

  HistoryItem({
    required this.id,
    required this.claim,
    required this.verdict,
    required this.confidence,
    required this.reason,
    required this.sources,
    required this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] ?? '',
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'claim': claim,
      'verdict': verdict,
      'confidence': confidence,
      'reason': reason,
      'sources': sources,
      'createdAt': createdAt,
    };
  }

  String get formattedDate {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown date';
    }
  }

  Color get verdictColor {
    switch (verdict.toLowerCase()) {
      case 'true':
        return Colors.green;
      case 'false':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData get verdictIcon {
    switch (verdict.toLowerCase()) {
      case 'true':
        return Icons.check_circle;
      case 'false':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}

class HistoryService extends GetxService {
  String get baseUrl =>
      dotenv.env['BASE_URL_NODE'] ?? 'http://192.168.1.152:4000';

  /// Fetch fact-check history for the authenticated user
  ///
  /// [token] - The authentication token
  ///
  /// Returns a Map with 'success' boolean, 'count', and 'results' (List<HistoryItem>)
  Future<Map<String, dynamic>> getFactCheckHistory({
    required String token,
  }) async {
    try {
      final url = '$baseUrl/fact-check/history';
      debugPrint('HistoryService: Calling $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint(
        'HistoryService: Response status=${response.statusCode}, body=${response.body}',
      );

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message':
              'Server returned empty response. Status: ${response.statusCode}',
          'count': 0,
          'results': <HistoryItem>[],
        };
      }

      final body = jsonDecode(response.body);

      // Check success field from backend
      if (body['success'] == true) {
        final count = body['count'] ?? 0;
        final results =
            (body['results'] as List<dynamic>?)
                ?.map(
                  (item) => HistoryItem.fromJson(item as Map<String, dynamic>),
                )
                .toList() ??
            <HistoryItem>[];

        return {'success': true, 'count': count, 'results': results};
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to fetch history',
          'count': 0,
          'results': <HistoryItem>[],
        };
      }
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
}
