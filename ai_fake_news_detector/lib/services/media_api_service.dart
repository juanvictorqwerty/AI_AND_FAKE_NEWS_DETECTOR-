import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ai_fake_news_detector/models/upload_response.dart';
import 'package:ai_fake_news_detector/models/analysis_result.dart';

/// Service for handling media upload and result retrieval from backend
///
/// This service handles:
/// - File upload via multipart POST request
/// - Polling results endpoint until completion
/// - Retrieving final analysis results
/// - Retry mechanism and timeout handling
class MediaApiService extends GetxService {
  /// Base URL for FastAPI endpoints
  String get baseUrl => dotenv.env['Base_url_fastapi'] ?? 'http://192.168.1.152:8000';
  
  /// Maximum number of retry attempts for network errors
  static const int maxRetryAttempts = 3;
  
  /// Default timeout for processing (5 minutes)
  static const Duration defaultTimeout = Duration(minutes: 5);
  
  /// Default polling interval (2 seconds)
  static const Duration defaultPollInterval = Duration(seconds: 2);

  /// Get MIME type based on file extension
  ///
  /// [filePath] - Path to the file
  ///
  /// Returns the appropriate MIME type string
  String _getMimeType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'application/octet-stream';
    }
  }

  /// Upload file to backend via multipart POST request
  ///
  /// [filePath] - Path to the file to upload
  /// [fileType] - Type of file ('image' or 'video')
  ///
  /// Returns UploadResponse with file_id on success
  /// Throws exception on failure after max retries
  Future<UploadResponse> uploadFile(String filePath, String fileType) async {
    int attempts = 0;
    
    while (attempts < maxRetryAttempts) {
      try {
        print('MediaApiService: Uploading file (attempt ${attempts + 1}/$maxRetryAttempts)');
        print('MediaApiService: File path: $filePath');
        print('MediaApiService: File type: $fileType');
        
        // Create multipart request
        final url = Uri.parse('$baseUrl/upload');
        final request = http.MultipartRequest('POST', url);
        
        // Add file to request
        final file = File(filePath);
        final fileStream = http.ByteStream(file.openRead());
        final fileLength = await file.length();
        
        final multipartFile = http.MultipartFile(
          'file',
          fileStream,
          fileLength,
          filename: filePath.split('/').last,
          contentType: MediaType.parse(_getMimeType(filePath)),
        );
        
        request.files.add(multipartFile);
        
        // Add file type header
        request.headers['Content-Type'] = 'multipart/form-data';
        
        print('MediaApiService: Sending request to $url');
        print('MediaApiService: File size: $fileLength bytes');
        
        // Send request with timeout
        final streamedResponse = await request.send().timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            throw TimeoutException('Upload timeout after 2 minutes');
          },
        );
        
        // Get response
        final response = await http.Response.fromStream(streamedResponse);
        
        print('MediaApiService: Response status: ${response.statusCode}');
        print('MediaApiService: Response body: ${response.body}');
        
        // Check response status
        if (response.statusCode == 200 || response.statusCode == 201) {
          final jsonResponse = jsonDecode(response.body);
          final uploadResponse = UploadResponse.fromJson(jsonResponse);
          
          if (uploadResponse.success) {
            print('MediaApiService: Upload successful, file_id: ${uploadResponse.fileId}');
            return uploadResponse;
          } else {
            throw Exception(uploadResponse.message);
          }
        } else {
          // Try to parse error message from response
          String errorMessage = 'Upload failed with status ${response.statusCode}';
          try {
            final jsonResponse = jsonDecode(response.body);
            errorMessage = jsonResponse['message'] ?? errorMessage;
          } catch (_) {}
          
          throw Exception(errorMessage);
        }
      } on TimeoutException {
        attempts++;
        print('MediaApiService: Upload timeout (attempt $attempts)');
        if (attempts >= maxRetryAttempts) {
          throw Exception('Upload timeout after $maxRetryAttempts attempts');
        }
        // Wait before retry
        await Future.delayed(Duration(seconds: attempts * 2));
      } on SocketException catch (e) {
        attempts++;
        print('MediaApiService: Network error (attempt $attempts): $e');
        if (attempts >= maxRetryAttempts) {
          throw Exception('Network error after $maxRetryAttempts attempts: ${e.message}');
        }
        // Wait before retry
        await Future.delayed(Duration(seconds: attempts * 2));
      } catch (e) {
        print('MediaApiService: Upload error: $e');
        throw Exception('Upload failed: ${e.toString()}');
      }
    }
    
    throw Exception('Upload failed after $maxRetryAttempts attempts');
  }

  /// Get analysis result for a file
  ///
  /// [fileId] - ID of the uploaded file
  ///
  /// Returns AnalysisResult with status, label, confidence, and probabilities
  Future<AnalysisResult> getAnalysisResult(String fileId) async {
    try {
      print('MediaApiService: Getting analysis result for file_id: $fileId');
      
      final url = Uri.parse('$baseUrl/results/$fileId');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Result fetch timeout');
        },
      );
      
      print('MediaApiService: Result response: ${response.statusCode}');
      print('MediaApiService: Result body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return AnalysisResult.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to get result: ${response.statusCode}');
      }
    } on TimeoutException {
      print('MediaApiService: Result fetch timeout');
      rethrow;
    } catch (e) {
      print('MediaApiService: Result fetch error: $e');
      throw Exception('Failed to get analysis result: ${e.toString()}');
    }
  }

  /// Poll results endpoint until completion or timeout
  ///
  /// [fileId] - ID of the uploaded file
  /// [timeout] - Maximum time to wait for completion (default: 5 minutes)
  /// [interval] - Polling interval (default: 2 seconds)
  /// [onStatusUpdate] - Optional callback for status updates
  ///
  /// Returns AnalysisResult when processing is complete
  /// Throws exception on failure or timeout
  Future<AnalysisResult> pollUntilComplete(
    String fileId, {
    Duration timeout = defaultTimeout,
    Duration interval = defaultPollInterval,
    void Function(AnalysisResult)? onStatusUpdate,
  }) async {
    print('MediaApiService: Starting polling for file_id: $fileId');
    print('MediaApiService: Timeout: ${timeout.inSeconds}s, Interval: ${interval.inSeconds}s');
    
    final startTime = DateTime.now();
    int pollCount = 0;
    
    while (true) {
      pollCount++;
      final elapsed = DateTime.now().difference(startTime);
      
      // Check timeout
      if (elapsed > timeout) {
        print('MediaApiService: Polling timeout after ${elapsed.inSeconds}s');
        throw TimeoutException('Processing timeout after ${timeout.inMinutes} minutes');
      }
      
      print('MediaApiService: Poll #$pollCount (${elapsed.inSeconds}s elapsed)');
      
      try {
        // Get current result
        final result = await getAnalysisResult(fileId);
        
        print('MediaApiService: Status: ${result.status}, Label: ${result.label}, Confidence: ${result.confidence}');
        
        // Call status update callback if provided
        if (onStatusUpdate != null) {
          onStatusUpdate(result);
        }
        
        // Check if completed
        if (result.isCompleted) {
          print('MediaApiService: Processing completed');
          return result;
        }
        
        // Check if failed
        if (result.isFailed) {
          print('MediaApiService: Processing failed');
          throw Exception(result.error ?? 'Processing failed');
        }
        
        // Wait before next poll
        await Future.delayed(interval);
      } catch (e) {
        // If it's a timeout or network error, continue polling
        if (e is TimeoutException || e is SocketException) {
          print('MediaApiService: Temporary error during poll: $e');
          await Future.delayed(interval);
          continue;
        }
        
        // For other errors, rethrow
        rethrow;
      }
    }
  }

  /// Complete upload and processing flow
  ///
  /// [filePath] - Path to the file to upload
  /// [fileType] - Type of file ('image' or 'video')
  /// [onUploadProgress] - Optional callback for upload progress
  /// [onStatusUpdate] - Optional callback for processing status updates
  ///
  /// Returns AnalysisResult when processing is complete
  Future<AnalysisResult> uploadAndProcess(
    String filePath,
    String fileType, {
    void Function(double)? onUploadProgress,
    void Function(AnalysisResult)? onStatusUpdate,
  }) async {
    print('MediaApiService: Starting upload and process flow');
    
    // Upload file
    final uploadResponse = await uploadFile(filePath, fileType);
    
    if (!uploadResponse.success) {
      throw Exception(uploadResponse.message);
    }
    
    // Poll until complete
    return await pollUntilComplete(
      uploadResponse.fileId,
      onStatusUpdate: onStatusUpdate,
    );
  }
}
