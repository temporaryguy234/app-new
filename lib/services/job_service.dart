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

  // Paged Google Jobs via SerpAPI with backoff and dedupe
  Future<List<JobModel>> searchJobsPaged({
    required String query,
    required String location,
    String? experienceLevel,
    JobFilters? filters,
    bool? remote,
    double? minSalary,
    int maxPages = 3,
  }) async {
    final all = <JobModel>[];
    final seen = <String>{};
    String? nextToken;
    int page = 0;

    do {
      final params = _buildSearchParams(query, location, filters, experienceLevel, remote, minSalary);
      if (nextToken != null) params['next_page_token'] = nextToken;

      Map<String, dynamic> json;
      int attempts = 0;
      while (true) {
        attempts++;
        try {
          json = await _callSerpAPI(params).timeout(const Duration(seconds: 12));
          break;
        } catch (e) {
          if (attempts >= 3) rethrow;
          await Future.delayed(Duration(milliseconds: 100 + 150 * attempts));
        }
      }

      final jobs = _parseJobs(json);
      for (final j in jobs) {
        final k = '${(j.applicationUrl ?? '').toLowerCase()}|${j.title.toLowerCase()}|${j.company.toLowerCase()}';
        if (seen.add(k)) all.add(j);
      }

      nextToken = json['serpapi_pagination']?['next_page_token'] as String?;
      page++;
    } while (nextToken != null && page < maxPages);

    return all;
  }

  Map<String, String> _buildSearchParams(
    String query, 
    String? location, 
    FilterModel? filters,
    String? experienceLevel,
    bool? remote,
    double? minSalary,
  ) {
    final loc = _normalizeSerpLocation(location);
    final params = {
      'api_key': ApiKeys.serpApiKey,
      'engine': 'google_jobs',
      'q': query,
      'location': loc['location']!,
      'hl': loc['hl']!,
      'gl': loc['gl']!,
    };

    // Add experience level to query
    if (experienceLevel != null) {
      switch (experienceLevel) {
        case 'entry':
          params['q'] = '${params['q']} junior';
          break;
        case 'mid':
          params['q'] = '${params['q']} mid';
          break;
        case 'senior':
          params['q'] = '${params['q']} senior';
          break;
        case 'expert':
          params['q'] = '${params['q']} expert';
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
    print('🔗 SERP GET: ${uri.toString().replaceAll(ApiKeys.serpApiKey, '***')}');
    
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    print('📦 SERP status: ${response.statusCode}, bytes: ${response.bodyBytes.length}');

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
        // Neue Felder für mehr Job-Daten
        requirements: _extractList(jobData['job_highlights']?['requirements']),
        benefits: _extractList(jobData['job_highlights']?['benefits']),
        responsibilities: _extractList(jobData['job_highlights']?['responsibilities']),
        companySize: jobData['company_size'] ?? '',
        workType: jobData['schedule_type'] ?? '',
        industry: jobData['industry'] ?? '',
        companyDescription: jobData['company_description'] ?? '',
        postalCode: _extractPostalCode(location),
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

  /// Normalisiert City/ZIP + Country (EN) für SerpAPI
  /// Beispiele: "Berlin, Deutschland" -> "Berlin, Germany" | "12305 Berlin" -> "Berlin, Germany"
  Map<String, String> _normalizeSerpLocation(String? location) {
    final raw = (location ?? '').trim();
    
    if (raw.isEmpty) {
      return {'location': 'Germany', 'hl': 'en', 'gl': 'de'};
    }
    // "Berlin, Deutschland" -> City + Country EN
    if (raw.contains(',')) {
      final parts = raw.split(',').map((s) => s.trim()).toList();
      final city = parts.first;
      final countryEn = _toEnglishCountry(parts.sublist(1).join(', '));
      final gl = countryEn == 'Austria' ? 'at' : countryEn == 'Switzerland' ? 'ch' : 'de';
      return {'location': '$city, $countryEn', 'hl': 'en', 'gl': gl};
    }

    // "12305 Berlin" -> "12305 Berlin, Germany" | "1200 Wien" -> "1200 Wien, Austria"
    final zipCity = RegExp(r'^\s*(\d{4,5})\s+(.+)$').firstMatch(raw);
    if (zipCity != null) {
      final zip = zipCity.group(1)!;
      final city = zipCity.group(2)!.trim();
      if (zip.length == 5) return {'location': '$zip $city, Germany', 'hl': 'en', 'gl': 'de'};
      if (zip.length == 4) return {'location': '$zip $city, Austria', 'hl': 'en', 'gl': 'at'}; // Heuristik
    }

    // Nur Land
    final l = raw.toLowerCase();
    if (['deutschland','germany','de'].contains(l)) return {'location': 'Germany', 'hl': 'en', 'gl': 'de'};
    if (['österreich','austria','at'].contains(l)) return {'location': 'Austria', 'hl': 'en', 'gl': 'at'};
    if (['schweiz','switzerland','ch'].contains(l)) return {'location': 'Switzerland', 'hl': 'en', 'gl': 'ch'};
    
    // Stadt-Name-Erkennung (erweiterte DACH-Städte)
    final cityMap = {
      // Deutschland - Großstädte
      'berlin': 'Berlin, Germany',
      'hamburg': 'Hamburg, Germany',
      'münchen': 'Munich, Germany',
      'munich': 'Munich, Germany',
      'köln': 'Cologne, Germany',
      'cologne': 'Cologne, Germany',
      'frankfurt': 'Frankfurt, Germany',
      'stuttgart': 'Stuttgart, Germany',
      'düsseldorf': 'Düsseldorf, Germany',
      'dresden': 'Dresden, Germany',
      'leipzig': 'Leipzig, Germany',
      'hannover': 'Hannover, Germany',
      'nürnberg': 'Nuremberg, Germany',
      'nuremberg': 'Nuremberg, Germany',
      'bremen': 'Bremen, Germany',
      'essen': 'Essen, Germany',
      'dortmund': 'Dortmund, Germany',
      'duisburg': 'Duisburg, Germany',
      'bochum': 'Bochum, Germany',
      'wuppertal': 'Wuppertal, Germany',
      'bielefeld': 'Bielefeld, Germany',
      'bonn': 'Bonn, Germany',
      'mannheim': 'Mannheim, Germany',
      'karlsruhe': 'Karlsruhe, Germany',
      'augsburg': 'Augsburg, Germany',
      'wiesbaden': 'Wiesbaden, Germany',
      'mönchengladbach': 'Mönchengladbach, Germany',
      'gelsenkirchen': 'Gelsenkirchen, Germany',
      'braunschweig': 'Braunschweig, Germany',
      'chemnitz': 'Chemnitz, Germany',
      'kiel': 'Kiel, Germany',
      'aachen': 'Aachen, Germany',
      'halle': 'Halle, Germany',
      'magdeburg': 'Magdeburg, Germany',
      'freiburg': 'Freiburg, Germany',
      'krefeld': 'Krefeld, Germany',
      'lübeck': 'Lübeck, Germany',
      'oberhausen': 'Oberhausen, Germany',
      'erfurt': 'Erfurt, Germany',
      'mainz': 'Mainz, Germany',
      'rostock': 'Rostock, Germany',
      'kassel': 'Kassel, Germany',
      'hagen': 'Hagen, Germany',
      'hamm': 'Hamm, Germany',
      'saarbrücken': 'Saarbrücken, Germany',
      'mülheim': 'Mülheim, Germany',
      'potsdam': 'Potsdam, Germany',
      'ludwigshafen': 'Ludwigshafen, Germany',
      'oldenburg': 'Oldenburg, Germany',
      'leverkusen': 'Leverkusen, Germany',
      'osnabrück': 'Osnabrück, Germany',
      'solingen': 'Solingen, Germany',
      'heidelberg': 'Heidelberg, Germany',
      'herne': 'Herne, Germany',
      'neuss': 'Neuss, Germany',
      'darmstadt': 'Darmstadt, Germany',
      'paderborn': 'Paderborn, Germany',
      'regensburg': 'Regensburg, Germany',
      'ingolstadt': 'Ingolstadt, Germany',
      'würzburg': 'Würzburg, Germany',
      'fürth': 'Fürth, Germany',
      'wolfsburg': 'Wolfsburg, Germany',
      'offenbach': 'Offenbach, Germany',
      'ulm': 'Ulm, Germany',
      'heilbronn': 'Heilbronn, Germany',
      'pforzheim': 'Pforzheim, Germany',
      'göttingen': 'Göttingen, Germany',
      'bottrop': 'Bottrop, Germany',
      'trier': 'Trier, Germany',
      'recklinghausen': 'Recklinghausen, Germany',
      'reutlingen': 'Reutlingen, Germany',
      'bremerhaven': 'Bremerhaven, Germany',
      'koblenz': 'Koblenz, Germany',
      'bergisch gladbach': 'Bergisch Gladbach, Germany',
      'jena': 'Jena, Germany',
      'remscheid': 'Remscheid, Germany',
      'erlangen': 'Erlangen, Germany',
      'moers': 'Moers, Germany',
      'siegen': 'Siegen, Germany',
      'hildesheim': 'Hildesheim, Germany',
      'salzgitter': 'Salzgitter, Germany',
      
      // Österreich - Städte
      'wien': 'Vienna, Austria',
      'vienna': 'Vienna, Austria',
      'graz': 'Graz, Austria',
      'linz': 'Linz, Austria',
      'salzburg': 'Salzburg, Austria',
      'innsbruck': 'Innsbruck, Austria',
      'klagenfurt': 'Klagenfurt, Austria',
      'villach': 'Villach, Austria',
      'wels': 'Wels, Austria',
      'sankt pölten': 'Sankt Pölten, Austria',
      'dornbirn': 'Dornbirn, Austria',
      'steyr': 'Steyr, Austria',
      'wiener neustadt': 'Wiener Neustadt, Austria',
      'feldkirch': 'Feldkirch, Austria',
      'bregenz': 'Bregenz, Austria',
      'leonding': 'Leonding, Austria',
      'klosterneuburg': 'Klosterneuburg, Austria',
      'baden': 'Baden, Austria',
      'wolfsberg': 'Wolfsberg, Austria',
      'leoben': 'Leoben, Austria',
      'krems': 'Krems, Austria',
      'traun': 'Traun, Austria',
      'amstetten': 'Amstetten, Austria',
      'kapfenberg': 'Kapfenberg, Austria',
      'hallein': 'Hallein, Austria',
      'kufstein': 'Kufstein, Austria',
      'traiskirchen': 'Traiskirchen, Austria',
      'schwechat': 'Schwechat, Austria',
      'braunau am inn': 'Braunau am Inn, Austria',
      'stockerau': 'Stockerau, Austria',
      'saalfelden': 'Saalfelden, Austria',
      'ansfelden': 'Ansfelden, Austria',
      'hollabrunn': 'Hollabrunn, Austria',
      'spittal an der drau': 'Spittal an der Drau, Austria',
      'tulln': 'Tulln, Austria',
      'telfs': 'Telfs, Austria',
      'ternitz': 'Ternitz, Austria',
      'perchtoldsdorf': 'Perchtoldsdorf, Austria',
      'zell am see': 'Zell am See, Austria',
      'voitsberg': 'Voitsberg, Austria',
      'st. veit an der glan': 'St. Veit an der Glan, Austria',
      'korneuburg': 'Korneuburg, Austria',
      'neunkirchen': 'Neunkirchen, Austria',
      'hard': 'Hard, Austria',
      'wattens': 'Wattens, Austria',
      'lienz': 'Lienz, Austria',
      'knittelfeld': 'Knittelfeld, Austria',
      'schwaz': 'Schwaz, Austria',
      'eisenstadt': 'Eisenstadt, Austria',
      'gmunden': 'Gmunden, Austria',
      'bischofshofen': 'Bischofshofen, Austria',
      'wörgl': 'Wörgl, Austria',
      'götzis': 'Götzis, Austria',
      'sankt johann im pongau': 'Sankt Johann im Pongau, Austria',
      'kitzbühel': 'Kitzbühel, Austria',
      'imst': 'Imst, Austria',
      'lauterach': 'Lauterach, Austria',
      'rum': 'Rum, Austria',
      'hohenems': 'Hohenems, Austria',
      'frastanz': 'Frastanz, Austria',
      'rankweil': 'Rankweil, Austria',
      
      // Schweiz - Städte
      'zürich': 'Zurich, Switzerland',
      'zurich': 'Zurich, Switzerland',
      'genf': 'Geneva, Switzerland',
      'geneva': 'Geneva, Switzerland',
      'basel': 'Basel, Switzerland',
      'bern': 'Bern, Switzerland',
      'lausanne': 'Lausanne, Switzerland',
      'winterthur': 'Winterthur, Switzerland',
      'luzern': 'Lucerne, Switzerland',
      'lucerne': 'Lucerne, Switzerland',
      'st. gallen': 'St. Gallen, Switzerland',
      'lugano': 'Lugano, Switzerland',
      'biel': 'Biel, Switzerland',
      'thun': 'Thun, Switzerland',
      'köniz': 'Köniz, Switzerland',
      'la chaux-de-fonds': 'La Chaux-de-Fonds, Switzerland',
      'fribourg': 'Fribourg, Switzerland',
      'schaffhausen': 'Schaffhausen, Switzerland',
      'chur': 'Chur, Switzerland',
      'vernier': 'Vernier, Switzerland',
      'neuchâtel': 'Neuchâtel, Switzerland',
      'uster': 'Uster, Switzerland',
      'sion': 'Sion, Switzerland',
      'lancy': 'Lancy, Switzerland',
      'pully': 'Pully, Switzerland',
      'kriens': 'Kriens, Switzerland',
      'dübendorf': 'Dübendorf, Switzerland',
      'dietikon': 'Dietikon, Switzerland',
      'montreux': 'Montreux, Switzerland',
      'rapperswil-jona': 'Rapperswil-Jona, Switzerland',
      'frauenfeld': 'Frauenfeld, Switzerland',
      'wettingen': 'Wettingen, Switzerland',
      'riex': 'Riex, Switzerland',
      'carouge': 'Carouge, Switzerland',
      'reinach': 'Reinach, Switzerland',
      'meyrin': 'Meyrin, Switzerland',
      'horgen': 'Horgen, Switzerland',
    };
    
    final normalized = cityMap[raw.toLowerCase()];
    if (normalized != null) {
      return {
        'location': normalized,
        'hl': 'en',
        'gl': normalized.endsWith('Austria') ? 'at' : 
             normalized.endsWith('Switzerland') ? 'ch' : 'de'
      };
    }
    
    // Fallback: Deutschland
    return {'location': 'Germany', 'hl': 'en', 'gl': 'de'};
  }

  String _toEnglishCountry(String s) {
    final l = s.toLowerCase();
    if (l.contains('deutschland') || l == 'de') return 'Germany';
    if (l.contains('österreich') || l == 'at' || l.contains('austria')) return 'Austria';
    if (l.contains('schweiz') || l == 'ch' || l.contains('switzerland')) return 'Switzerland';
    return s;
  }

  List<String> _extractList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data.map((e) => e.toString()).toList();
    if (data is String) return [data];
    return [];
  }

  String _extractPostalCode(String location) {
    final match = RegExp(r'\b(\d{4,5})\b').firstMatch(location);
    return match?.group(1) ?? '';
  }
}
