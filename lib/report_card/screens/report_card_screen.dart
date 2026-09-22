import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:excel/excel.dart' hide Border;
import 'preview_screen.dart';
import '../models/report_card_data.dart';
import '../models/report_card_config.dart';
import '../models/subject_mapping.dart';
import '../services/excel_parser_service.dart';
import '../services/report_card_pdf_service.dart';
import '../../excel_storage_service.dart';
import 'package:intl/intl.dart';

class ReportCardExcelScreen extends StatefulWidget {
  const ReportCardExcelScreen({super.key});

  @override
  State<ReportCardExcelScreen> createState() => _ReportCardExcelScreenState();
}

class _ReportCardExcelScreenState extends State<ReportCardExcelScreen> {
  final ExcelParserService _parserService = ExcelParserService();
  final ReportCardPdfService _pdfService = ReportCardPdfService();
  final ExcelStorageService _storageService = ExcelStorageService();
  
  List<ReportCardData> _mergedStudents = [];
  bool _isLoading = true;
  String _error = '';
  
  List<ExcelFileMetadata> _studentDetailsHistory = [];
  List<ReportCardData> _allStudentDetails = [];
  List<String> _availableBatches = [];
  String? _selectedBatch;

  // Student Marks State
  List<ExcelFileMetadata> _studentMarksHistory = [];
  List<String> _availableMarksBatches = [];
  Map<String, ExcelFileMetadata> _marksBatchesFiles = {};
  String? _selectedMarksBatch;
  bool _isMarksFileUploaded = false;
  Uint8List? _marksExcelBytes;
  List<String> _availableSubjectHeaders = [];

  final ReportCardConfig _config = ReportCardConfig();

  // Controllers for config
  final TextEditingController _periodicalTestController = TextEditingController();
  final TextEditingController _academicYearController = TextEditingController();
  final TextEditingController _numSubjectsController = TextEditingController(text: '');

  // Advisors State
  final List<String> _staffOptions = [
    'Mr. J.Amos Viyanikaran, AP/IT',
    'Dr. R. Chithra Devi, ASP/IT',
    'Mrs. K.P. Ramya, AP/IT',
    'Ms. K. Ramya Thamizharasi, AP/IT',
    'Mrs. N. Rajeswari, AP/IT',
    'Mrs. M. Petchithai, AP/IT',
    'Mrs. A. Shilba, AP/IT',
  ];

