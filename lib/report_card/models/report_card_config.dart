import 'subject_mapping.dart';

class ReportCardConfig {
  String periodicalTestNumber;
  String academicYear;
  String semesterType; // "ODD SEMESTER" or "EVEN SEMESTER"
  String year; // e.g., "II Year"
  String semester; // e.g., "III Semester"
  DateTime? fromDate;
  DateTime? toDate;
  int workingDays;
  List<String> advisors;
  List<SubjectMapping> subjectMappings;
  bool includePlacement;

  ReportCardConfig({
    this.periodicalTestNumber = '',
    this.academicYear = '',
    this.semesterType = '',
    this.year = '',
    this.semester = '',
    this.fromDate,
    this.toDate,
    this.workingDays = 0,
    this.includePlacement = false,
    List<String>? advisors,
    List<SubjectMapping>? subjectMappings,
  }) : advisors = advisors ?? [],
       subjectMappings = subjectMappings ?? [];
}
