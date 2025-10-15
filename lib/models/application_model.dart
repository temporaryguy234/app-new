enum ApplicationStatus {
  applied,      // Beworben
  interview,    // Interview
  offer,        // Angebot erhalten
  rejected,     // Abgelehnt
  accepted,     // Angenommen
  withdrawn     // Zurückgezogen
}

class ApplicationModel {
  final String id;
  final String jobId;
  final String jobTitle;
  final String company;
  final String applicationUrl;
  final DateTime applicationDate;
  final ApplicationStatus status;
  final String? notes;
  final DateTime? nextFollowUp;
  final bool reminderEnabled;
  final String? interviewDate;
  final String? salaryOffer;
  final String? contactPerson;

  ApplicationModel({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.company,
    required this.applicationUrl,
    required this.applicationDate,
    required this.status,
    this.notes,
    this.nextFollowUp,
    this.reminderEnabled = false,
    this.interviewDate,
    this.salaryOffer,
    this.contactPerson,
  });

  factory ApplicationModel.fromMap(Map<String, dynamic> map) {
    return ApplicationModel(
      id: map['id'] ?? '',
      jobId: map['jobId'] ?? '',
      jobTitle: map['jobTitle'] ?? '',
      company: map['company'] ?? '',
      applicationUrl: map['applicationUrl'] ?? '',
      applicationDate: DateTime.parse(map['applicationDate']),
      status: ApplicationStatus.values.firstWhere(
        (e) => e.toString() == 'ApplicationStatus.${map['status']}',
        orElse: () => ApplicationStatus.applied,
      ),
      notes: map['notes'],
      nextFollowUp: map['nextFollowUp'] != null ? DateTime.parse(map['nextFollowUp']) : null,
      reminderEnabled: map['reminderEnabled'] ?? false,
      interviewDate: map['interviewDate'],
      salaryOffer: map['salaryOffer'],
      contactPerson: map['contactPerson'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'company': company,
      'applicationUrl': applicationUrl,
      'applicationDate': applicationDate.toIso8601String(),
      'status': status.toString().split('.').last,
      'notes': notes,
      'nextFollowUp': nextFollowUp?.toIso8601String(),
      'reminderEnabled': reminderEnabled,
      'interviewDate': interviewDate,
      'salaryOffer': salaryOffer,
      'contactPerson': contactPerson,
    };
  }

  ApplicationModel copyWith({
    String? id,
    String? jobId,
    String? jobTitle,
    String? company,
    String? applicationUrl,
    DateTime? applicationDate,
    ApplicationStatus? status,
    String? notes,
    DateTime? nextFollowUp,
    bool? reminderEnabled,
    String? interviewDate,
    String? salaryOffer,
    String? contactPerson,
  }) {
    return ApplicationModel(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      company: company ?? this.company,
      applicationUrl: applicationUrl ?? this.applicationUrl,
      applicationDate: applicationDate ?? this.applicationDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      nextFollowUp: nextFollowUp ?? this.nextFollowUp,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      interviewDate: interviewDate ?? this.interviewDate,
      salaryOffer: salaryOffer ?? this.salaryOffer,
      contactPerson: contactPerson ?? this.contactPerson,
    );
  }

  String get statusText {
    switch (status) {
      case ApplicationStatus.applied:
        return 'Beworben';
      case ApplicationStatus.interview:
        return 'Interview';
      case ApplicationStatus.offer:
        return 'Angebot';
      case ApplicationStatus.rejected:
        return 'Abgelehnt';
      case ApplicationStatus.accepted:
        return 'Angenommen';
      case ApplicationStatus.withdrawn:
        return 'Zurückgezogen';
    }
  }

  String get statusColor {
    switch (status) {
      case ApplicationStatus.applied:
        return 'blue';
      case ApplicationStatus.interview:
        return 'orange';
      case ApplicationStatus.offer:
        return 'green';
      case ApplicationStatus.rejected:
        return 'red';
      case ApplicationStatus.accepted:
        return 'green';
      case ApplicationStatus.withdrawn:
        return 'gray';
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(applicationDate);
    
    if (difference.inDays > 0) {
      return 'vor ${difference.inDays} Tag${difference.inDays > 1 ? 'en' : ''}';
    } else if (difference.inHours > 0) {
      return 'vor ${difference.inHours} Stunde${difference.inHours > 1 ? 'n' : ''}';
    } else {
      return 'gerade eben';
    }
  }
}
