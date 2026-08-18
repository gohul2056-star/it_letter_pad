import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:intl/intl.dart';
import 'attendance_screen.dart';
import 'pdf_generator_service.dart';
import 'excel_storage_service.dart';

class StudentDetailsScreen extends StatefulWidget {
  const StudentDetailsScreen({super.key});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  String? _selectedYear;
  Uint8List? _excelBytes;
  final PdfGeneratorService _pdfService = PdfGeneratorService();
  final ExcelStorageService _storageService = ExcelStorageService();
  List<DateTime?> _selectedDates = [];
  final TextEditingController _advisorController = TextEditingController(text: '');

  final List<String> _staffOptions = [
    'Mr. J.Amos Viyanikaran, AP/IT',
    'Dr. R. Chithra Devi, ASP/IT',
    'Mrs. K.P. Ramya, AP/IT',
    'Ms. K. Ramya Thamizharasi, AP/IT',
    'Mrs. N. Rajeswari, AP/IT',
    'Mrs. M. Petchithai, AP/IT',
    'Mrs. A. Shilba, AP/IT',
  ];
  List<String> _selectedStaff = [];

  @override
  void initState() {
    super.initState();
    _loadInitialBatchAndExcel();
  }

  Future<void> _loadInitialBatchAndExcel() async {
    final history = await _storageService.getHistory();
    history.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    final leaveFiles = history.where((f) => f.fileType == 'Leave Intimation');
    if (leaveFiles.isNotEmpty) {
      final latest = leaveFiles.first;
      if (latest.originalFileName.startsWith('Leave_Intimation_Year_')) {
        final batch = latest.originalFileName.split('_').last;
        final bytes = await _storageService.loadExcelFile(latest.id);
        if (bytes != null && mounted) {
          setState(() {
            _selectedYear = batch;
            _excelBytes = bytes;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _advisorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
        backgroundColor: const Color(0xFF296FD8),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Year',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: PopupMenuButton<String>(
                initialValue: _selectedYear,
                offset: const Offset(0, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Theme.of(context).colorScheme.surface,
                elevation: 4,
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 40,
                  maxWidth: MediaQuery.of(context).size.width - 40,
                ),
                onSelected: (value) async {
                  setState(() {
                    _selectedYear = value;
                    _excelBytes = null; 
                  });
                  final history = await _storageService.getHistory();
                  final matchingFiles = history.where((f) => f.originalFileName == 'Leave_Intimation_Year_$value' && f.fileType == 'Leave Intimation');
                  
                  Uint8List? bytes;
                  if (matchingFiles.isNotEmpty) {
                    bytes = await _storageService.loadExcelFile(matchingFiles.first.id);
                  }
                  
                  if (bytes != null) {
                    setState(() {
                      _excelBytes = bytes;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Loaded existing Excel file for Year $value!')),
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: '2025', child: Text('2025 - 2029')),
                  const PopupMenuItem(value: '2024', child: Text('2024 - 2028')),
                  const PopupMenuItem(value: '2023', child: Text('2023 - 2027')),
                ],
                child: Container(
                  height: 56,
                  width: MediaQuery.of(context).size.width - 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedYear != null ? '$_selectedYear Batch' : 'Choose a Batch',
                        style: TextStyle(
                          color: _selectedYear != null ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey[700], 
                          fontSize: 16
                        )
                      ),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF296FD8)),
                    ],
                  ),
                ),
              ),
            ),
            if (_selectedYear != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: Text(_excelBytes != null ? 'Update Excel File' : 'Upload Excel File'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : const Color(0xFFF1F5F9),
                        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1E293B),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        Uint8List? bytes = await _pdfService.pickExcelFile();
                        if (bytes != null) {
                          await _storageService.saveExcelFile('Leave_Intimation_Year_$_selectedYear', 'Leave Intimation', bytes);
                          setState(() {
                            _excelBytes = bytes;
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Excel file saved for Year $_selectedYear!')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_excelBytes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text('Excel data is ready', style: TextStyle(color: Colors.green, fontSize: 12)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 20),
            Text('Select Dates', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CalendarDatePicker2(
                config: CalendarDatePicker2Config(
                  calendarType: CalendarDatePicker2Type.multi,
                  selectedDayHighlightColor: const Color(0xFF296FD8),
                ),
                value: _selectedDates,
                onValueChanged: (dates) => setState(() => _selectedDates = dates),
              ),
            ),
            const SizedBox(height: 8),
            Text('Selected ${_selectedDates.where((d) => d != null).length} days', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Text('Staff Name (Advisor)', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final selected = await showDialog<List<String>>(
                  context: context,
                  builder: (context) {
                    List<String> tempSelected = List.from(_selectedStaff);
                    return StatefulBuilder(
                      builder: (context, setState) {
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
                                    setState(() {
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
                    _selectedStaff = selected;
                    _advisorController.text = _selectedStaff.join(' & ');
                  });
                }
              },
              child: Container(
                width: MediaQuery.of(context).size.width - 40,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedStaff.isEmpty ? 'Select Advisors' : _selectedStaff.join(' & '),
                  style: TextStyle(fontSize: 16, color: _selectedStaff.isEmpty ? Colors.grey[600] : Theme.of(context).textTheme.bodyLarge?.color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildActionCard(context, 'Attendance', Icons.calendar_month),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (title == 'Attendance') {
              if (_selectedYear == null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Action Required'),
                    content: const Text('Please select a year first.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              } else if (_excelBytes == null) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Action Required'),
                    content: const Text('Please upload an Excel file for the selected year.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              } else {
                final validDates = _selectedDates.where((d) => d != null).map((d) => d!).toList();
                if (validDates.isEmpty) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Action Required'),
                      content: const Text('Please select at least one date from the calendar.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                validDates.sort();
                final fromDate = DateFormat('dd.MM.yyyy').format(validDates.first);
                final toDate = DateFormat('dd.MM.yyyy').format(validDates.last);
                final totalSelectedDays = validDates.length;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceScreen(
                      year: _selectedYear!, 
                      excelBytes: _excelBytes!,
                      fromDate: fromDate,
                      toDate: toDate,
                      totalSelectedDays: totalSelectedDays,
                      advisor: _advisorController.text,
                    ),
                  ),
                );
              }
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF296FD8)),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
