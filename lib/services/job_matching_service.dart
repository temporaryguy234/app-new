import '../models/job_model.dart';
import '../models/resume_analysis_model.dart';

class JobMatchingService {
  
  List<JobModel> matchJobsWithAnalysis(
    List<JobModel> jobs, 
    ResumeAnalysisModel analysis
  ) {
    final List<JobMatch> matches = [];
    
    for (final job in jobs) {
      final matchScore = _calculateMatchScore(job, analysis);
      if (matchScore > 0.3) { // Mindest-Score für Relevanz
        matches.add(JobMatch(job, matchScore));
      }
    }
    
    // Sortiere nach Match-Score (höchste zuerst)
    matches.sort((a, b) => b.score.compareTo(a.score));
    
    return matches.map((match) => match.job).toList();
  }
  
  double _calculateMatchScore(JobModel job, ResumeAnalysisModel analysis) {
    // Gewichtung: Skills 60%, Experience 25%, Industries 15%
    final skillScore = _calculateSkillMatch(job, analysis.skills) * 0.6;
    final experienceScore = _calculateExperienceMatch(job, analysis.experienceLevel) * 0.25;
    final industryScore = _calculateIndustryMatch(job, analysis.industries) * 0.15;
    
    final totalScore = skillScore + experienceScore + industryScore;
    
    // Debug-Logging
    print('🎯 Job: ${job.title} - Score: ${totalScore.toStringAsFixed(2)} (Skills: ${skillScore.toStringAsFixed(2)}, Experience: ${experienceScore.toStringAsFixed(2)}, Industry: ${industryScore.toStringAsFixed(2)})');
    
    return totalScore;
  }
  
  double _calculateSkillMatch(JobModel job, List<String> userSkills) {
    if (userSkills.isEmpty) return 0.0;
    
    final jobText = '${job.title} ${job.description}'.toLowerCase();
    int matches = 0;
    
    for (final skill in userSkills) {
      if (jobText.contains(skill.toLowerCase())) {
        matches++;
      }
    }
    
    return matches / userSkills.length;
  }
  
  double _calculateExperienceMatch(JobModel job, String userExperienceLevel) {
    final jobText = '${job.title} ${job.description}'.toLowerCase();
    
    // Mapping der Experience Levels
    final experienceKeywords = {
      'entry': ['junior', 'entry', 'trainee', 'praktikum', 'internship'],
      'mid': ['mid', 'erfahren', 'experienced', '3-5 jahre'],
      'senior': ['senior', 'lead', 'manager', '5+ jahre', 'expert'],
      'expert': ['expert', 'principal', 'architect', '10+ jahre']
    };
    
    final keywords = experienceKeywords[userExperienceLevel] ?? [];
    for (final keyword in keywords) {
      if (jobText.contains(keyword)) {
        return 1.0;
      }
    }
    
    return 0.5; // Neutraler Score wenn kein Match
  }
  
  double _calculateIndustryMatch(JobModel job, List<String> userIndustries) {
    if (userIndustries.isEmpty) return 0.5;
    
    final jobText = '${job.title} ${job.description} ${job.company}'.toLowerCase();
    int matches = 0;
    
    for (final industry in userIndustries) {
      if (jobText.contains(industry.toLowerCase())) {
        matches++;
      }
    }
    
    return matches / userIndustries.length;
  }
}

class JobMatch {
  final JobModel job;
  final double score;
  
  JobMatch(this.job, this.score);
}
