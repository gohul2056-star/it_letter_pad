import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/painting.dart' as p;
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'attendance_screen.dart';

class PdfGeneratorService {
  Future<Uint8List?> pickExcelFile() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'Excel Files',
      extensions: <String>['xlsx', 'xls'],
    );
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    
    if (file != null) {
      return await file.readAsBytes();
    }
    return null;
  }

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

  Future<Uint8List> generatePdfFromData(List<dynamic> students) async {
    final englishFont = await PdfGoogleFonts.robotoRegular();
    final englishBold = await PdfGoogleFonts.robotoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: englishFont,
        bold: englishBold,
      ),
    );

    // Pre-generate static Tamil text images using Flutter's TextPainter (perfect shaping)
    final p.TextStyle tamilStyle14Bold = GoogleFonts.notoSansTamil(fontSize: 14, fontWeight: p.FontWeight.bold, color: const p.Color(0xFF000000));
    final p.TextStyle tamilStyle12Bold = GoogleFonts.notoSansTamil(fontSize: 12, fontWeight: p.FontWeight.bold, color: const p.Color(0xFF000000));
    final p.TextStyle tamilStyle12Italic = GoogleFonts.notoSansTamil(fontSize: 12, fontStyle: p.FontStyle.italic, color: const p.Color(0xFF000000));
    final p.TextStyle tamilStyle12 = GoogleFonts.notoSansTamil(fontSize: 12, color: const p.Color(0xFF000000));
    final p.TextStyle tamilStyle10 = GoogleFonts.notoSansTamil(fontSize: 10, color: const p.Color(0xFF000000));
    final p.TextStyle englishStyleBold = const p.TextStyle(fontWeight: p.FontWeight.bold, fontFamily: 'Roboto', color: p.Color(0xFF000000));
    
    final pwHeader1 = await _buildTextImage(p.TextSpan(text: 'டாக்டர் சிவந்தி ஆதித்தனார் பொறியியல் கல்லூரி', style: tamilStyle14Bold));
    final pwHeader2 = await _buildTextImage(p.TextSpan(text: 'திருச்செந்தூர் - 628 215', style: tamilStyle12Bold));
    final pwDateLabel = await _buildTextImage(p.TextSpan(text: 'நாள்: ', style: tamilStyle12Bold));
    final pwToLabel = await _buildTextImage(p.TextSpan(text: 'பெறுநர்:', style: tamilStyle12Italic));
    final pwSalutation = await _buildTextImage(p.TextSpan(text: 'ஐயா,', style: tamilStyle12Italic));
    final pwPara2 = await _buildTextImage(
      p.TextSpan(text: '\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0பல்கலைக் கழகத் தேர்வு விதிமுறைகளின் படி ஒரு மாணவரின் வருகை பதிவு 75 சதவீதத்திற்கு குறைவாக இருந்தால் அவரை பல்கலைக்கழக தேர்வுகள் எழுத அனுமதிக்க இயலாது. மற்றும் இந்த பருவத்தின் கடைசி வேலை நாளுக்குள் உங்களது மகன் வருகைப்பதிவு 75% க்கு அதிகமாக இருக்க நாள் தவறாது வகுப்புக்கு குறித்த நேரத்தில் வருகை புரிய தகுந்த அறிவுரை கூறவும். எனவே இக்கடிதம் கண்டவுடன் துறை தலைவரை உடனே சந்திக்கவும்.', style: tamilStyle12),
      maxWidth: 515,
      textAlign: p.TextAlign.justify,
    );
    final pwThanks = await _buildTextImage(p.TextSpan(text: 'நன்றி.', style: tamilStyle12));
    final pwYours = await _buildTextImage(p.TextSpan(text: 'இப்படிக்கு,', style: tamilStyle12));
    final pwHodTitle = await _buildTextImage(p.TextSpan(text: 'துறைத்தலைவர்', style: tamilStyle10));
    final pwAdvTitle = await _buildTextImage(p.TextSpan(text: 'ஆலோசகர்', style: tamilStyle10));
    final pwPrinTitle = await _buildTextImage(p.TextSpan(text: 'முதல்வர்', style: tamilStyle10));

    for (var student in students) {
      String studentName = student.name;
      String studentAddress = student.address;
      String attendance = student.attendance;
      String date = student.date;
      String advisor = student.advisor;
      String fromDate = student.fromDate ?? '01.07.2026';
      String toDate = student.toDate ?? '21.07.2026';

      if (studentName.trim().isEmpty) {
        continue; 
      }

      // Generate dynamic paragraph 1 image for this specific student
      final pwPara1 = await _buildTextImage(
        p.TextSpan(
          style: tamilStyle12,
          children: [
            const p.TextSpan(text: '\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0\u00A0எங்களது கல்லூரியில் இறுதி ஆண்டு Information Technology துறையில் பயிலும் தங்களது மகன்/மகள் '),
            p.TextSpan(text: studentName, style: englishStyleBold),
            const p.TextSpan(text: ' அவர்களின் கல்லூரி வருகைப்பதிவு '),
            p.TextSpan(text: attendance, style: englishStyleBold),
            const p.TextSpan(text: '% ஆக உள்ளது. ('),
            p.TextSpan(text: fromDate, style: englishStyleBold),
            const p.TextSpan(text: ' முதல் '),
            p.TextSpan(text: toDate, style: englishStyleBold),
            const p.TextSpan(text: ' வரை).'),
          ]
        ),
        maxWidth: 515,
        textAlign: p.TextAlign.justify,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pwHeader1,
                pwHeader2,
                pw.SizedBox(height: 5),
                pw.Text('OFFICE : 04639 - 242482', style: pw.TextStyle(font: englishFont, fontSize: 10)),
                pw.Text('FAX : 243188', style: pw.TextStyle(font: englishFont, fontSize: 10)),
                pw.Divider(thickness: 1),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Dr. G. Wiselin Jiji', style: pw.TextStyle(font: englishBold, fontSize: 11)),
                        pw.Text('PRINCIPAL', style: pw.TextStyle(font: englishBold, fontSize: 11)),
                      ]
                    ),
                    pw.Row(
                      children: [
                        pwDateLabel,
                        pw.Text(date, style: pw.TextStyle(font: englishBold, fontSize: 12)),
                      ]
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                pwToLabel,
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 30, top: 2),
                  child: pw.Text(
                    studentName + ',\n' + studentAddress.replaceAll(', ', ',\n'), 
                    style: pw.TextStyle(font: englishFont, fontSize: 12, lineSpacing: 2)
                  ),
                ),
                pw.SizedBox(height: 20),

                pwSalutation,
                pw.SizedBox(height: 10),

                pwPara1,
                pw.SizedBox(height: 15),

                pwPara2,
                pw.SizedBox(height: 20),

                pw.Center(child: pwThanks),
                pw.SizedBox(height: 20),

                pw.Align(alignment: pw.Alignment.centerRight, child: pwYours),
                pw.SizedBox(height: 60),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Dr. S. Selvi, Prof & HOD/IT', style: pw.TextStyle(font: englishBold, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pwHodTitle,
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          (advisor.isNotEmpty ? advisor : 'Ms. K. Ramya Thamizharasi, AP/IT').replaceAll(' & ', '\n'), 
                          style: pw.TextStyle(font: englishBold, fontSize: 10),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 2),
                        pwAdvTitle,
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('Dr. G. Wiselin Jiji', style: pw.TextStyle(font: englishBold, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pwPrinTitle,
                      ]
                    ),
                  ]
                ),
                
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1.5),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('From:', style: pw.TextStyle(font: englishFont, fontSize: 10)),
                          pw.SizedBox(height: 10),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 20),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('The Principal', style: pw.TextStyle(font: englishFont, fontSize: 10)),
                                pw.Text('Dr. Sivanthi Aditanar College of Engineering', style: pw.TextStyle(font: englishFont, fontSize: 10)),
                                pw.Text('Tiruchendur 628215', style: pw.TextStyle(font: englishFont, fontSize: 10)),
                                pw.Text('Tuticorin.', style: pw.TextStyle(font: englishFont, fontSize: 10)),
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
                          pw.Text('To', style: pw.TextStyle(font: englishFont, fontSize: 10)),
                          pw.SizedBox(height: 10),
                          pw.Text(studentName + ',', style: pw.TextStyle(font: englishFont, fontSize: 10)),
                          pw.Text(studentAddress.replaceAll(', ', ',\n'), style: pw.TextStyle(font: englishFont, fontSize: 10, lineSpacing: 2)),
                        ]
                      )
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('STAMP', style: pw.TextStyle(font: englishFont, fontSize: 10)),
                          pw.SizedBox(height: 5),
                          pw.Container(
                            width: 40,
                            height: 50,
                            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1))
                          )
                        ]
                      )
                    )
                  ]
                )
              ],
            );
          },
        ),
      );
    }

    return await pdf.save();
  }
}
