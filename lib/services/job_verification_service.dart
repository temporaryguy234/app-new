import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/job_model.dart';

class JobVerificationService {
  static const Duration _timeout = Duration(seconds: 3);

  /// Verify if a job is still online by checking its application URL
  static Future<bool> verifyJobOnline(JobModel job) async {
    try {
      final url = job.applicationUrl?.isNotEmpty == true 
        ? job.applicationUrl! 
        : job.sourceUrl;
      
      if (url == null || url.isEmpty) return true; // Assume online if no URL
      
      final uri = Uri.parse(url);
      
      // Try HEAD request first (faster)
      try {
        final headResponse = await http.head(uri).timeout(_timeout);
        
        // 404/410 means definitely offline
        if (headResponse.statusCode == 404 || headResponse.statusCode == 410) {
          return false;
        }
        
        // 2xx-3xx means likely online
        if (headResponse.statusCode >= 200 && headResponse.statusCode < 400) {
          return true;
        }
      } catch (e) {
        // HEAD failed, try GET
      }
      
      // Fallback to GET request
      final getResponse = await http.get(uri).timeout(_timeout);
      
      // Check status code
      if (getResponse.statusCode >= 400) return false;
      
      // Check response body for "no longer available" patterns
      final body = getResponse.body.toLowerCase();
      final offlinePatterns = [
        'no longer available',
        'position closed',
        'job expired',
        'nicht mehr verfügbar',
        'stelle nicht mehr verfügbar',
        'bewerbung nicht mehr möglich',
        'ausschreibung beendet',
      ];
      
      for (final pattern in offlinePatterns) {
        if (body.contains(pattern)) return false;
      }
      
      return true;
    } catch (e) {
      // On any error, assume online (don't aggressively drop jobs)
      print('Job verification error for ${job.id}: $e');
      return true;
    }
  }

  /// Verify multiple jobs in parallel (with concurrency limit)
  static Future<Map<String, bool>> verifyJobsOnline(List<JobModel> jobs) async {
    final results = <String, bool>{};
    
    // Process in batches of 5 to avoid overwhelming servers
    const batchSize = 5;
    for (int i = 0; i < jobs.length; i += batchSize) {
      final batch = jobs.skip(i).take(batchSize).toList();
      
      final futures = batch.map((job) async {
        final isOnline = await verifyJobOnline(job);
        return MapEntry(job.id, isOnline);
      });
      
      final batchResults = await Future.wait(futures);
      results.addAll(Map.fromEntries(batchResults));
      
      // Small delay between batches to be respectful
      if (i + batchSize < jobs.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    return results;
  }

  /// Filter jobs to only show online ones
  static List<JobModel> filterOnlineJobs(List<JobModel> jobs, Map<String, bool> onlineStatus) {
    return jobs.where((job) {
      final status = onlineStatus[job.id];
      return status != false; // Show if online or unknown
    }).toList();
  }
}
