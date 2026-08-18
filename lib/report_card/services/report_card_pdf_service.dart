import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/painting.dart' as p;
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/report_card_data.dart';
import '../models/report_card_config.dart';

class ReportCardPdfService {
  Future<pw.Widget> _buildTextImage(p.InlineSpan textSpan, {double maxWidth = double.infinity, p.TextAlign textAlign = p.TextAlign.left}) async {
    final textPainter = p.TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
      textAlign: textAlign,
    );
    final scale = 3.0; // High resolution for PDF
    textPainter.textScaleFactor = scale;
    textPainter.layout(minWidth: 0, maxWidth: maxWidth == double.infinity ? double.infinity : maxWidth * scale);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    textPainter.paint(canvas, ui.Offset.zero);
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(textPainter.width.ceil(), textPainter.height.ceil());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final memoryImage = pw.MemoryImage(byteData!.buffer.asUint8List());
    
    return pw.Image(
      memoryImage, 
      width: textPainter.width / scale,
      height: textPainter.height / scale,
      fit: pw.BoxFit.fill,
    );
  }

  Future<Uint8List> generateReportCards(List<ReportCardData> students, ReportCardConfig config) async {
    final englishFont = await PdfGoogleFonts.robotoRegular();
    final englishBold = await PdfGoogleFonts.robotoBold();
    
    final ByteData logoData = await rootBundle.load('assets/icons/SAECO.png');
    final pw.ImageProvider logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: englishFont,
        bold: englishBold,
      ),
    );

    final p.TextStyle tamilStyle12Bold = GoogleFonts.notoSansTamil(fontSize: 11, color: const p.Color(0xFF000000));
    final p.TextStyle tamilStyle12 = GoogleFonts.notoSansTamil(fontSize: 12, color: const p.Color(0xFF000000),fontWeight: FontWeight.bold);
    await GoogleFonts.pendingFonts();

    final pwPara1 = await _buildTextImage(
      p.TextSpan(
        text: '\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0'
            'என்னுடைய மகன்/மகள் வகுப்பு தேர்ச்சியை அறிந்து கொண்டேன். '
            'அடுத்த தேர்வில் நல்ல முறையில் தேர்ச்சி பெற அறிவுரை கூறுகிறேன். '
            'இத்துடன் இந்த தேர்ச்சி அறிக்கையை திருப்பி அனுப்புகிறேன்.',
        style: tamilStyle12Bold,
      ),
      maxWidth: 520,
      textAlign: p.TextAlign.left,
    );
    
    final pwPara2 = await _buildTextImage(
      p.TextSpan(
        text: '\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0'
            'என்னுடைய மகன்/மகள் வகுப்பு தேர்வுகள் அனைத்திலும் சேர்த்து '
            'குறைந்தபட்சம் 50% மதிப்பெண்களும் வருகை விழுக்காடு 75% பெற்றால் தான் '
            'பல்கலைக்கழக தேர்விற்கு அனுமதிக்கப்படுவார்கள் என்பதையும் நான் அறிவேன்.',
        style: tamilStyle12Bold,
      ),
      maxWidth: 520,
      textAlign: p.TextAlign.left,
    );

    final pwParentSig = await _buildTextImage(p.TextSpan(text: 'பெற்றோர் கையொப்பம்', style: tamilStyle12));

    final now = DateTime.now();
    final currentDateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final fromDateStr = config.fromDate != null ? '${config.fromDate!.day.toString().padLeft(2, '0')}/${config.fromDate!.month.toString().padLeft(2, '0')}/${config.fromDate!.year}' : '';
    final toDateStr = config.toDate != null ? '${config.toDate!.day.toString().padLeft(2, '0')}/${config.toDate!.month.toString().padLeft(2, '0')}/${config.toDate!.year}' : '';
    final String advisorsStr = config.advisors.join('\n');

    for (var student in students) {
      double attendance = 0.0;
      if (config.workingDays > 0) {
        attendance = ((config.workingDays - student.daysAbsent) / config.workingDays) * 100;
      }
      final String attendanceStr = '${attendance.toStringAsFixed(2)}%';

      // Calculate totals for configured subjects only
      int totalMarksCalculated = 0;
      int scoredMarksCalculated = 0;
      int totalPasses = 0;
      
      for (var mapping in config.subjectMappings) {
        totalMarksCalculated += 100;
        String norm(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
        final markData = student.subjects.firstWhere((m) => norm(m.subjectCode) == norm(mapping.subjectCode), orElse: () => SubjectMark(subjectName: '', subjectCode: '', totalMark: '', passingMark: '', scoredMark: '#N/A', passFail: '#N/A'));
        
        if (markData.scoredMark == '#N/A') {
          // If any subject is missing, we might want to flag the total as N/A
        } else {
          int? sMark = int.tryParse(markData.scoredMark);
          if (sMark != null) {
            scoredMarksCalculated += sMark;
            if (sMark >= 50) totalPasses++;
          }
        }
      }
      
      String displayScoredMarks = scoredMarksCalculated > 0 ? scoredMarksCalculated.toString() : (student.subjects.any((s) => s.scoredMark == '#N/A') ? '#N/A' : '0');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topCenter,
              child: pw.Container(
                width: PdfPageFormat.a4.width - 40, // Account for margins
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 3),
                      ),
                      padding: const pw.EdgeInsets.all(15),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildHeaderBlock(englishFont, englishBold, config, logoImage),
                          pw.SizedBox(height: 10),
                          _buildHeaderInfo(englishFont, englishBold, config, currentDateStr),
                          pw.SizedBox(height: 10),
                          _buildStudentInfo(student, englishFont, englishBold, config),
                          pw.SizedBox(height: 15),
                          _buildSubjectsTable(student, config, englishFont, englishBold),
                          pw.SizedBox(height: 15),
                          _buildResultsTable(student, totalMarksCalculated.toString(), displayScoredMarks, student.rank, attendanceStr, fromDateStr, toDateStr, englishFont, englishBold, config),
                          pw.SizedBox(height: 20),
                          _buildSignaturesBlock(advisorsStr, englishFont, englishBold),
                          pw.SizedBox(height: 10),
                          pwPara1,
                          pw.SizedBox(height: 10),
                          pwPara2,
                          pw.SizedBox(height: 40),
                          pw.Align(alignment: pw.Alignment.centerRight, child: pwParentSig),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    _buildFooterBlock(student, englishFont, englishBold),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return await pdf.save();
  }

  pw.Widget _buildHeaderBlock(pw.Font englishFont, pw.Font englishBold, ReportCardConfig config, pw.ImageProvider logoImage) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.start,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Image(logoImage, width: 60, height: 60),
        pw.SizedBox(width: 15),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('Dr. Sivanthi Aditanar College of Engineering', style: pw.TextStyle(font: englishBold, fontSize: 16)),
              pw.SizedBox(height: 5),
              pw.Text(' Tiruchendur', style: pw.TextStyle(font: englishBold, fontSize: 16)),
              pw.SizedBox(height: 5),
              pw.Text('Department of Information Technology', style: pw.TextStyle(font: englishBold, fontSize: 14)),
              pw.SizedBox(height: 5),
              pw.Text('Periodical Test - ${config.periodicalTestNumber} Progress Report : ${config.academicYear}(${config.semesterType})', style: pw.TextStyle(font: englishBold, fontSize: 12, decoration: pw.TextDecoration.underline)),
            ],
          ),
        ),

        pw.SizedBox(width: 75), 
      ],
    );
  }

  pw.Widget _buildHeaderInfo(pw.Font englishFont, pw.Font englishBold, ReportCardConfig config, String currentDate) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text('Year & Sem : ${config.year.replaceAll(' Year', '')} & ${config.semester.replaceAll(' Semester', '')}', style: pw.TextStyle(font: englishBold, fontSize: 12)),
        ),
        pw.SizedBox(height: 5),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Date : $currentDate', style: pw.TextStyle(font: englishBold, fontSize: 12)),
        ),
      ]
    );
  }

  pw.Widget _buildStudentInfo(ReportCardData student, pw.Font englishFont, pw.Font englishBold, ReportCardConfig config) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(children: [
          pw.SizedBox(width: 80, child: pw.Text('Roll No.', style: pw.TextStyle(font: englishFont, fontSize: 11))),
          pw.Text(': ${student.rollNo}', style: pw.TextStyle(font: englishFont, fontSize: 11)),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.SizedBox(width: 80, child: pw.Text('Student Name', style: pw.TextStyle(font: englishFont, fontSize: 11))),
          pw.Text(': ${student.studentName}', style: pw.TextStyle(font: englishFont, fontSize: 11)),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.SizedBox(width: 80, child: pw.Text('Class & Sem', style: pw.TextStyle(font: englishFont, fontSize: 11))),
          pw.Text(': ${config.year.replaceAll(' Year', '')} IT & ${config.semester.replaceAll(' Semester', '')}', style: pw.TextStyle(font: englishFont, fontSize: 11)),
        ]),
      ]
    );
  }

  pw.Widget _buildSubjectsTable(ReportCardData student, ReportCardConfig config, pw.Font englishFont, pw.Font englishBold) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Subject Name with Code', style: pw.TextStyle(font: englishBold, fontSize: 10), textAlign: pw.TextAlign.center)),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Total Mark', style: pw.TextStyle(font: englishBold, fontSize: 10), textAlign: pw.TextAlign.center)),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Passing Mark', style: pw.TextStyle(font: englishBold, fontSize: 10), textAlign: pw.TextAlign.center)),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Scored Mark', style: pw.TextStyle(font: englishBold, fontSize: 10), textAlign: pw.TextAlign.center)),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Pass/Fail', style: pw.TextStyle(font: englishBold, fontSize: 10), textAlign: pw.TextAlign.center)),
          ]
        ),
        for (var mapping in config.subjectMappings)
          (){
            String norm(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
            final markData = student.subjects.firstWhere((m) => norm(m.subjectCode) == norm(mapping.subjectCode), orElse: () => SubjectMark(subjectName: '', subjectCode: '', totalMark: '', passingMark: '', scoredMark: '#N/A', passFail: '#N/A'));
            return pw.TableRow(
              children: [
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Container(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(right: pw.BorderSide(color: PdfColors.black, width: 1))
                        ),
                        padding: const pw.EdgeInsets.all(5), 
                        alignment: pw.Alignment.center,
                        child: pw.Text(mapping.subjectName, style: pw.TextStyle(font: englishFont, fontSize: 10), textAlign: pw.TextAlign.center)
                      )
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(5), 
                        alignment: pw.Alignment.center,
                        child: pw.Text(mapping.subjectCode, style: pw.TextStyle(font: englishBold, fontSize: 10), textAlign: pw.TextAlign.center)
                      )
                    ),
                  ]
                ),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('100', style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('50', style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text(markData.scoredMark, style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text(markData.passFail, style: pw.TextStyle(font: englishBold, fontSize: 10)))),
              ]
            );
          }(),
        if (config.includePlacement)
          (){
            String passFail = 'Fail';
            if (student.placementMark != null && student.placementMark!.isNotEmpty) {
              String pm = student.placementMark!.toUpperCase();
              if (pm == 'AB' || pm == 'AAA' || pm == 'U') {
                passFail = 'Fail';
              } else {
                int markInt = int.tryParse(student.placementMark!) ?? 0;
                if (markInt >= 50) passFail = 'Pass';
              }
            }
            return pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('Placement', style: pw.TextStyle(font: englishFont, fontSize: 10)))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('100', style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text('50', style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text(student.placementMark ?? '', style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text(passFail, style: pw.TextStyle(font: englishBold, fontSize: 10)))),
              ]
            );
          }(),
      ]
    );
  }

  pw.Widget _buildResultsTable(ReportCardData student, String totalMarks, String scoredMarks, String rank, String attendancePercentage, String fromDate, String toDate, pw.Font englishFont, pw.Font englishBold, ReportCardConfig config) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(
              width: 250,
              child: pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text('Total Marks', style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text(totalMarks, style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text('Scored Marks', style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text(scoredMarks, style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                  ]),
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text('Rank', style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                    pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text(rank.isEmpty ? '#N/A' : rank, style: pw.TextStyle(font: englishBold, fontSize: 10)))),
                  ]),
                ]
              )
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Attendance Percentage', style: pw.TextStyle(font: englishBold, fontSize: 11)),
                pw.SizedBox(width: 15),
                pw.Text(attendancePercentage, style: pw.TextStyle(font: englishBold, fontSize: 11)),
                pw.SizedBox(width: 15),
                pw.Text('From : $fromDate To : $toDate', style: pw.TextStyle(font: englishBold, fontSize: 11)),
              ]
            ),
            pw.SizedBox(height: 15),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 120, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Remarks  ', style: pw.TextStyle(font: englishBold, fontSize: 11)))),
                pw.Container(
                  width: 300,
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Text(_generateRemark(student, config), style: pw.TextStyle(font: englishBold, fontSize: 11)),
                )
              ]
            )
          ]
        )
      ]
    );
  }

  String _generateRemark(ReportCardData student, ReportCardConfig config) {
    bool hasFailed = false;
    bool isAbsent = false;

    for (var mapping in config.subjectMappings) {
      String norm(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
      var mark = student.subjects.firstWhere((m) => norm(m.subjectCode) == norm(mapping.subjectCode), orElse: () => SubjectMark(subjectName: '', subjectCode: '', totalMark: '', passingMark: '', scoredMark: '#N/A', passFail: '#N/A'));
      
      int? sMark = int.tryParse(mark.scoredMark);
      if (sMark != null) {
        if (sMark < 50) {
          hasFailed = true;
        }
      } else {
        isAbsent = true;
      }
    }

    if (hasFailed) return 'Get pass mark in all subjects.';
    if (isAbsent) return 'Attend all exams regularly.';

    double? att = double.tryParse(student.attendancePercentage.replaceAll('%', ''));
    if (att != null && att < 75.0) {
      return 'Attendance Percentage is very low. Come to class regularly.';
    }

    int? rank = int.tryParse(student.rank);
    if (rank != null) {
      if (rank >= 30 && rank <= 70) return 'Work Hard. Study well and can do better.';
      if (rank >= 20 && rank <= 29) return 'Good! Can do better.';
      if (rank >= 1 && rank <= 19) return 'Good. Aim to be First.';
    }

    return student.remarks.isNotEmpty ? student.remarks : 'Good.'; // Fallback
  }

  pw.Widget _buildSignaturesBlock(String advisors, pw.Font englishFont, pw.Font englishBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('FACULTY ADVISOR', style: pw.TextStyle(font: englishBold, fontSize: 11)),
            pw.Text(advisors, style: pw.TextStyle(font: englishFont, fontSize: 9), textAlign: pw.TextAlign.center),
          ]
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('HOD', style: pw.TextStyle(font: englishBold, fontSize: 11)),
            pw.Text('Dr. S. Selvi, Prof & HOD', style: pw.TextStyle(font: englishBold, fontSize: 10)),
          ]
        ),
      ]
    );
  }

  pw.Widget _buildFooterBlock(ReportCardData student, pw.Font englishFont, pw.Font englishBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('From', style: pw.TextStyle(font: englishBold, fontSize: 11)),
              pw.SizedBox(height: 5),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 15),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('The Principal,', style: pw.TextStyle(font: englishBold, fontSize: 11)),
                    pw.Text('Dr. Sivanthi Aditanar College of', style: pw.TextStyle(font: englishBold, fontSize: 11)),
                    pw.Text('Engineering,', style: pw.TextStyle(font: englishBold, fontSize: 11)),
                    pw.Text('Tirunelveli Road,', style: pw.TextStyle(font: englishBold, fontSize: 11)),
                    pw.Text('Tirucendur - 628 215.', style: pw.TextStyle(font: englishBold, fontSize: 11)),
                  ]
                )
              )
            ]
          )
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('To', style: pw.TextStyle(font: englishBold, fontSize: 11)),
              pw.SizedBox(height: 5),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 15),
                child: pw.Text(student.address, style: pw.TextStyle(font: englishBold, fontSize: 11)),
              )
            ]
          )
        ),
        pw.Expanded(
          flex: 1,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('STAMP', style: pw.TextStyle(font: englishBold, fontSize: 11)),
              pw.SizedBox(height: 5),
              pw.Container(
                width: 50,
                height: 60,
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1))
              )
            ]
          )
        )
      ]
    );
  }
}
