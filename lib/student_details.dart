import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:intl/intl.dart';
import 'attendance_screen.dart';
import 'pdf_generator_service.dart';

class StudentDetailsScreen extends StatefulWidget {
  const StudentDetailsScreen({super.key});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  String? _selectedYear;
  Uint8List? _excelBytes;
  final PdfGeneratorService _pdfService = PdfGeneratorService();
  List<DateTime?> _selectedDates = [];
  final TextEditingController _advisorController = TextEditingController(text: '');
  
  final List<String> _staffOptions = [
    'Dr. R. Chithra Devi',
    'Mrs. K.P. Ramya',
    'Ms. K. Ramya Thamizharasi',
    'Mrs. N. Rajeswari',
    'Mr. J.Amos Viyanikaran',
    'Mrs. M. Petchithai',
    'Mrs. A. Shilba',
  ];
  List<String> _selectedStaff = [];

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
            const Text(
              'Select Year',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
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
                offset: const Offset(0, 56), // Open exactly below the box
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                elevation: 4,
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 40,
                  maxWidth: MediaQuery.of(context).size.width - 40,
                ),
                onSelected: (value) async {
                  setState(() {
                    _selectedYear = value;
                  });
                  // Trigger file picker
                  Uint8List? bytes = await _pdfService.pickExcelFile();
                  if (bytes != null) {
                    setState(() {
                      _excelBytes = bytes;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Excel file selected successfully!')),
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: '2', child: Text('2 Years')),
                  const PopupMenuItem(value: '3', child: Text('3 Years')),
                  const PopupMenuItem(value: '4', child: Text('4 Years')),
                ],
                child: Container(
                  height: 56,
                  width: MediaQuery.of(context).size.width - 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedYear != null ? '$_selectedYear Years' : 'Choose a year', 
                        style: TextStyle(
                          color: _selectedYear != null ? const Color(0xFF1E293B) : Colors.grey[700], 
                          fontSize: 16
                        )
                      ),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF296FD8)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            const Text('Select Dates', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
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
            const Text('Staff Name (Advisor)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
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
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _selectedStaff.isEmpty ? 'Select Advisors' : _selectedStaff.join(' & '),
                  style: TextStyle(fontSize: 16, color: _selectedStaff.isEmpty ? Colors.grey[600] : const Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
                    content: const Text('Please select an Excel file first (re-select the year to trigger picker).'),
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

