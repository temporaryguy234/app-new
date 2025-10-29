import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/job_model.dart';
import '../models/filter_model.dart';
import '../models/application_model.dart';
import '../models/job_cache_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Check if user has uploaded a resume / has an analysis
  Future<bool> userHasResume(String userId) async {
    try {
      // Our app stores analysis in top-level collection 'resume_analyses' with docId=userId
      final analysisDoc = await _firestore.collection('resume_analyses').doc(userId).get();
      if (analysisDoc.exists) return true;

      // Also accept presence of an uploaded resume metadata in 'resumes'
      final resumeDoc = await _firestore.collection('resumes').doc(userId).get();
      if (resumeDoc.exists) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  // Save job to user's saved jobs
  Future<void> saveJob(JobModel job) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_jobs')
          .doc(job.id)
          .set(job.toMap());
    } catch (e) {
      throw Exception('Failed to save job: $e');
    }
  }

  // Remove job from saved jobs
  Future<void> removeJob(String jobId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_jobs')
          .doc(jobId)
          .delete();
    } catch (e) {
      throw Exception('Failed to remove job: $e');
    }
  }

  // Get all saved jobs for current user
  Future<List<JobModel>> getSavedJobs() async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_jobs')
          .get();
      
      return snapshot.docs
          .map((doc) => JobModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get saved jobs: $e');
    }
  }

  // Save rejected job
  Future<void> saveRejectedJob(JobModel job) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('rejected_jobs')
          .doc(job.id)
          .set(job.toMap());
    } catch (e) {
      throw Exception('Failed to save rejected job: $e');
    }
  }

  // Save user filters
  Future<void> saveFilters(FilterModel filters) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .set({
        'filters': filters.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save filters: $e');
    }
  }

  // Get user filters
  Future<FilterModel?> getFilters() async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      
      if (doc.exists && doc.data()?['filters'] != null) {
        return FilterModel.fromMap(doc.data()!['filters']);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get filters: $e');
    }
  }

  // Check if job is saved
  Future<bool> isJobSaved(String jobId) async {
    if (currentUserId == null) return false;
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('saved_jobs')
          .doc(jobId)
          .get();
      
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get saved jobs stream for real-time updates
  Stream<List<JobModel>> getSavedJobsStream() {
    if (currentUserId == null) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('saved_jobs')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JobModel.fromMap(doc.data()))
            .toList());
  }

  // Application tracking methods
  Future<void> createApplication(ApplicationModel application) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('applications')
          .doc(application.id)
          .set(application.toMap());
    } catch (e) {
      throw Exception('Failed to create application: $e');
    }
  }

  Future<void> updateApplicationStatus(String applicationId, ApplicationStatus status) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('applications')
          .doc(applicationId)
          .update({
        'status': status.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update application status: $e');
    }
  }

  Future<void> updateApplication(ApplicationModel application) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('applications')
          .doc(application.id)
          .update(application.toMap());
    } catch (e) {
      throw Exception('Failed to update application: $e');
    }
  }

  Future<List<ApplicationModel>> getApplications() async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('applications')
          .orderBy('applicationDate', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => ApplicationModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get applications: $e');
    }
  }

  Stream<List<ApplicationModel>> getApplicationsStream() {
    if (currentUserId == null) return Stream.value([]);
    
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('applications')
        .orderBy('applicationDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ApplicationModel.fromMap(doc.data()))
            .toList());
  }

  Future<void> deleteApplication(String applicationId) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('applications')
          .doc(applicationId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete application: $e');
    }
  }

  // Get applications by status
  Future<List<ApplicationModel>> getApplicationsByStatus(ApplicationStatus status) async {
    if (currentUserId == null) throw Exception('User not authenticated');
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('applications')
          .where('status', isEqualTo: status.toString().split('.').last)
          .orderBy('applicationDate', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => ApplicationModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get applications by status: $e');
    }
  }

  // Job cache methods
  Future<JobCacheModel?> getJobCache(String userId) async {
    try {
      final doc = await _firestore.collection('job_cache').doc(userId).get();
      if (!doc.exists) return null;
      return JobCacheModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting job cache: $e');
      return null;
    }
  }

  Future<void> saveJobCache(JobCacheModel cache) async {
    try {
      await _firestore.collection('job_cache').doc(cache.userId).set(cache.toFirestore());
    } catch (e) {
      print('Error saving job cache: $e');
      throw Exception('Failed to save job cache: $e');
    }
  }

  Future<void> updateJobOnlineStatus(String userId, Map<String, bool> status) async {
    try {
      await _firestore.collection('job_cache').doc(userId).update({
        'jobOnlineStatus': status,
        'lastVerifiedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating job online status: $e');
    }
  }

  Future<void> clearJobCache(String userId) async {
    try {
      await _firestore.collection('job_cache').doc(userId).delete();
    } catch (e) {
      print('Error clearing job cache: $e');
    }
  }
}
