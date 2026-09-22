import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'excel_storage_service.dart';
import 'report_card/services/excel_parser_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ExcelStorageService _storageService = ExcelStorageService();
  Map<String, List<ExcelFileMetadata>> _groupedHistory = {};
  bool _isLoading = true;
  String? _selectedBatch;

  final ExcelParserService _parserService = ExcelParserService();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _storageService.getHistory();
    
    Map<String, List<ExcelFileMetadata>> grouped = {};
    for (var file in history) {
      List<String> batches = await _parserService.getBatchesForFile(file, _storageService.loadExcelFile);
      for (var batch in batches) {
        if (!grouped.containsKey(batch)) {
          grouped[batch] = [];
        }
        grouped[batch]!.add(file);
      }
    }
    
    // Sort batches: try to extract year for proper sorting, otherwise alphabetical
    var sortedKeys = grouped.keys.toList()..sort((a, b) {
      return b.compareTo(a); 
    });
    
    Map<String, List<ExcelFileMetadata>> sortedGrouped = {};
    for (var key in sortedKeys) {
      // Sort files within the batch chronologically (newest first)
      var files = grouped[key]!;
      files.sort((f1, f2) => f2.dateAdded.compareTo(f1.dateAdded));
      sortedGrouped[key] = files;
    }
    
    setState(() {
      _groupedHistory = sortedGrouped;
      _isLoading = false;
    });
  }

  Future<void> _deleteFile(ExcelFileMetadata file) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete ${file.originalFileName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _storageService.deleteExcelFile(file.id);
      await _loadHistory();
      
      // If the selected batch is now empty, go back to the main list
      if (_selectedBatch != null && (_groupedHistory[_selectedBatch]?.isEmpty ?? true)) {
        setState(() {
          _selectedBatch = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedBatch != null ? _selectedBatch! : 'History', 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: const Color(0xFF296FD8),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: _selectedBatch != null 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _selectedBatch = null;
                });
              },
            )
          : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedBatch != null
              ? _buildFileList(_groupedHistory[_selectedBatch]!)
              : _buildBatchList(),
    );
  }

  Widget _buildBatchList() {
    if (_groupedHistory.isEmpty) {
      return const Center(
        child: Text(
          'No saved Excel files found.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groupedHistory.length,
      itemBuilder: (context, index) {
        final batch = _groupedHistory.keys.elementAt(index);
        final files = _groupedHistory[batch]!;
        
        final typesSet = files.map((f) => f.fileType == 'Leave Intimation' ? 'Student Details' : f.fileType).toSet();
        final typesString = typesSet.join(' • ');
        final lastUpdated = files.map((f) => f.dateAdded).reduce((a, b) => a.isAfter(b) ? a : b);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: const Icon(Icons.folder, color: Colors.amber, size: 40),
            title: Text(
              batch, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  typesString, 
                  style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)
                ),
                const SizedBox(height: 4),
                Text(
                  '${files.length} upload${files.length > 1 ? 's' : ''} • Last updated ${DateFormat('MMM dd, yyyy').format(lastUpdated)}', 
                  style: const TextStyle(fontSize: 12, color: Colors.grey)
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              setState(() {
                _selectedBatch = batch;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildFileList(List<ExcelFileMetadata> files) {
    if (files.isEmpty) {
      return const Center(child: Text('No files in this batch.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: file.fileType == 'Leave Intimation'
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.description,
                color: file.fileType == 'Leave Intimation' ? Colors.blue : Colors.green,
              ),
            ),
            title: Text(
              file.fileType == 'Leave Intimation' ? 'Student Details' : file.fileType,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  file.originalFileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Added: ${DateFormat('MMM dd, yyyy').format(file.dateAdded)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteFile(file),
            ),
          ),
        );
      },
    );
  }
}
