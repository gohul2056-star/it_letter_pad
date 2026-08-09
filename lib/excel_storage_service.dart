import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExcelStorageService {
  final Map<String, Uint8List> _webCache = {};

  Future<String> _getFilePath(String year) async {
    if (kIsWeb) return '';
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/it_letter_pad_year_$year.xlsx';
  }

  Future<void> saveExcelFile(String year, Uint8List bytes) async {
    if (kIsWeb) {
      _webCache[year] = bytes;
      return;
    }
    try {
      final path = await _getFilePath(year);
      final file = File(path);
      await file.writeAsBytes(bytes);
    } catch (e) {
      print('Error saving excel file: $e');
    }
  }

  Future<Uint8List?> loadExcelFile(String year) async {
    if (kIsWeb) {
      return _webCache[year];
    }
    try {
      final path = await _getFilePath(year);
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      print('Error loading excel file: $e');
    }
    return null;
  }
}
