import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/resume_analysis_model.dart';

class CvExportService {
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  Future<String> exportImprovedCv(ResumeAnalysisModel analysis) async {
    // Build a clean PDF using analysis fields
    final doc = PdfDocument();
    final page = doc.pages.add();
    final bounds = Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height);
    final headerBrush = PdfSolidBrush(PdfColor(33, 150, 243));
    final textBrush = PdfSolidBrush(PdfColor(33, 33, 33));
    final subBrush = PdfSolidBrush(PdfColor(97, 97, 97));

    // Header
    page.graphics.drawRectangle(brush: headerBrush, bounds: Rect.fromLTWH(0, 0, bounds.width, 60));
    final userEmail = _auth.currentUser?.email ?? '';
    final title = 'Lebenslauf';
    PdfFont headerFont = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    page.graphics.drawString(title, headerFont, bounds: Rect.fromLTWH(20, 18, bounds.width - 40, 30), brush: PdfBrushes.white);
    if (userEmail.isNotEmpty) {
      PdfFont emailFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
      page.graphics.drawString(userEmail, emailFont, bounds: Rect.fromLTWH(20, 44, bounds.width - 40, 14), brush: PdfBrushes.white);
    }

    double y = 80;

    void section(String title, List<String> lines) {
      if (lines.isEmpty) return;
      final fTitle = PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold);
      final fBody = PdfStandardFont(PdfFontFamily.helvetica, 11);
      page.graphics.drawString(title, fTitle, bounds: Rect.fromLTWH(20, y, bounds.width - 40, 18), brush: textBrush);
      y += 20;
      for (final l in lines) {
        page.graphics.drawString('• $l', fBody, bounds: Rect.fromLTWH(26, y, bounds.width - 52, 16), brush: subBrush);
        y += 16;
      }
      y += 10;
    }

    // Summary and meta
    final metaFont = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final locationLine = analysis.location.isNotEmpty ? 'Standort: ${analysis.location}' : '';
    final xpLine = 'Erfahrung: ${analysis.experienceText}';
    final scoreLine = 'Profil-Score: ${analysis.formattedScore}';
    page.graphics.drawString(analysis.summary, metaFont, bounds: Rect.fromLTWH(20, y, bounds.width - 40, 48), brush: textBrush);
    y += 56;
    if (locationLine.isNotEmpty) {
      page.graphics.drawString(locationLine, metaFont, bounds: Rect.fromLTWH(20, y, bounds.width - 40, 16), brush: subBrush);
      y += 18;
    }
    page.graphics.drawString(xpLine, metaFont, bounds: Rect.fromLTWH(20, y, bounds.width - 40, 16), brush: subBrush);
    y += 18;
    page.graphics.drawString(scoreLine, metaFont, bounds: Rect.fromLTWH(20, y, bounds.width - 40, 16), brush: subBrush);
    y += 24;

    section('Stärken', analysis.strengths.take(8).toList());
    section('Verbesserungen', analysis.improvements.take(6).toList());
    section('Top‑Skills', analysis.topSkills);
    section('Branchen', analysis.industries);

    final bytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();

    final uid = _auth.currentUser?.uid ?? analysis.userId;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('cv_exports/$uid/$ts.pdf');
    await ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
    final url = await ref.getDownloadURL();
    // Optionally record latest URL in Firestore
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'cvExport': {
        'url': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
    return url;
  }
}


