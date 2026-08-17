import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/report_card_data.dart';
import '../models/subject_mapping.dart';

class ExcelParserService {
  List<String> getAvailableSubjectHeaders(Uint8List bytes) {
    var excel = Excel.decodeBytes(bytes);
    List<String> subjectHeaders = [];
    
    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table]!;
      if (sheet.rows.isEmpty) continue;

      int headerRowIndex = -1;
      for (int r = 0; r < sheet.rows.length && r < 10; r++) {
        var row = sheet.rows[r];
        bool hasRoll = row.any((c) => (c?.value?.toString().toLowerCase() ?? '').contains('roll') || (c?.value?.toString().toLowerCase() ?? '').contains('reg'));
        bool hasName = row.any((c) => (c?.value?.toString().toLowerCase() ?? '').contains('name') || (c?.value?.toString().toLowerCase() ?? '').contains('student'));
        if (hasRoll && hasName) {
          headerRowIndex = r;
          break;
        }
      }

      if (headerRowIndex == -1) continue; // Skip sheet if no header row found

      var headerRow = sheet.rows[headerRowIndex];
      if (headerRow.isEmpty) continue;

      Set<String> standardHeaders = {
        's.no', 'sno', 'roll no.', 'roll no', 'rollno', 'reg no', 'reg no.', 'regno', 'register no', 'register number',
        'name', 'student name',
        'class', 'date', 'total mark', 'total marks', 'scored mark', 'scored marks',
        'rank', 'attendance', 'attendance %', 'absent', 'days absent', 'absent days', 
        'from date', 'from', 'to date', 'to', 'remarks', 'address'
      };

