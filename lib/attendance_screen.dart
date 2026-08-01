import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pdf_generator_service.dart';

class StudentData {
  String name;
  String address;
  String attendance;
  String date;
  String advisor;
  String fromDate;
  String toDate;

  StudentData({
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
  final PageController _pageController = PageController();

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

      List<Data?> headerRow = table.rows.first;
      int nameIdx = -1, addressIdx = -1, attendanceIdx = -1, dateIdx = -1, advisorIdx = -1;

      for (int i = 0; i < headerRow.length; i++) {
        String header = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
        if (header.contains('name') && !header.contains('advisor')) nameIdx = i;
        if (header.contains('address') || header.contains('add')) addressIdx = i;
        if (header.contains('attendance') || header.contains('%') || header.contains('att') || header.contains('percent')) attendanceIdx = i;
        if (header.contains('date')) dateIdx = i;
        if (header.contains('advisor')) advisorIdx = i;
      }

      // Fallback if headers aren't explicitly named
      if (nameIdx == -1 && headerRow.isNotEmpty) nameIdx = 0;
      if (addressIdx == -1 && headerRow.length > 1) addressIdx = 1;
      
      if (attendanceIdx == -1) {
        // Try to find a column containing a number (skipping the first two which are usually name/address/reg no)
        List<List<Data?>> tempRows = table.rows.skip(1).toList();
        if (tempRows.isNotEmpty) {
          for (int i = 2; i < headerRow.length; i++) {
            String val = tempRows.first.length > i ? (tempRows.first[i]?.value?.toString().trim() ?? '') : '';
            if (double.tryParse(val) != null) {
              attendanceIdx = i;
              break;
            }
          }
        }
        // Absolute fallback
        if (attendanceIdx == -1 && headerRow.length > 2) attendanceIdx = 2;
      }

      List<List<Data?>> dataRows = table.rows.skip(1).toList();
      List<StudentData> parsed = [];

      for (var row in dataRows) {
        // Skip completely empty rows
        if (row.every((cell) => cell == null || cell.value == null || cell.value.toString().trim().isEmpty)) {
          continue;
        }

        String name = nameIdx != -1 && row.length > nameIdx ? (row[nameIdx]?.value?.toString() ?? '') : '';
        String address = addressIdx != -1 && row.length > addressIdx ? (row[addressIdx]?.value?.toString() ?? '') : '';
        String att = attendanceIdx != -1 && row.length > attendanceIdx ? (row[attendanceIdx]?.value?.toString() ?? '') : '';
        String date = dateIdx != -1 && row.length > dateIdx ? (row[dateIdx]?.value?.toString() ?? '') : '';
        if (date.isEmpty) {
          final now = DateTime.now();
          date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
        }
        String advisor = advisorIdx != -1 && row.length > advisorIdx ? (row[advisorIdx]?.value?.toString() ?? '') : '';

        // Strip % so we can parse it as a number of days
        att = att.replaceAll('%', '').trim();
        
        // Calculate percentage: (Days Attended / totalSelectedDays) * 100
        String calculatedAtt = att;
        if (widget.totalSelectedDays > 0 && att.isNotEmpty) {
          double? daysAttended = double.tryParse(att);
          if (daysAttended != null) {
            double percentage = (daysAttended / widget.totalSelectedDays) * 100;
            calculatedAtt = percentage.round().toString();
          }
        }

        // Add to list regardless of whether some fields are empty (since it's an editable UI)
        parsed.add(StudentData(
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
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final bytes = await _pdfService.generatePdfFromData(_students);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Attendance_Letters_${widget.year}.pdf',
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
        appBar: AppBar(title: Text('Letters - Year ${widget.year}'), backgroundColor: const Color(0xFF296FD8), foregroundColor: Colors.white),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Letters - Year ${widget.year}'), backgroundColor: const Color(0xFF296FD8), foregroundColor: Colors.white),
        body: Center(child: Text(_error, style: const TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Letters - Year ${widget.year} (${_students.length} Students)'),
        backgroundColor: const Color(0xFF296FD8),
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _students.length,
        itemBuilder: (context, index) {
          return EditableLetterView(
            student: _students[index],
            onChanged: (updatedStudent) {
              _students[index] = updatedStudent;
            },
          );
        },
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
    String d = widget.student.date;
    if (d.isEmpty) {
      final now = DateTime.now();
      d = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    }
    _dateController = TextEditingController(text: d);
    _nameController = TextEditingController(text: widget.student.name);
    _addressController = TextEditingController(text: widget.student.address);
    _attController = TextEditingController(text: widget.student.attendance);
    _advisorController = TextEditingController(text: widget.student.advisor);
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
  
  void _notifyChange() {
    widget.onChanged(StudentData(
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('டாக்டர் சிவந்தி ஆதித்தனார் பொறியியல் கல்லூரி', style: GoogleFonts.notoSansTamil(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('திருச்செந்தூர் - 628 215', style: GoogleFonts.notoSansTamil(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('OFFICE : 04639 - 242482', style: TextStyle(fontSize: 12)),
          const Text('FAX : 243188', style: TextStyle(fontSize: 12)),
          const Divider(thickness: 1.5, color: Colors.black),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dr. G. Wiselin Jiji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('PRINCIPAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  Text('நாள்: ', style: GoogleFonts.notoSansTamil(fontWeight: FontWeight.bold)),
                  IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 80),
                      child: TextField(
                        controller: _dateController,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text('பெறுநர்:', style: GoogleFonts.notoSansTamil(fontSize: 14, fontStyle: FontStyle.italic)),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                ),
                TextField(
                  controller: _addressController,
                  maxLines: null,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('ஐயா,', style: GoogleFonts.notoSansTamil(fontSize: 14, fontStyle: FontStyle.italic)),
          const SizedBox(height: 10),

          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('      எங்களது கல்லூரியில் இறுதி ஆண்டு Information Technology துறையில் பயிலும் தங்களது மகன்/மகள் ', style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0)),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 50),
                  child: TextField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 2.0),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
              ),
              Text(' அவர்களின் கல்லூரி வருகைப்பதிவு ', style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0)),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 30),
                  child: TextField(
                    controller: _attController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 2.0),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
              ),
              Text('% ஆக உள்ளது. (', style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0)),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 40),
                  child: TextField(
                    controller: _fromDateController,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 2.0),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
              ),
              Text(' முதல் ', style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0)),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 40),
                  child: TextField(
                    controller: _toDateController,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 2.0),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
              ),
              Text(' வரை).', style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0)),
            ],
          ),
          const SizedBox(height: 15),

          Text(
            '      பல்கலைக் கழகத் தேர்வு விதிமுறைகளின் படி ஒரு மாணவரின் வருகை பதிவு 75 சதவீதத்திற்கு குறைவாக இருந்தால் அவரை பல்கலைக்கழக தேர்வுகள் எழுத அனுமதிக்க இயலாது. மற்றும் இந்த பருவத்தின் கடைசி வேலை நாளுக்குள் உங்களது மகன் வருகைப்பதிவு 75% க்கு அதிகமாக இருக்க நாள் தவறாது வகுப்புக்கு குறித்த நேரத்தில் வருகை புரிய தகுந்த அறிவுரை கூறவும். எனவே இக்கடிதம் கண்டவுடன் துறை தலைவரை உடனே சந்திக்கவும்.',
            style: GoogleFonts.notoSansTamil(fontSize: 13, height: 2.0),
            textAlign: TextAlign.justify,
          ),
          const SizedBox(height: 20),

          Center(child: Text('நன்றி.', style: GoogleFonts.notoSansTamil(fontSize: 13))),
          const SizedBox(height: 20),

          Align(alignment: Alignment.centerRight, child: Text('இப்படிக்கு,', style: GoogleFonts.notoSansTamil(fontSize: 13))),
          const SizedBox(height: 60),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Dr. S. Selvi,\nProf & HOD/IT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                    Text('துறைத்தலைவர்', style: GoogleFonts.notoSansTamil(fontSize: 11), textAlign: TextAlign.center),
                  ]
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TextField(
                      controller: _advisorController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                    ),
                    Text('ஆலோசகர்', style: GoogleFonts.notoSansTamil(fontSize: 11), textAlign: TextAlign.center),
                  ]
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Dr. G. Wiselin Jiji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
                    Text('முதல்வர்', style: GoogleFonts.notoSansTamil(fontSize: 11), textAlign: TextAlign.center),
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
                    const Text('From:', style: TextStyle(fontSize: 11)),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('The Principal', style: TextStyle(fontSize: 11)),
                          Text('Dr. Sivanthi Aditanar College of Engineering', style: TextStyle(fontSize: 11)),
                          Text('Tiruchendur 628215', style: TextStyle(fontSize: 11)),
                          Text('Tuticorin.', style: TextStyle(fontSize: 11)),
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
                    const Text('To', style: TextStyle(fontSize: 11)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 11, height: 1.5),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                    ),
                    TextField(
                      controller: _addressController,
                      maxLines: null,
                      style: const TextStyle(fontSize: 11, height: 1.5),
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
                    const Text('STAMP', style: TextStyle(fontSize: 11)),
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
    );
  }
}
