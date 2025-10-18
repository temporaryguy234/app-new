import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/resume_analysis_model.dart';
import '../../config/colors.dart';
import '../scoring/resume_scoring_screen.dart';

class AnalysisListScreen extends StatelessWidget {
  const AnalysisListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gespeicherte Analysen'),
        backgroundColor: AppColors.surface,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('resume_analyses')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Noch keine Analysen verfügbar'),
                  SizedBox(height: 8),
                  Text('Lade deinen ersten Lebenslauf hoch'),
                ],
              ),
            );
          }
          
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final analysis = ResumeAnalysisModel.fromMap(data);
              
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getScoreColor(analysis.score),
                    child: Text(
                      '${analysis.score.toInt()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text('Score: ${analysis.formattedScore}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Level: ${analysis.experienceText}'),
                      Text('Standort: ${analysis.location}'),
                      Text('Erstellt: ${_formatDate(analysis.createdAt)}'),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResumeScoringScreen(analysis: analysis),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
