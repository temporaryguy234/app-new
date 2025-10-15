import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_keys.dart';
import '../models/job_model.dart';
import '../models/filter_model.dart';

class JobService {
  static const String _baseUrl = 'https://serpapi.com/search';

  Future<List<JobModel>> searchJobs({
    required String query,
    String? location,
    FilterModel? filters,
    String? experienceLevel,
    bool? remote,
    double? minSalary,
  }) async {
    try {
      print('🔍 Suche Jobs mit Query: $query');
      print('📍 Location: $location');
      print('🎯 Experience: $experienceLevel');
      print('🏠 Remote: $remote');
      print('💰 Min Salary: $minSalary');
      
      final params = _buildSearchParams(query, location, filters, experienceLevel, remote, minSalary);
      final response = await _callSerpAPI(params);
      
      final jobs = _parseJobResults(response);
      print('✅ ${jobs.length} Jobs gefunden');
      
      return jobs;
    } catch (e) {
      print('❌ Job-Suche fehlgeschlagen: $e');
      throw Exception('Job-Suche fehlgeschlagen: ${e.toString()}');
    }
  }

  Map<String, String> _buildSearchParams(
    String query, 
    String? location, 
    FilterModel? filters,
    String? experienceLevel,
    bool? remote,
    double? minSalary,
  ) {
    final params = {
      'api_key': ApiKeys.serpApiKey,
      'engine': 'google_jobs',
      'q': query,
      'location': location ?? 'Deutschland',
      'hl': 'de',
      'gl': 'de',
    };

    // Add experience level to query
    if (experienceLevel != null) {
      switch (experienceLevel) {
        case 'entry':
          params['q'] = '$query junior trainee entry level';
          break;
        case 'mid':
          params['q'] = '$query mid-level experienced 3-5 jahre';
          break;
        case 'senior':
          params['q'] = '$query senior lead manager 5+ jahre';
          break;
        case 'expert':
          params['q'] = '$query expert principal architect 10+ jahre';
          break;
      }
    }

    // Add remote filter
    if (remote == true) {
      params['q'] = '${params['q']} remote home office';
    }

    // Add salary filter
    if (minSalary != null) {
      params['salary_min'] = minSalary.toInt().toString();
    }

    // Add filters if provided
    if (filters != null) {
      if (filters.jobTypes.isNotEmpty) {
        params['job_type'] = filters.jobTypes.join(',');
      }
      if (filters.minSalary != null) {
        params['salary_min'] = filters.minSalary!.toInt().toString();
      }
      if (filters.maxSalary != null) {
        params['salary_max'] = filters.maxSalary!.toInt().toString();
      }
    }

    return params;
  }

