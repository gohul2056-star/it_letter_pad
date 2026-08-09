import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pdf_generator_service.dart';

class StudentData {
  String rollNo;
  String name;
  String address;
  String attendance;
  String date;
  String advisor;
  String fromDate;
  String toDate;

  StudentData({
    required this.rollNo,
    required this.name,
    required this.address,
    required this.attendance,
    required this.date,
    required this.advisor,
    this.fromDate = '',
    this.toDate = '',
  });
}

class AttendanceScreen extends StatefulWidget {
  final String year;
  final Uint8List excelBytes;
  final String fromDate;
  final String toDate;
  final int totalSelectedDays;
  final String advisor;

  const AttendanceScreen({
    super.key, 
    required this.year, 
    required this.excelBytes,
    required this.fromDate,
    required this.toDate,
    required this.totalSelectedDays,
    required this.advisor,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final PdfGeneratorService _pdfService = PdfGeneratorService();
  List<StudentData> _students = [];
  bool _isLoading = true;
  String _error = '';
  String? _selectedRollNo;
  final TextEditingController _presentDaysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExcelData();
  }

  void _loadExcelData() {
    try {
      var excel = Excel.decodeBytes(widget.excelBytes);
      var table = excel.tables[excel.tables.keys.first];

      if (table == null || table.rows.isEmpty) {
        setState(() {
          _error = "Excel file is empty.";
          _isLoading = false;
        });
        return;
      }

      int headerRowIndex = 0;
      for (int r = 0; r < table.rows.length && r < 10; r++) {
        var row = table.rows[r];
        bool hasReg = row.any((c) {
          String v = c?.value?.toString().toLowerCase() ?? '';
          return v.contains('reg') || v.contains('roll');
        });
        bool hasName = row.any((c) => c?.value?.toString().toLowerCase().contains('name') ?? false);
        if (hasReg || hasName) {
          headerRowIndex = r;
          break;
        }
      }

      List<Data?> headerRow = table.rows[headerRowIndex];
      int rollNoIdx = -1, nameIdx = -1, addressIdx = -1, attendanceIdx = -1, dateIdx = -1, advisorIdx = -1;

      for (int i = 0; i < headerRow.length; i++) {
        String header = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
        if (header.contains('roll') || header.contains('reg')) rollNoIdx = i;
        else if (header.contains('name') && !header.contains('advisor') && !header.contains('father')) nameIdx = i;
        else if (header.contains('address') || header.contains('add') || header.contains('father')) addressIdx = i;
        else if (header.contains('attendance') || header.contains('%') || header.contains('att') || header.contains('percent')) attendanceIdx = i;
        else if (header.contains('date')) dateIdx = i;
        else if (header.contains('advisor')) advisorIdx = i;
      }

      // If headers weren't found, fallback based on typical student lists (S.No, RegNo, Name, Father Name/Address)
      if (rollNoIdx == -1 && headerRow.length > 1) rollNoIdx = 1;
      if (nameIdx == -1 && headerRow.length > 2) nameIdx = 2;
      if (addressIdx == -1 && headerRow.length > 3) addressIdx = 3;
      
      if (attendanceIdx == -1) {
        List<List<Data?>> tempRows = table.rows.skip(headerRowIndex + 1).toList();
        if (tempRows.isNotEmpty) {
          for (int i = 2; i < headerRow.length; i++) {
            String val = tempRows.first.length > i ? (tempRows.first[i]?.value?.toString().trim() ?? '') : '';
            if (double.tryParse(val) != null) {
              attendanceIdx = i;
              break;
            }
          }
        }
      }

      List<List<Data?>> dataRows = table.rows.skip(headerRowIndex + 1).toList();
      List<StudentData> parsed = [];

      for (var row in dataRows) {
        if (row.every((cell) => cell == null || cell.value == null || cell.value.toString().trim().isEmpty)) {
          continue;
        }

        String rollNo = rollNoIdx != -1 && row.length > rollNoIdx ? (row[rollNoIdx]?.value?.toString() ?? '') : '';
        String name = nameIdx != -1 && row.length > nameIdx ? (row[nameIdx]?.value?.toString() ?? '') : '';
        String address = addressIdx != -1 && row.length > addressIdx ? (row[addressIdx]?.value?.toString() ?? '') : '';
        
        if (address.isNotEmpty) {
          List<String> lines = address.split('\n');
          if (lines.isNotEmpty) {
            String firstLine = lines.first.trim().toLowerCase();
            if (firstLine.startsWith('mr.') || firstLine.startsWith('mr ') || 
                firstLine.startsWith('miss') || firstLine.startsWith('ms.') || 
                firstLine.startsWith('ms ') || firstLine.startsWith('mrs')) {
              lines.removeAt(0);
              address = lines.join('\n').trim();
            }
          }
        }

        String att = attendanceIdx != -1 && row.length > attendanceIdx ? (row[attendanceIdx]?.value?.toString() ?? '') : '';
        String date = dateIdx != -1 && row.length > dateIdx ? (row[dateIdx]?.value?.toString() ?? '') : '';
        if (date.isEmpty) {
          final now = DateTime.now();
          date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
        }
        String advisor = advisorIdx != -1 && row.length > advisorIdx ? (row[advisorIdx]?.value?.toString() ?? '') : '';

        att = att.replaceAll('%', '').trim();
        String calculatedAtt = att;
        if (widget.totalSelectedDays > 0 && att.isNotEmpty) {
          double? daysAttended = double.tryParse(att);
          if (daysAttended != null) {
            double percentage = (daysAttended / widget.totalSelectedDays) * 100;
            calculatedAtt = percentage.round().toString();
          }
        }

        parsed.add(StudentData(
          rollNo: rollNo.isNotEmpty ? rollNo : 'Unknown',
          name: name,
          address: address,
          attendance: calculatedAtt,
          date: date,
          advisor: advisor.isNotEmpty ? advisor : widget.advisor,
          fromDate: widget.fromDate,
          toDate: widget.toDate,
        ));
      }

      setState(() {
        _students = parsed;
        if (_students.isNotEmpty) {
          _selectedRollNo = _students.first.rollNo;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _updateAttendance() {
    if (_selectedRollNo == null) return;
    final idx = _students.indexWhere((s) => s.rollNo == _selectedRollNo);
    if (idx == -1) return;
    
    double? days = double.tryParse(_presentDaysController.text);
    if (days != null && widget.totalSelectedDays > 0) {
      double percentage = (days / widget.totalSelectedDays) * 100;
      setState(() {
        _students[idx].attendance = percentage.round().toString();
      });
    }
  }

  Future<void> _generatePdf() async {
    if (_selectedRollNo == null) return;
    final student = _students.firstWhere((s) => s.rollNo == _selectedRollNo);
    
    setState(() {
      _isLoading = true;
    });
    try {
      final bytes = await _pdfService.generatePdfFromData([student]);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Attendance_Letter_${student.rollNo}.pdf',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Generate Letter'), backgroundColor: const Color(0xFF296FD8), foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Generate Letter'), backgroundColor: const Color(0xFF296FD8), foregroundColor: Colors.white),
        body: Center(child: Text(_error, style: const TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Generate Letter - Year ${widget.year}'),
        backgroundColor: const Color(0xFF296FD8),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Roll No',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedRollNo,
                    items: _students.map((s) => DropdownMenuItem(value: s.rollNo, child: Text(s.rollNo))).toList(),
                    onChanged: (val) {
                      setState(() {
                         _selectedRollNo = val;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _presentDaysController,
                    decoration: const InputDecoration(
                      labelText: 'Number of Present Days',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                       _updateAttendance();
                    }
                  ),
                )
              ]
            )
          ),
          const Divider(),
          Expanded(
            child: _selectedRollNo == null 
              ? const Center(child: Text('Please select a Roll No')) 
              : EditableLetterView(
                  student: _students.firstWhere((s) => s.rollNo == _selectedRollNo),
                  onChanged: (updatedStudent) {
                    final idx = _students.indexWhere((s) => s.rollNo == _selectedRollNo);
                    if (idx != -1) {
                      _students[idx] = updatedStudent;
                    }
                  }
                )
          )
        ]
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generatePdf,
        label: const Text('Print / PDF'),
        icon: const Icon(Icons.print),
        backgroundColor: const Color(0xFF296FD8),
      ),
    );
  }
}

class EditableLetterView extends StatefulWidget {
  final StudentData student;
  final ValueChanged<StudentData> onChanged;

  const EditableLetterView({super.key, required this.student, required this.onChanged});

  @override
  State<EditableLetterView> createState() => _EditableLetterViewState();
}

class _EditableLetterViewState extends State<EditableLetterView> {
  late TextEditingController _dateController;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _attController;
  late TextEditingController _advisorController;
  late TextEditingController _fromDateController;
  late TextEditingController _toDateController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    String d = widget.student.date;
    if (d.isEmpty) {
      final now = DateTime.now();
      d = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    }
    _dateController = TextEditingController(text: d);
    _nameController = TextEditingController(text: widget.student.name);
    _addressController = TextEditingController(text: widget.student.address);
    _attController = TextEditingController(text: widget.student.attendance);
    _advisorController = TextEditingController(text: widget.student.advisor.replaceAll(' & ', '\n'));
    _fromDateController = TextEditingController(text: widget.student.fromDate);
    _toDateController = TextEditingController(text: widget.student.toDate);

    _dateController.addListener(_notifyChange);
    _nameController.addListener(_notifyChange);
    _addressController.addListener(_notifyChange);
    _attController.addListener(_notifyChange);
    _advisorController.addListener(_notifyChange);
    _fromDateController.addListener(_notifyChange);
    _toDateController.addListener(_notifyChange);
  }

  @override
  void didUpdateWidget(EditableLetterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student != widget.student) {
      _dateController.text = widget.student.date;
      _nameController.text = widget.student.name;
      _addressController.text = widget.student.address;
      _attController.text = widget.student.attendance;
      _advisorController.text = widget.student.advisor;
      _fromDateController.text = widget.student.fromDate;
      _toDateController.text = widget.student.toDate;
    }
  }

  void _notifyChange() {
    widget.onChanged(StudentData(
      rollNo: widget.student.rollNo,
      name: _nameController.text,
      address: _addressController.text,
      attendance: _attController.text,
      date: _dateController.text,
      advisor: _advisorController.text,
      fromDate: _fromDateController.text,
      toDate: _toDateController.text,
    ));
  }

  @override
  void dispose() {
    _dateController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _attController.dispose();
    _advisorController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16.0),
      child: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          width: 595, // Standard A4 width
          // height: 842, // Removed to allow dynamic height
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('டாக்டர் சிவந்தி ஆதித்தனார் பொறியியல் கல்லூரி', style: GoogleFonts.notoSansTamil(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                Text('திருச்செந்தூர் - 628 215', style: GoogleFonts.notoSansTamil(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 8),
                const Text('OFFICE : 04639 - 242482', style: TextStyle(fontSize: 12, color: Colors.black)),
                const Text('FAX : 243188', style: TextStyle(fontSize: 12, color: Colors.black)),
                const Divider(thickness: 1.5, color: Colors.black),
                const SizedBox(height: 10),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dr. G. Wiselin Jiji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                        Text('PRINCIPAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                      ],
                    ),
                    Row(
                      children: [
                        Text('நாள்: ', style: GoogleFonts.notoSansTamil(fontWeight: FontWeight.bold, color: Colors.black)),
                        IntrinsicWidth(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 80),
                            child: TextField(
                              controller: _dateController,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Text('பெறுநர்:', style: GoogleFonts.notoSansTamil(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black)),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                      ),
                      TextField(
                        controller: _addressController,
                        maxLines: null,
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text('ஐயா,', style: GoogleFonts.notoSansTamil(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black)),
                const SizedBox(height: 10),

                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('      எங்களது கல்லூரியில் இறுதி ஆண்டு Information Technology துறையில் பயிலும் தங்களது மகன்/மகள் ', style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0, color: Colors.black)),
                    IntrinsicWidth(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 50),
                        child: TextField(
                          controller: _nameController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, height: 2.0, color: Colors.black),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                        ),
                      ),
                    ),
                    Text(' அவர்களின் கல்லூரி வருகைப்பதிவு ', style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0, color: Colors.black)),
                    IntrinsicWidth(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 30),
                        child: TextField(
                          controller: _attController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, height: 2.0, color: Colors.black),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                        ),
                      ),
                    ),
                    Text('% ஆக உள்ளது. (', style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0, color: Colors.black)),
                    IntrinsicWidth(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 40),
                        child: TextField(
                          controller: _fromDateController,
                          style: const TextStyle(fontSize: 13, height: 2.0, color: Colors.black),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                        ),
                      ),
                    ),
                    Text(' முதல் ', style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0, color: Colors.black)),
                    IntrinsicWidth(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 40),
                        child: TextField(
                          controller: _toDateController,
                          style: const TextStyle(fontSize: 13, height: 2.0, color: Colors.black),
                          decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                        ),
                      ),
                    ),
                    Text(' வரை).', style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0, color: Colors.black)),
                  ],
                ),
                const SizedBox(height: 10),

                Text(
                  '      பல்கலைக் கழகத் தேர்வு விதிமுறைகளின் படி ஒரு மாணவரின் வருகை பதிவு 75 சதவீதத்திற்கு குறைவாக இருந்தால் அவரை பல்கலைக்கழக தேர்வுகள் எழுத அனுமதிக்க இயலாது. மற்றும் இந்த பருவத்தின் கடைசி வேலை நாளுக்குள் உங்களது மகன் வருகைப்பதிவு 75% க்கு அதிகமாக இருக்க நாள் தவறாது வகுப்புக்கு குறித்த நேரத்தில் வருகை புரிய தகுந்த அறிவுரை கூறவும். எனவே இக்கடிதம் கண்டவுடன் துறை தலைவரை உடனே சந்திக்கவும்.',
                  style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0, color: Colors.black),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 10),

                Center(child: Text('நன்றி.', style: GoogleFonts.notoSansTamil(fontSize: 13, color: Colors.black))),
                const SizedBox(height: 10),

                Align(alignment: Alignment.centerRight, child: Text('இப்படிக்கு,', style: GoogleFonts.notoSansTamil(fontSize: 13, color: Colors.black))),
                const SizedBox(height: 30),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Dr. S. Selvi, Prof & HOD/IT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black), textAlign: TextAlign.center),
                          Text('துறைத்தலைவர்', style: GoogleFonts.notoSansTamil(fontSize: 11, color: Colors.black), textAlign: TextAlign.center),
                        ]
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TextField(
                            controller: _advisorController,
                            maxLines: null,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                          ),
                          Text('ஆலோசகர்', style: GoogleFonts.notoSansTamil(fontSize: 11, color: Colors.black), textAlign: TextAlign.center),
                        ]
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Dr. G. Wiselin Jiji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black), textAlign: TextAlign.center),
                          Text('முதல்வர்', style: GoogleFonts.notoSansTamil(fontSize: 11, color: Colors.black), textAlign: TextAlign.center),
                        ]
                      ),
                    ),
                  ]
                ),
                
                const SizedBox(height: 10),
                const Divider(thickness: 1.5, color: Colors.black),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('From:', style: TextStyle(fontSize: 11, color: Colors.black)),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('The Principal', style: TextStyle(fontSize: 11, color: Colors.black)),
                                Text('Dr. Sivanthi Aditanar College of Engineering', style: TextStyle(fontSize: 11, color: Colors.black)),
                                Text('Tiruchendur 628215', style: TextStyle(fontSize: 11, color: Colors.black)),
                                Text('Tuticorin.', style: TextStyle(fontSize: 11, color: Colors.black)),
                              ]
                            )
                          )
                        ]
                      )
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('To', style: TextStyle(fontSize: 11, color: Colors.black)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(fontSize: 11, height: 1.5, color: Colors.black),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                          ),
                          TextField(
                            controller: _addressController,
                            maxLines: null,
                            style: const TextStyle(fontSize: 11, height: 1.5, color: Colors.black),
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                          ),
                        ]
                      )
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('STAMP', style: TextStyle(fontSize: 11, color: Colors.black)),
                          const SizedBox(height: 5),
                          Container(
                            width: 40,
                            height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 1)
                            )
                          )
                        ]
                      )
                    )
                  ]
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