      for (var cell in headerRow) {
        if (cell != null && cell.value != null) {
          String rawVal = cell.value.toString();
          String headerVal = rawVal.trim().toUpperCase();
          if (headerVal.isNotEmpty && !standardHeaders.contains(rawVal.trim().toLowerCase())) {
            subjectHeaders.add(headerVal);
            
            // Extract individual tokens in case the subject code is inside a longer string (e.g. "Subject CS3452")
            var tokens = headerVal.split(RegExp(r'[\s\(\)\-\_\[\]]+'));
            for (var t in tokens) {
              if (t.isNotEmpty) subjectHeaders.add(t);
            }
          }
        }
      }
    }
    return subjectHeaders;
  }

  List<ReportCardData> parseExcel(Uint8List bytes, {List<SubjectMapping>? subjectMappings}) {
    var excel = Excel.decodeBytes(bytes);
    List<ReportCardData> parsedStudents = [];

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table]!;
      if (sheet.rows.isEmpty) continue;

      int headerRowIndex = 0;
      for (int r = 0; r < sheet.rows.length && r < 10; r++) {
        var row = sheet.rows[r];
        bool hasRoll = row.any((c) {
          String val = c?.value?.toString().toLowerCase() ?? '';
          return val.contains('roll') || val.contains('reg') || val.contains('register');
        });
        bool hasName = row.any((c) {
          String val = c?.value?.toString().toLowerCase() ?? '';
          return val.contains('name') || val.contains('student');
        });
        if (hasRoll && hasName) {
          headerRowIndex = r;
          break;
        }
      }

      var headerRow = sheet.rows[headerRowIndex];
      if (headerRow.isEmpty) continue;

      Map<String, int> colMap = {};
      List<String> originalHeaders = [];
      for (int i = 0; i < headerRow.length; i++) {
        var cell = headerRow[i];
        if (cell != null && cell.value != null) {
          String headerVal = cell.value.toString().trim();
          colMap[headerVal.toLowerCase()] = i;
          originalHeaders.add(headerVal);
        } else {
          originalHeaders.add('');
        }
      }

      // Standard headers to ignore when looking for subjects
      Set<String> standardHeaders = {
        's.no', 'sno', 'roll no.', 'roll no', 'rollno', 'reg no', 'reg no.', 'regno', 'register no', 'register number',
        'name', 'student name',
        'class', 'date', 'total mark', 'total marks', 'scored mark', 'scored marks',
        'rank', 'attendance', 'attendance %', 'absent', 'days absent', 'absent days', 
        'from date', 'from', 'to date', 'to', 'remarks', 'address'
      };

      for (int r = headerRowIndex + 1; r < sheet.rows.length; r++) {
        var row = sheet.rows[r];
        if (row.isEmpty) continue;

        String getCellVal(String key) {
          String searchKey = key.toLowerCase();
          if (!colMap.containsKey(searchKey)) {
            try {
              searchKey = colMap.keys.firstWhere((k) => k.contains(searchKey));
            } catch (e) {
              return '';
            }
          }
          int idx = colMap[searchKey]!;
          if (idx >= row.length) return '';
          return row[idx]?.value?.toString().trim() ?? '';
        }

        String rollNo = getCellVal('roll no');
        if (rollNo.isEmpty) rollNo = getCellVal('rollno');
        if (rollNo.isEmpty) rollNo = getCellVal('reg no');
        if (rollNo.isEmpty) rollNo = getCellVal('regno');
        if (rollNo.isEmpty) rollNo = getCellVal('register');
        if (rollNo.isEmpty) continue; 

        String studentName = getCellVal('name');
        if (studentName.isEmpty) studentName = getCellVal('student name');

        String address = getCellVal('address');

        String daysAbsentStr = getCellVal('absent');
        if (daysAbsentStr.isEmpty) daysAbsentStr = getCellVal('days absent');
        int daysAbsent = int.tryParse(daysAbsentStr) ?? 0;

        String classAndSem = '';
        String date = '';
        String rank = '';
        String attendancePercentage = '';
        String fromDate = '';
        String toDate = '';
        String remarks = '';

        List<SubjectMark> subjects = [];
        List<String> availableSubjectCodes = [];
        int calculatedTotalScored = 0;
        int maxTotalMarks = 0;
        
        for (int i = 0; i < originalHeaders.length; i++) {
          String header = originalHeaders[i];
          if (header.isEmpty) continue;
          
          if (!standardHeaders.contains(header.toLowerCase())) {
            String scoredMark = row.length > i ? (row[i]?.value?.toString().trim() ?? '') : '';
            
            SubjectMapping? matchedMapping;
            if (subjectMappings != null) {
              String norm(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
              String normHeader = norm(header);
              
              for (var mapping in subjectMappings) {
                String normCode = norm(mapping.subjectCode);
                String normName = norm(mapping.subjectName);
                
                if ((normCode.isNotEmpty && normHeader.contains(normCode)) || 
                    (normName.isNotEmpty && normHeader.contains(normName))) {
                  matchedMapping = mapping;
                  break;
                }
              }
            }
            
            // Only process columns that matched a configured subject
            if (matchedMapping != null) {
              String subCode = matchedMapping.subjectCode;
              availableSubjectCodes.add(subCode);
              
              if (scoredMark.isNotEmpty) {
                int markInt = int.tryParse(scoredMark) ?? 0;
                calculatedTotalScored += markInt;
                maxTotalMarks += 100;
                
                String passFail = 'Fail';
                if (scoredMark.toUpperCase() == 'AB' || scoredMark.toUpperCase() == 'AAA' || scoredMark.toUpperCase() == 'U') {
                  passFail = 'Fail';
                } else if (markInt >= 50) {
                  passFail = 'Pass';
                }
                
                subjects.add(SubjectMark(
                  subjectName: matchedMapping.subjectName,
                  subjectCode: subCode,
                  totalMark: '100',
                  passingMark: '50',
                  scoredMark: scoredMark,
                  passFail: passFail,
                ));
              }
            }
          }
        }

        String totalMarksStr = maxTotalMarks.toString();
        String scoredMarksStr = calculatedTotalScored.toString();

        parsedStudents.add(ReportCardData(
          rollNo: rollNo,
          studentName: studentName,
          classAndSem: classAndSem,
          date: date,
          totalMarks: totalMarksStr,
          scoredMarks: scoredMarksStr,
          rank: rank,
          attendancePercentage: attendancePercentage,
          fromDate: fromDate,
          toDate: toDate,
          remarks: remarks,
          address: address,
          daysAbsent: daysAbsent,
          subjects: subjects,
          availableSubjectCodes: availableSubjectCodes,
        ));
      }
    }

    if (parsedStudents.isEmpty) {
      throw Exception('Could not find any valid student data. Make sure the Excel file has columns like "ROLL NO." and "NAME".');
    }

    return parsedStudents;
  }
}
