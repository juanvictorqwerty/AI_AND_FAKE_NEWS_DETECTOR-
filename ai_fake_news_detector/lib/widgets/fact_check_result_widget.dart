import 'package:flutter/material.dart';
import 'package:ai_fake_news_detector/models/fact_check_result.dart';
import 'package:url_launcher/url_launcher.dart';

class FactCheckResultWidget extends StatelessWidget {
  final FactCheckResult result;

  const FactCheckResultWidget({
    super.key,
    required this.result,
  });

  Color _getVerdictColor(String verdict) {
    switch (verdict.toLowerCase()) {
      case 'true':
        return Colors.green;
      case 'false':
        return Colors.red;
      case 'unverified':
      default:
        return Colors.orange;
    }
  }

  String _getVerdictText(String verdict) {
    switch (verdict.toLowerCase()) {
      case 'true':
        return 'TRUE';
      case 'false':
        return 'FALSE';
      case 'unverified':
      default:
        return 'UNVERIFIED';
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Claim Text
            const Text(
              'Claim:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.claim,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Verdict
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getVerdictColor(result.combinedVerdict).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getVerdictColor(result.combinedVerdict),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    result.combinedVerdict.toLowerCase() == 'true'
                        ? Icons.check_circle
                        : result.combinedVerdict.toLowerCase() == 'false'
                            ? Icons.cancel
                            : Icons.help,
                    color: _getVerdictColor(result.combinedVerdict),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getVerdictText(result.combinedVerdict),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getVerdictColor(result.combinedVerdict),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Evidence Summary
            const Text(
              'Evidence Summary:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              result.evidenceSummary,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Sources
            if (result.sources.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sources:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '${result.totalSources} sources found',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: result.sources.length,
                itemBuilder: (context, index) {
                  final source = result.sources[index];
                  return _SourceTile(
                    source: source,
                    onTap: () => _launchUrl(source.url),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final WebSearchResult source;
  final VoidCallback onTap;

  const _SourceTile({
    required this.source,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    source.publisher,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.open_in_new,
              size: 20,
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}
