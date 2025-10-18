class ApplicationData {
  final String name;
  final String email;
  final String phone;
  final String address;
  final String resumeUrl;
  final String coverLetter;
  
  ApplicationData({
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.resumeUrl,
    required this.coverLetter,
  });
  
  Map<String, String> toFormData() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'resume_url': resumeUrl,
      'cover_letter': coverLetter,
    };
  }
}