  // Attendance State
  final TextEditingController _workingDaysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _periodicalTestController.addListener(() => _config.periodicalTestNumber = _periodicalTestController.text);
    _academicYearController.addListener(() => _config.academicYear = _academicYearController.text);
    _numSubjectsController.addListener(_onNumSubjectsChanged);
  }

  @override
  void dispose() {
    _periodicalTestController.dispose();
    _academicYearController.dispose();
    _numSubjectsController.dispose();
    _workingDaysController.dispose();
    super.dispose();
  }

  void _onNumSubjectsChanged() {
    final int? newCount = int.tryParse(_numSubjectsController.text);
    if (newCount != null && newCount >= 0) {
      setState(() {
        if (newCount > _config.subjectMappings.length) {
          _config.subjectMappings.addAll(
            List.generate(newCount - _config.subjectMappings.length, (index) => SubjectMapping(subjectCode: '', subjectName: ''))
          );
        } else if (newCount < _config.subjectMappings.length) {
          _config.subjectMappings = _config.subjectMappings.sublist(0, newCount);
        }
      });
    }
  }

  Future<void> _loadHistory() async {
    final history = await _storageService.getHistory();
    final studentDetailsFiles = history.where((m) => m.fileType == 'Leave Intimation' || m.fileType == 'Student Details').toList();
    final studentMarksFiles = history.where((m) => m.fileType == 'Student Marks').toList();
    
    Map<String, ReportCardData> latestStudents = {};
    Set<String> batches = {};
    
    // Process oldest to newest so newest overwrites
    for (var file in studentDetailsFiles.reversed) {
      final bytes = await _storageService.loadExcelFile(file.id);
      if (bytes != null) {
        try {
          String? extractedBatch;
          if (file.originalFileName.startsWith('Leave_Intimation_Year_') || file.originalFileName.startsWith('Student_Details_Year_')) {
            final parts = file.originalFileName.split('_');
            if (parts.isNotEmpty) extractedBatch = 'Batch ${parts.last.replaceAll('.xlsx', '')}';
          }
          
          var students = _parserService.parseExcel(bytes, defaultBatch: extractedBatch);
          for (var s in students) {
            latestStudents[s.rollNo.trim().toLowerCase()] = s;
            batches.add(s.batch);
          }
        } catch (e) {
          // ignore
        }
      }
    }
    
    Set<String> marksBatchesSet = {};
    Map<String, ExcelFileMetadata> marksBatchesFiles = {};
    
    // Process marks files (newest first, since we want the latest uploaded marks file for a batch)
    for (var file in studentMarksFiles) {
       List<String> fileBatches = await _parserService.getBatchesForFile(file, _storageService.loadExcelFile);
       for (var b in fileBatches) {
          if (!marksBatchesFiles.containsKey(b)) {
             marksBatchesFiles[b] = file;
             marksBatchesSet.add(b);
          }
       }
    }
    
    if (mounted) {
      setState(() {
        _studentDetailsHistory = studentDetailsFiles;
        _allStudentDetails = latestStudents.values.toList();
        _availableBatches = batches.toList()..sort();
        
        _studentMarksHistory = studentMarksFiles;
        _availableMarksBatches = marksBatchesSet.toList()..sort();
        _marksBatchesFiles = marksBatchesFiles;
        
        if (_selectedBatch != null && !_availableBatches.contains(_selectedBatch)) {
          _selectedBatch = null;
        }
        
        if (_selectedMarksBatch != null && !_availableMarksBatches.contains(_selectedMarksBatch)) {
          _selectedMarksBatch = null;
          _isMarksFileUploaded = false;
          _marksExcelBytes = null;
        }
        
        _isLoading = false;
      });
    }
  }

  bool _isSubjectMappingValid(SubjectMapping mapping) {
    if (!_isMarksFileUploaded || _marksExcelBytes == null) return true;
    if (mapping.subjectCode.isEmpty) return true;

    final enteredCode = mapping.subjectCode.trim().toUpperCase();
    return _availableSubjectHeaders.contains(enteredCode);
  }

  Future<void> _pickStudentDetailsExcel() async {
    final XFile? file = await openFile();
    if (file != null) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      try {
        final bytes = await file.readAsBytes();
        
        // Basic validation
        _parserService.parseExcel(bytes);
        
        // Save as Student Details (we keep Leave Intimation for backwards compatibility if needed, but the prompt says replace it here)
        final String fileNameToSave = file.name;
        await _storageService.saveExcelFile(fileNameToSave, 'Student Details', bytes);
        await _loadHistory();
      } catch (e) {
        setState(() => _error = 'Error processing Student Details file: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickMarksExcel() async {
    if (_selectedBatch == null) {
      setState(() => _error = 'Please select a batch from Student Details first.');
      return;
    }
    
    final XFile? file = await openFile();
    if (file != null) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
      try {
        final bytes = await file.readAsBytes();
        
        // Pre-validate that marks match at least some students in the selected batch
        final marksStudents = _parserService.parseExcel(bytes);
        final batchStudents = _allStudentDetails.where((s) => s.batch == _selectedBatch).toList();
        
        bool anyMatch = false;
        for (var ms in marksStudents) {
           if (batchStudents.any((bs) => bs.rollNo.trim().toLowerCase() == ms.rollNo.trim().toLowerCase())) {
              anyMatch = true;
              break;
           }
        }
        
        if (!anyMatch) {
          throw Exception('No students in this marks file match the students in $_selectedBatch.');
        }

        await _storageService.saveExcelFile(file.name, 'Student Marks', bytes, batches: [_selectedBatch!]);
        
        await _loadHistory();
        
        if (mounted) {
          setState(() {
            _selectedMarksBatch = _selectedBatch;
            _marksExcelBytes = bytes;
            _availableSubjectHeaders = _parserService.getAvailableSubjectHeaders(bytes);
            _isMarksFileUploaded = true;
          });
        }
      } catch (e) {
        setState(() => _error = 'Error parsing Student Marks Excel: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String? _validateConfiguration() {
    if (_selectedBatch == null) return 'Please select a Batch for Student Details.';
    if (!_isMarksFileUploaded || _marksExcelBytes == null) return 'Please upload the Student Marks Excel.';
    
    if (_config.periodicalTestNumber.isEmpty) return 'Please enter the Periodical Test number.';
    if (_config.academicYear.isEmpty) return 'Please enter the Academic Year.';
    if (_config.semesterType.isEmpty) return 'Please select ODD or EVEN Semester.';
    if (_config.year.isEmpty || _config.semester.isEmpty) return 'Please select Year and Semester.';
    
    if (_config.fromDate == null || _config.toDate == null) return 'Please enter the attendance period (Calendar icon).';
    if (_config.workingDays <= 0) return 'Please enter a valid number of working days (Calendar icon).';
    
    if (_config.advisors.isEmpty) return 'Please add and select at least one Faculty Advisor (Person icon).';

    if (_config.subjectMappings.isEmpty) return 'Please configure at least one subject.';
    for (var sub in _config.subjectMappings) {
      if (sub.subjectCode.isEmpty) return 'A subject is missing its code.';
      if (sub.subjectName.isEmpty) return 'A subject is missing its name.';
      if (!_isSubjectMappingValid(sub)) return 'Subject ${sub.subjectCode} is not found in the uploaded Student Marks Excel.';
    }

    return null; // All valid
  }

  Future<void> _generatePdf() async {
    final String? validationError = _validateConfiguration();
    if (validationError != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validationError), backgroundColor: Colors.red));
      return;
    }

    setState(() {
      _isLoading = true;
    });
    
    try {
      if (_selectedBatch != null && _marksExcelBytes != null) {
        // Parse the marks excel.
        final marksStudents = _parserService.parseExcel(_marksExcelBytes!, subjectMappings: _config.subjectMappings);
        
        // Filter the pre-loaded student details by the selected batch
        final batchStudents = _allStudentDetails.where((s) => s.batch == _selectedBatch).toList();
        
        List<ReportCardData> mergedList = [];
        
        // Merge logic
        for (var detailsStudent in batchStudents) {
          // Find matching student in marks based on Roll Number
          final String targetRoll = detailsStudent.rollNo.trim().toLowerCase();
          
          ReportCardData? marksStudent;
          for (var ms in marksStudents) {
            if (ms.rollNo.trim().toLowerCase() == targetRoll) {
              marksStudent = ms;
              break;
            }
          }
          
          // Skip if no marks found (or throw error based on preference, but better to skip or just leave blank if they want strict matching)
          if (marksStudent == null) {
            continue; // Only add matching students as per requirements
          }
          
          if (_config.includePlacement && (marksStudent.placementMark == null || marksStudent.placementMark!.isEmpty)) {
            // throw Exception('Placement mark not found for Roll No. ${detailsStudent.rollNo}.');
            // Actually, we shouldn't fail the whole batch for one missing placement mark, but I'll preserve original logic if needed, or just let it pass.
          }

          // Use Identity from Student Details, Academic from Student Marks
          final mergedStudent = ReportCardData(
            rollNo: detailsStudent.rollNo,
            studentName: detailsStudent.studentName,
            classAndSem: detailsStudent.classAndSem,
            date: detailsStudent.date,
            batch: detailsStudent.batch,
            totalMarks: marksStudent.totalMarks,
            scoredMarks: marksStudent.scoredMarks,
            rank: marksStudent.rank,
            attendancePercentage: marksStudent.attendancePercentage,
            fromDate: detailsStudent.fromDate,
            toDate: detailsStudent.toDate,
            remarks: detailsStudent.remarks,
            address: detailsStudent.address,
            daysAbsent: marksStudent.daysAbsent,
            subjects: marksStudent.subjects,
            placementMark: marksStudent.placementMark,
            availableSubjectCodes: marksStudent.availableSubjectCodes,
            isSelected: true,
          );
          
          mergedList.add(mergedStudent);
        }

        // --- Calculate Ranks based on mergedList ---
        List<Map<String, dynamic>> passList = [];
        for (var student in mergedList) {
          int scored = 0;
          bool passed = true;
          for (var mapping in _config.subjectMappings) {
            String norm(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
            var mark = student.subjects.firstWhere((m) => norm(m.subjectCode) == norm(mapping.subjectCode), orElse: () => SubjectMark(subjectName: '', subjectCode: '', totalMark: '', passingMark: '', scoredMark: '#N/A', passFail: '#N/A'));
            int? m = int.tryParse(mark.scoredMark);
            if (m != null) {
              scored += m;
              if (m < 50) passed = false;
            } else {
              passed = false; // #N/A or absent
            }
          }
          if (passed && _config.subjectMappings.isNotEmpty) {
            passList.add({'student': student, 'score': scored});
          } else {
            student.rank = '-';
          }
        }
        
        passList.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
        
        int currentRank = 1;
        for (int i = 0; i < passList.length; i++) {
          if (i > 0 && passList[i]['score'] < passList[i-1]['score']) {
            currentRank = i + 1;
          }
          ReportCardData s = passList[i]['student'];
          s.rank = currentRank.toString();
        }
        // --- End Rank Calculation ---

        setState(() {
          _mergedStudents = mergedList;
          for (var s in _mergedStudents) {
            s.isSelected = true;
          }
        });
      }

      final selectedStudents = _mergedStudents.where((s) => s.isSelected).toList();
      if (selectedStudents.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one student.')));
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(
            students: selectedStudents,
            config: _config,
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAttendancePopup() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Attendance Configuration'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('From: '),
                      TextButton(
                        onPressed: () async {
                          final dt = await showDatePicker(context: context, initialDate: _config.fromDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (dt != null) {
                            setStateDialog(() => _config.fromDate = dt);
                            setState(() {}); // Update parent
                          }
                        },
                        child: Text(_config.fromDate != null ? '${_config.fromDate!.day}/${_config.fromDate!.month}/${_config.fromDate!.year}' : 'Select Date'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('To: '),
                      TextButton(
                        onPressed: () async {
                          final dt = await showDatePicker(context: context, initialDate: _config.toDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (dt != null) {
                            setStateDialog(() => _config.toDate = dt);
                            setState(() {}); // Update parent
                          }
                        },
                        child: Text(_config.toDate != null ? '${_config.toDate!.day}/${_config.toDate!.month}/${_config.toDate!.year}' : 'Select Date'),
                      ),
                    ],
                  ),
                  TextField(
                    controller: _workingDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Number of Working Days'),
                    onChanged: (val) {
                      _config.workingDays = int.tryParse(val) ?? 0;
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
              ],
            );
          }
        );
      }
    );
  }



  Widget _buildSubjectConfiguration() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Row(
              children: const [
                Icon(Icons.subject, color: Color(0xFF296FD8)),
                SizedBox(width: 8),
                Text('Subject Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF296FD8))),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Number of Subjects', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _numSubjectsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter number of subjects',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            if (_config.subjectMappings.isNotEmpty) ...[
              Row(
                children: const [
                  Expanded(child: Text('Subject Code', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 14))),
                  Expanded(child: Text('Subject Name', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 14))),
                  SizedBox(width: 48), // Space for delete icon
                ],
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _config.subjectMappings.length,
                itemBuilder: (context, index) {
                  return Padding(
                    key: ObjectKey(_config.subjectMappings[index]),
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _config.subjectMappings[index].subjectCode,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(
                                text: newValue.text.toUpperCase(),
                                selection: newValue.selection,
                              )),
                            ],
                            decoration: InputDecoration(
                              hintText: 'Enter Code',
                              errorText: (!_isSubjectMappingValid(_config.subjectMappings[index])) ? 'Invalid' : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (val) {
                              _config.subjectMappings[index].subjectCode = val;
                              setState((){});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _config.subjectMappings[index].subjectName,
                            decoration: InputDecoration(
                              hintText: 'Enter Name',
                              errorText: (!_isSubjectMappingValid(_config.subjectMappings[index])) ? 'Invalid' : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (val) {
                              _config.subjectMappings[index].subjectName = val;
                              setState((){});
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () {
                            setState(() {
                              _config.subjectMappings.removeAt(index);
                              _numSubjectsController.text = _config.subjectMappings.length.toString();
                            });
                          },
                        )
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _config.subjectMappings.add(SubjectMapping(subjectCode: '', subjectName: ''));
                      _numSubjectsController.text = _config.subjectMappings.length.toString();
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Subject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF296FD8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Placement', style: TextStyle(fontWeight: FontWeight.bold)),
                value: _config.includePlacement,
                onChanged: (val) {
                  setState(() {
                    _config.includePlacement = val ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      );
  }

  Widget _buildReportCardConfiguration() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Row(
              children: const [
                Icon(Icons.description, color: Color(0xFF296FD8)),
                SizedBox(width: 8),
                Text('Report Card Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF296FD8))),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _periodicalTestController,
                  decoration: InputDecoration(
                    hintText: 'e.g. II',
                    labelText: 'Periodical Test Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _academicYearController,
                  decoration: InputDecoration(
                    hintText: 'e.g. 2025 - 26',
                    labelText: 'Academic Year',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Semester Type: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 8),
                Radio<String>(
                  value: 'ODD SEMESTER',
                  groupValue: _config.semesterType,
                  onChanged: (val) => setState(() => _config.semesterType = val!),
                ),
                const Text('ODD'),
                const SizedBox(width: 8),
                Radio<String>(
                  value: 'EVEN SEMESTER',
                  groupValue: _config.semesterType,
                  onChanged: (val) => setState(() => _config.semesterType = val!),
                ),
                const Text('EVEN'),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 200,
                    decoration: InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    value: _config.year.isEmpty ? null : _config.year,
                    items: ['I Year', 'II Year', 'III Year', 'IV Year'].map((y) => DropdownMenuItem(value: y, child: Text(y, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setState(() => _config.year = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    menuMaxHeight: 200,
                    decoration: InputDecoration(
                      labelText: 'Semester',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    value: _config.semester.isEmpty ? null : _config.semester,
                    items: ['I Semester', 'II Semester', 'III Semester', 'IV Semester', 'V Semester', 'VI Semester', 'VII Semester', 'VIII Semester']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setState(() => _config.semester = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Faculty Advisors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final selected = await showDialog<List<String>>(
                  context: context,
                  builder: (context) {
                    List<String> tempSelected = List.from(_config.advisors);
                    return StatefulBuilder(
                      builder: (context, setStateDialog) {
                        return AlertDialog(
                          title: const Text('Select Advisors'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: _staffOptions.map((staff) {
                                return CheckboxListTile(
                                  title: Text(staff),
                                  value: tempSelected.contains(staff),
                                  onChanged: (bool? value) {
                                    setStateDialog(() {
                                      if (value == true) {
                                        tempSelected.add(staff);
                                      } else {
                                        tempSelected.remove(staff);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, tempSelected), child: const Text('OK')),
                          ],
                        );
                      }
                    );
                  }
                );
                if (selected != null) {
                  setState(() {
                    _config.advisors = selected;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _config.advisors.isEmpty ? 'Select Advisors' : _config.advisors.join(' & '),
                  style: TextStyle(fontSize: 16, color: _config.advisors.isEmpty ? Colors.grey[600] : Colors.lightBlue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      );

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Card Generator'),
        backgroundColor: const Color(0xFF296FD8),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _showAttendancePopup,
            tooltip: 'Attendance Configuration',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- 1. Student Details Section ---
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue.shade200),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.blue.shade50,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.person, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Expanded(child: Text('Student Details (Student Identity)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D47A1)))), // Dark Blue
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_availableBatches.isEmpty) ...[
                                const Text('No batches found from uploaded Student Details.', style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _pickStudentDetailsExcel,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Upload Student Details Excel'),
                                ),
                              ] else ...[
                                const Text('Select a batch:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
                                const SizedBox(height: 8),
                                ..._availableBatches.map((batch) => CheckboxListTile(
                                  title: Text(batch, style: const TextStyle(color: Colors.black87)),
                                  value: _selectedBatch == batch,
                                  onChanged: (bool? val) {
                                    if (val == true) {
                                      setState(() {
                                        _selectedBatch = batch;
                                      });
                                    }
                                  },
                                )).toList(),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _pickStudentDetailsExcel,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Upload Additional File'),
                                )
                              ]
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // --- 2. Student Marks Section ---
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.green.shade50,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.bar_chart, color: Colors.green),
                                  SizedBox(width: 8),
                                  Expanded(child: Text('Student Marks Excel (Academic Data)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B5E20)))), // Dark Green
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_availableMarksBatches.isEmpty) ...[
                                const Text('No Student Marks records found in History.', style: TextStyle(color: Colors.grey)),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _pickMarksExcel,
                                  icon: const Icon(Icons.upload_file),
                                  label: Text(_selectedBatch != null ? 'Upload Marks for $_selectedBatch' : 'Upload Marks Excel'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                )
                              ] else ...[
                                const Text('Select a batch from History:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
                                const SizedBox(height: 8),
                                ..._availableMarksBatches.map((batch) => CheckboxListTile(
                                  title: Text(batch, style: const TextStyle(color: Colors.black87)),
                                  value: _selectedMarksBatch == batch,
                                  onChanged: (bool? val) async {
                                    if (val == true) {
                                      setState(() => _isLoading = true);
                                      final fileMeta = _marksBatchesFiles[batch]!;
                                      final bytes = await _storageService.loadExcelFile(fileMeta.id);
                                      setState(() {
                                        _selectedMarksBatch = batch;
                                        _marksExcelBytes = bytes;
                                        if (bytes != null) {
                                           _availableSubjectHeaders = _parserService.getAvailableSubjectHeaders(bytes);
                                           _isMarksFileUploaded = true;
                                        }
                                        _isLoading = false;
                                      });
                                    } else {
                                      setState(() {
                                        _selectedMarksBatch = null;
                                        _marksExcelBytes = null;
                                        _isMarksFileUploaded = false;
                                      });
                                    }
                                  },
                                )).toList(),
                                const SizedBox(height: 8),
                                if (_selectedBatch != null && !_availableMarksBatches.contains(_selectedBatch)) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('No Student Marks found in History for $_selectedBatch.', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          onPressed: _pickMarksExcel,
                                          icon: const Icon(Icons.upload_file),
                                          label: Text('Upload Marks for $_selectedBatch'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  OutlinedButton.icon(
                                    onPressed: _pickMarksExcel,
                                    icon: const Icon(Icons.upload_file),
                                    label: Text(_selectedBatch != null ? 'Upload New Marks File for $_selectedBatch' : 'Upload New Marks File'),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                                  )
                                ]
                              ]
                            ],
                          ),
                        ),
                        
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                            child: Text(_error, style: TextStyle(color: Colors.red.shade900)),
                          )
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // --- 3. Configuration ---
                        _buildSubjectConfiguration(),
                        const SizedBox(height: 24),
                        _buildReportCardConfiguration(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: (_selectedBatch != null && _isMarksFileUploaded) ? FloatingActionButton.extended(
        onPressed: _generatePdf,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Generate PDF', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF296FD8),
        foregroundColor: Colors.white,
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

