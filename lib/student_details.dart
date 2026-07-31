import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  final TextEditingController _fromDateController = TextEditingController(text: '01.01.${DateTime.now().year}');
  final TextEditingController _toDateController = TextEditingController(text: '01.12.${DateTime.now().year}');
  final TextEditingController _advisorController = TextEditingController(text: '***********');

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('From Date', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _fromDateController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF296FD8))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('To Date', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _toDateController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF296FD8))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Staff Name (Advisor)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            DropdownMenu<String>(
              controller: _advisorController,
              initialSelection: 'Enter or Select Name',
              width: MediaQuery.of(context).size.width - 40,
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF1F5F9))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF296FD8))),
              ),
              dropdownMenuEntries: const [
                DropdownMenuEntry(value: 'Dr. R. Chithra Devi', label: 'Dr. R. Chithra Devi, ASP/IT'),
                DropdownMenuEntry(value: 'Mrs. K.P. Ramya', label: 'Mrs. K.P. Ramya, AP/IT'),
                DropdownMenuEntry(value: 'Ms. K. Ramya Thamizharasi ', label: 'Ms. K. Ramya Thamizharasi, AP/IT'),
                DropdownMenuEntry(value: 'Mrs. N. Rajeswari ', label: 'Mrs. N. Rajeswari, AP/IT'),
                DropdownMenuEntry(value: 'Mr. J.Amos Viyanikaran ', label: 'Mr.J.Amos Viyanikaran, AP/IT'),
                DropdownMenuEntry(value: 'Mrs. M. Petchithai ', label: 'Mrs. M. Petchithai, AP/IT'),
                DropdownMenuEntry(value: 'Mrs. A. Shilba ', label: 'Mrs. A. Shilba, AP/IT'),
              ],
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceScreen(
                      year: _selectedYear!, 
                      excelBytes: _excelBytes!,
                      fromDate: _fromDateController.text,
                      toDate: _toDateController.text,
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

