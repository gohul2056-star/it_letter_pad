import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

class ExcelFileMetadata {
  final String id;
  final String originalFileName;
  final String fileType; // 'Leave Intimation', 'Student Details' or 'Student Marks'
  final DateTime dateAdded;
  final List<String>? batches;

  ExcelFileMetadata({
    required this.id,
    required this.originalFileName,
    required this.fileType,
    required this.dateAdded,
    this.batches,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalFileName': originalFileName,
        'fileType': fileType,
        'dateAdded': dateAdded.toIso8601String(),
        if (batches != null) 'batches': batches,
      };

  factory ExcelFileMetadata.fromJson(Map<String, dynamic> json) =>
      ExcelFileMetadata(
        id: json['id'],
        originalFileName: json['originalFileName'],
        fileType: json['fileType'],
        dateAdded: DateTime.parse(json['dateAdded']),
        batches: json['batches'] != null ? List<String>.from(json['batches']) : null,
      );
}

class ExcelStorageService {
  static const String _metadataFileName = 'excel_history_metadata.json';
  final _uuid = const Uuid();

  // For Web, keep simple cache since we don't have file system access
  final Map<String, Uint8List> _webCache = {};
  List<ExcelFileMetadata> _webMetadataCache = [];

  Future<String> _getDirectoryPath() async {
    if (kIsWeb) return '';
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/it_letter_pad_history';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<List<ExcelFileMetadata>> getHistory() async {
    if (kIsWeb) return _webMetadataCache;
    
    try {
      final dir = await _getDirectoryPath();
      final metaFile = File('$dir/$_metadataFileName');
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList.map((e) => ExcelFileMetadata.fromJson(e)).toList()..sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      }
    } catch (e) {
      print('Error loading history: $e');
    }
    return [];
  }

  Future<void> _saveHistory(List<ExcelFileMetadata> history) async {
    if (kIsWeb) {
      _webMetadataCache = history;
      return;
    }
    try {
      final dir = await _getDirectoryPath();
      final metaFile = File('$dir/$_metadataFileName');
      final content = jsonEncode(history.map((e) => e.toJson()).toList());
      await metaFile.writeAsString(content);
    } catch (e) {
      print('Error saving history: $e');
    }
  }

  Future<void> saveExcelFile(String originalFileName, String fileType, Uint8List bytes, {List<String>? batches}) async {
    final id = _uuid.v4();
    final metadata = ExcelFileMetadata(
      id: id,
      originalFileName: originalFileName,
      fileType: fileType,
      dateAdded: DateTime.now(),
      batches: batches,
    );

    if (kIsWeb) {
      _webCache[id] = bytes;
      _webMetadataCache.add(metadata);
      return;
    }

    try {
      final dir = await _getDirectoryPath();
      final file = File('$dir/$id.xlsx');
      await file.writeAsBytes(bytes);

      final history = await getHistory();
      history.add(metadata);
      await _saveHistory(history);
    } catch (e) {
      print('Error saving excel file: $e');
    }
  }

  Future<Uint8List?> loadExcelFile(String id) async {
    if (kIsWeb) return _webCache[id];

    try {
      final dir = await _getDirectoryPath();
      final file = File('$dir/$id.xlsx');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      print('Error loading excel file: $e');
    }
    return null;
  }
  
  Future<void> deleteExcelFile(String id) async {
    if (kIsWeb) {
      _webCache.remove(id);
      _webMetadataCache.removeWhere((m) => m.id == id);
      return;
    }
    
    try {
      final dir = await _getDirectoryPath();
      final file = File('$dir/$id.xlsx');
      if (await file.exists()) {
        await file.delete();
      }
      
      final history = await getHistory();
      history.removeWhere((m) => m.id == id);
      await _saveHistory(history);
    } catch (e) {
      print('Error deleting excel file: $e');
    }
  }
}
