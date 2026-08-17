import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../models/report_card_data.dart';
import '../models/report_card_config.dart';
import '../services/report_card_pdf_service.dart';

class PreviewScreen extends StatefulWidget {
  final List<ReportCardData> students;
  final ReportCardConfig config;

  const PreviewScreen({Key? key, required this.students, required this.config}) : super(key: key);

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _isGenerating = false;
  final ReportCardPdfService _pdfService = ReportCardPdfService();

  Future<void> _generatePdf() async {
    setState(() => _isGenerating = true);
    try {
      final bytes = await _pdfService.generateReportCards(widget.students, widget.config);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Report_Cards.pdf',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Data Preview', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF296FD8),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Previewing ${widget.students.length} students loaded from Excel. Please verify the marks align correctly with the subjects.',
                    style: TextStyle(fontSize: 16, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.blue.shade100),
                  dataRowColor: MaterialStateProperty.all(Colors.white),
                  columns: [
                    DataColumn(label: Text('Roll No.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))),
                    DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))),
                    ...widget.config.subjectMappings.map((m) => DataColumn(
                      label: Text(m.subjectCode.isEmpty ? 'Subject' : m.subjectCode, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                    )),
                    DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))),
                    DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))),
                  ],
                  rows: widget.students.map((student) {
                    return DataRow(
                      cells: [
                        DataCell(Text(student.rollNo, style: TextStyle(color: Colors.blue.shade900))),
                        DataCell(Text(student.studentName, style: TextStyle(color: Colors.blue.shade900))),
                        ...widget.config.subjectMappings.map((mapping) {
                          String norm(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
                          var mark = student.subjects.firstWhere((m) => norm(m.subjectCode) == norm(mapping.subjectCode), orElse: () => SubjectMark(subjectName: '', subjectCode: '', totalMark: '', passingMark: '', scoredMark: '#N/A', passFail: '#N/A'));
                          return DataCell(
                            Text(
                              mark.scoredMark,
                              style: TextStyle(
                                color: mark.scoredMark == '#N/A' ? Colors.red : Colors.black,
                                fontWeight: mark.scoredMark == '#N/A' ? FontWeight.bold : FontWeight.normal,
                              )
                            )
                          );
                        }),
                        DataCell(Text(student.scoredMarks, style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold))),
                        DataCell(Text(student.rank, style: TextStyle(color: student.rank == '-' ? Colors.red : Colors.blue.shade900, fontWeight: FontWeight.bold))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generatePdf,
                    icon: _isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.picture_as_pdf),
                    label: Text(_isGenerating ? 'Generating...' : 'Confirm & Generate PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF296FD8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
