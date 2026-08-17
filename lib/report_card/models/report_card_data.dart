class SubjectMark {
  final String subjectName;
  final String subjectCode;
  final String totalMark;
  final String passingMark;
  final String scoredMark;
  final String passFail;

  SubjectMark({
    required this.subjectName,
    required this.subjectCode,
    required this.totalMark,
    required this.passingMark,
    required this.scoredMark,
    required this.passFail,
  });
}

class ReportCardData {
  final String rollNo;
  final String studentName;
  final String classAndSem;
  final String date;
  
  final String totalMarks;
  final String scoredMarks;
  String rank;
  final String attendancePercentage;
  final String fromDate;
  final String toDate;
  final String remarks;
  final String address;
  final int daysAbsent; // NEW FIELD

  final List<SubjectMark> subjects;
  final List<String> availableSubjectCodes; // NEW FIELD for validation

  bool isSelected;

  ReportCardData({
    required this.rollNo,
    required this.studentName,
    required this.classAndSem,
    required this.date,
    required this.totalMarks,
    required this.scoredMarks,
    required this.rank,
    required this.attendancePercentage,
    required this.fromDate,
    required this.toDate,
    required this.remarks,
    required this.address,
    required this.daysAbsent,
    required this.subjects,
    this.availableSubjectCodes = const [],
    this.isSelected = false,
  });
}