  Future<Map<String, dynamic>> _callSerpAPI(Map<String, String> params) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('SerpAPI-Fehler: ${response.statusCode} - ${response.body}');
    }
  }

  List<JobModel> _parseJobResults(Map<String, dynamic> data) {
    final List<JobModel> jobs = [];
    
    try {
      final jobResults = data['jobs_results'] as List<dynamic>? ?? [];
      
      for (final jobData in jobResults) {
        final job = _parseJobFromData(jobData);
        if (job != null) {
          jobs.add(job);
        }
      }
    } catch (e) {
      // Return empty list if parsing fails
      print('Fehler beim Parsen der Job-Daten: $e');
    }
    
    return jobs;
  }

  JobModel? _parseJobFromData(Map<String, dynamic> jobData) {
    try {
      // Extract job details
      final title = jobData['title'] ?? '';
      final company = jobData['company_name'] ?? '';
      final location = jobData['location'] ?? '';
      final description = jobData['description'] ?? '';
      final applicationUrl = jobData['apply_options']?[0]?['link'] ?? '';
      
      // Parse salary
      String? salary;
      final salaryData = jobData['salary'];
      if (salaryData != null) {
        salary = salaryData['min'] != null && salaryData['max'] != null
            ? '${salaryData['min']} - ${salaryData['max']} €'
            : salaryData['min']?.toString() ?? salaryData['max']?.toString();
      }
      
      // Parse job type and other details
      final jobType = _extractJobType(jobData);
      final tags = _extractTags(jobData);
      final remotePercentage = _extractRemotePercentage(jobData);
      final experienceLevel = _extractExperienceLevel(jobData);
      
      // Parse posted date
      DateTime postedAt = DateTime.now();
      final postedDate = jobData['posted_at'];
      if (postedDate != null) {
        // Try to parse different date formats
        try {
          postedAt = DateTime.parse(postedDate);
        } catch (e) {
          // If parsing fails, use current date
          postedAt = DateTime.now();
        }
      }
      
      // Extract skills and industries from job data
      final skills = _extractSkills(jobData);
      final industries = _extractIndustries(jobData);
      
      // Generate unique ID
      final id = '${company}_${title}_${DateTime.now().millisecondsSinceEpoch}'.hashCode.toString();
      
      return JobModel(
        id: id,
        title: title,
        company: company,
        location: location,
        salary: salary,
        description: description,
        tags: tags,
        remotePercentage: remotePercentage,
        jobType: jobType,
        experienceLevel: experienceLevel,
        applicationUrl: applicationUrl,
        postedAt: postedAt,
        applicantCount: _extractApplicantCount(jobData),
        skills: skills,
        industries: industries,
      );
    } catch (e) {
      print('Fehler beim Parsen eines Jobs: $e');
      return null;
    }
  }

  String _extractJobType(Map<String, dynamic> jobData) {
    final scheduleType = jobData['schedule_type']?.toString().toLowerCase() ?? '';
    final jobType = jobData['job_type']?.toString().toLowerCase() ?? '';
    
    if (scheduleType.contains('full') || jobType.contains('vollzeit')) {
      return 'Vollzeit';
    } else if (scheduleType.contains('part') || jobType.contains('teilzeit')) {
      return 'Teilzeit';
    } else if (jobType.contains('praktikum') || jobType.contains('internship')) {
      return 'Praktikum';
    } else if (jobType.contains('freelance') || jobType.contains('freiberuflich')) {
      return 'Freelance';
    }
    
    return 'Vollzeit'; // Default
  }

  List<String> _extractTags(Map<String, dynamic> jobData) {
    final List<String> tags = [];
    
    // Check for remote work
    final location = jobData['location']?.toString().toLowerCase() ?? '';
    if (location.contains('remote') || location.contains('home')) {
      tags.add('Remote');
    }
    
    // Check for internship
    final title = jobData['title']?.toString().toLowerCase() ?? '';
    if (title.contains('praktikum') || title.contains('internship')) {
      tags.add('Praktikum');
    }
    
    // Add experience level tag
    final experienceLevel = _extractExperienceLevel(jobData);
    if (experienceLevel != null) {
      tags.add(experienceLevel);
    }
    
    return tags;
  }

  String? _extractRemotePercentage(Map<String, dynamic> jobData) {
    final location = jobData['location']?.toString().toLowerCase() ?? '';
    if (location.contains('remote')) {
      return '100%';
    } else if (location.contains('hybrid')) {
      return '50%';
    }
    return null;
  }

  String? _extractExperienceLevel(Map<String, dynamic> jobData) {
    final title = jobData['title']?.toString().toLowerCase() ?? '';
    final description = jobData['description']?.toString().toLowerCase() ?? '';
    
    if (title.contains('senior') || title.contains('lead') || title.contains('manager')) {
      return 'Senior';
    } else if (title.contains('mid') || title.contains('erfahren')) {
      return 'Mid';
    } else if (title.contains('junior') || title.contains('entry') || title.contains('trainee')) {
      return 'Entry';
    }
    
    return null;
  }

  int? _extractApplicantCount(Map<String, dynamic> jobData) {
    // This information is usually not available in SerpAPI results
    // Return null to indicate unknown
    return null;
  }

  List<String> _extractSkills(Map<String, dynamic> jobData) {
    final List<String> skills = [];
    final description = jobData['description']?.toString().toLowerCase() ?? '';
    final title = jobData['title']?.toString().toLowerCase() ?? '';
    
    // Common tech skills
    final techSkills = [
      'javascript', 'typescript', 'react', 'vue', 'angular', 'node.js', 'python',
      'java', 'c#', 'php', 'ruby', 'go', 'rust', 'swift', 'kotlin', 'dart',
      'html', 'css', 'sass', 'less', 'bootstrap', 'tailwind', 'jquery',
      'mongodb', 'mysql', 'postgresql', 'redis', 'elasticsearch',
      'aws', 'azure', 'gcp', 'docker', 'kubernetes', 'jenkins', 'git',
      'agile', 'scrum', 'kanban', 'ci/cd', 'devops', 'microservices'
    ];
    
    for (final skill in techSkills) {
      if (description.contains(skill) || title.contains(skill)) {
        skills.add(skill.toUpperCase());
      }
    }
    
    return skills.take(10).toList(); // Limit to 10 skills
  }

  List<String> _extractIndustries(Map<String, dynamic> jobData) {
    final List<String> industries = [];
    final description = jobData['description']?.toString().toLowerCase() ?? '';
    final company = jobData['company_name']?.toString().toLowerCase() ?? '';
    
    // Common industries
    final industryKeywords = {
      'Fintech': ['fintech', 'banking', 'finance', 'finanz', 'zahlung'],
      'E-Commerce': ['e-commerce', 'online shop', 'retail', 'handel'],
      'Healthcare': ['healthcare', 'medizin', 'pharma', 'gesundheit'],
      'Automotive': ['automotive', 'auto', 'fahrzeug', 'mobility'],
      'Gaming': ['gaming', 'spiel', 'entertainment', 'gaming'],
      'SaaS': ['saas', 'software as a service', 'cloud'],
      'AI/ML': ['artificial intelligence', 'machine learning', 'ai', 'ml'],
      'IoT': ['iot', 'internet of things', 'smart devices'],
      'Blockchain': ['blockchain', 'crypto', 'bitcoin', 'ethereum'],
      'EdTech': ['edtech', 'education', 'bildung', 'lernen']
    };
    
    for (final entry in industryKeywords.entries) {
      for (final keyword in entry.value) {
        if (description.contains(keyword) || company.contains(keyword)) {
          industries.add(entry.key);
          break; // Only add each industry once
        }
      }
    }
    
    return industries.take(3).toList(); // Limit to 3 industries
  }
}
