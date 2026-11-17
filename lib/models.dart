import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Multiplicateur du maxima de periode pour chacune des 9 colonnes du bulletin :
/// 1ere P., 2eme P., Exam., Total S1, 3eme P., 4eme P., Exam., Total S2, Total general.
const List<int> kMult = [1, 1, 2, 4, 1, 1, 2, 4, 8];

/// Index de saisie (0..5 = P1, P2, Ex1, P3, P4, Ex2) pour chaque colonne ; -1 = colonne calculee.
const List<int> kDataIdx = [0, 1, 2, -1, 3, 4, 5, -1, -1];

const List<String> kColLabels = [
  '1ère P.',
  '2ème P.',
  'Exam.',
  'Total',
  '3ème P.',
  '4ème P.',
  'Exam.',
  'Total',
  'Tot. gén.',
];

const String kConduct = 'conduite';

String fmt(double? v, {int dec = 1}) {
  if (v == null) return '';
  var s = v.toStringAsFixed(dec);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s.replaceAll('.', ',');
}

double? parseNum(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

class ClassInfo {
  String province;
  String city;
  String commune;
  String school;
  String code;
  String year;
  String className;
  String title;
  String teacher;

  ClassInfo({
    this.province = 'SUD-KIVU',
    this.city = 'BUKAVU',
    this.commune = 'IBANDA',
    this.school = 'INSTITUT AMANI',
    this.code = '',
    this.year = '2026 - 2027',
    this.className = '2ème HP',
    this.title = '2ème ANNEE HUMANITES PEDAGOGIE GENERALE',
    this.teacher = '',
  });

  Map<String, dynamic> toJson() => {
        'province': province,
        'city': city,
        'commune': commune,
        'school': school,
        'code': code,
        'year': year,
        'className': className,
        'title': title,
        'teacher': teacher,
      };

  factory ClassInfo.fromJson(Map<String, dynamic> j) {
    final d = ClassInfo();
    String g(String k, String def) => (j[k] ?? def).toString();
    return ClassInfo(
      province: g('province', d.province),
      city: g('city', d.city),
      commune: g('commune', d.commune),
      school: g('school', d.school),
      code: g('code', d.code),
      year: g('year', d.year),
      className: g('className', d.className),
      title: g('title', d.title),
      teacher: g('teacher', d.teacher),
    );
  }
}

class Student {
  final String id;
  String name;
  String sex;
  String birthPlace;
  String birthDate;
  String permNo;
  String idNo;

  /// 'auto', 'passe' ou 'double'
  String decision;

  Student({
    required this.id,
    required this.name,
    this.sex = '',
    this.birthPlace = '',
    this.birthDate = '',
    this.permNo = '',
    this.idNo = '',
    this.decision = 'auto',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sex': sex,
        'birthPlace': birthPlace,
        'birthDate': birthDate,
        'permNo': permNo,
        'idNo': idNo,
        'decision': decision,
      };

  factory Student.fromJson(Map<String, dynamic> j) {
    String g(String k, String def) => (j[k] ?? def).toString();
    return Student(
      id: g('id', ''),
      name: g('name', ''),
      sex: g('sex', ''),
      birthPlace: g('birthPlace', ''),
      birthDate: g('birthDate', ''),
      permNo: g('permNo', ''),
      idNo: g('idNo', ''),
      decision: g('decision', 'auto'),
    );
  }
}

class Course {
  final String id;
  String name;

  /// Maxima d'une periode (10, 20, 40, 50...). L'examen vaut le double.
  int max;
  bool active;
  String teacher;

  Course({
    required this.id,
    required this.name,
    required this.max,
    this.active = true,
    this.teacher = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'max': max,
        'active': active,
        'teacher': teacher,
      };

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        max: ((j['max'] as num?) ?? 10).toInt(),
        active: (j['active'] as bool?) ?? true,
        teacher: (j['teacher'] ?? '').toString(),
      );
}

List<Course> defaultCourses() => [
      Course(id: 'religion', name: 'Religion', max: 10),
      Course(id: 'ev', name: 'Education à la vie', max: 10),
      Course(id: 'ecm', name: 'Ed. Civ. & Morale', max: 10),
      Course(id: 'bio_mc', name: 'Biologie / Micro Chimie', max: 20),
      Course(id: 'dessin', name: 'Dessin', max: 20),
      Course(id: 'gymna', name: 'Education physique', max: 20),
      Course(id: 'eco_pol', name: 'Economie politique', max: 20),
      Course(id: 'music', name: 'Education musicale / Théâtrale', max: 20),
      Course(id: 'geo', name: 'Géographie', max: 20),
      Course(id: 'histoire', name: 'Histoire', max: 20),
      Course(id: 'inform', name: 'Informatique', max: 20),
      Course(id: 'lang_nat', name: 'Langues nationales', max: 20),
      Course(id: 'micro_bio', name: 'Micro Biologie', max: 20, active: false),
      Course(id: 'physique', name: 'Physique', max: 20),
      Course(id: 'dida_disc', name: 'Didactique des disciplines', max: 40),
      Course(id: 'dida_gen', name: 'Didactique générale', max: 40),
      Course(id: 'mathem', name: 'Mathématiques', max: 40),
      Course(id: 'pedag', name: 'Pédagogie', max: 40),
      Course(id: 'psycho', name: 'Psychologie', max: 40),
      Course(id: 'anglais', name: 'Anglais', max: 50),
      Course(id: 'francais', name: 'Français', max: 50),
    ];

class AppState extends ChangeNotifier {
  static const String _key = 'bulletin_data_v1';

  ClassInfo info = ClassInfo();
  List<Course> courses = defaultCourses();
  List<Student> students = [];

  /// courseId -> studentId -> [P1, P2, Ex1, P3, P4, Ex2]
  Map<String, Map<String, List<double?>>> marks = {};
  String selectedCourse = 'religion';

  /// Incremente a chaque restauration pour reinitialiser les champs de saisie.
  int revision = 0;

  Timer? _timer;
  int _counter = 0;

  String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_key);
      if (s != null) importJson(s);
    } catch (e) {
      debugPrint('Chargement impossible : $e');
    }
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, exportJson());
    } catch (e) {
      debugPrint('Enregistrement impossible : $e');
    }
  }

  /// A appeler apres toute modification : notifie l'interface et enregistre.
  void changed() {
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), _persist);
  }

  String exportJson() => jsonEncode({
        'version': 1,
        'info': info.toJson(),
        'courses': courses.map((c) => c.toJson()).toList(),
        'students': students.map((s) => s.toJson()).toList(),
        'marks': marks,
        'selectedCourse': selectedCourse,
      });

  void importJson(String text) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    final newInfo = ClassInfo.fromJson(
        (j['info'] ?? <String, dynamic>{}) as Map<String, dynamic>);
    var newCourses = ((j['courses'] ?? []) as List)
        .map((e) => Course.fromJson(e as Map<String, dynamic>))
        .toList();
    if (newCourses.isEmpty) newCourses = defaultCourses();
    final newStudents = ((j['students'] ?? []) as List)
        .map((e) => Student.fromJson(e as Map<String, dynamic>))
        .toList();
    final newMarks = <String, Map<String, List<double?>>>{};
    final raw = (j['marks'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    raw.forEach((cid, v) {
      final byStudent = <String, List<double?>>{};
      (v as Map<String, dynamic>).forEach((sid, arr) {
        final list = (arr as List)
            .map<double?>((x) => x == null ? null : (x as num).toDouble())
            .toList();
        while (list.length < 6) {
          list.add(null);
        }
        byStudent[sid] = list;
      });
      newMarks[cid] = byStudent;
    });
    info = newInfo;
    courses = newCourses;
    students = newStudents;
    marks = newMarks;
    selectedCourse = (j['selectedCourse'] ?? 'religion').toString();
    revision++;
    notifyListeners();
  }

  List<double?> rowOf(String courseId, String studentId) {
    return marks[courseId]?[studentId] ?? List<double?>.filled(6, null);
  }

  void setMark(String courseId, String studentId, int idx, double? v) {
    final byStudent = marks.putIfAbsent(courseId, () => {});
    final row =
        byStudent.putIfAbsent(studentId, () => List<double?>.filled(6, null));
    row[idx] = v;
    changed();
  }

  void sortStudents() {
    students
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void addStudent(Student s) {
    students.add(s);
    sortStudents();
    changed();
  }

  void removeStudent(Student s) {
    students.removeWhere((x) => x.id == s.id);
    for (final m in marks.values) {
      m.remove(s.id);
    }
    changed();
  }

  void addCourse(String name, int max) {
    courses.add(Course(id: newId(), name: name, max: max));
    changed();
  }

  void removeCourse(Course c) {
    courses.removeWhere((x) => x.id == c.id);
    marks.remove(c.id);
    changed();
  }

  void clearMarks() {
    marks = {};
    revision++;
    changed();
  }
}

final AppState app = AppState();

class PalmaresRow {
  final Student student;
  final double pct;
  final int place;
  final String appr;
  final String obs;
  PalmaresRow(this.student, this.pct, this.place, this.appr, this.obs);
}

/// Toutes les regles de calcul du bulletin (reprises du classeur Excel).
class Calc {
  /// Valeur d'une colonne (0..8) pour une ligne de cotes.
  static double? col(List<double?> r, int i) {
    switch (i) {
      case 0:
        return r[0];
      case 1:
        return r[1];
      case 2:
        return r[2];
      case 3:
        if (r[0] == null || r[1] == null || r[2] == null) return null;
        return r[0]! + r[1]! + r[2]!;
      case 4:
        return r[3];
      case 5:
        return r[4];
      case 6:
        return r[5];
      case 7:
        if (r[3] == null || r[4] == null || r[5] == null) return null;
        return r[3]! + r[4]! + r[5]!;
      default:
        final a = col(r, 3);
        final b = col(r, 7);
        if (a == null || b == null) return null;
        return a + b;
    }
  }

  static Iterable<Course> activeCourses(AppState a) =>
      a.courses.where((c) => c.active);

  static double total(AppState a, String sid, int i) {
    var s = 0.0;
    for (final c in activeCourses(a)) {
      final v = col(a.rowOf(c.id, sid), i);
      if (v != null) s += v;
    }
    return s;
  }

  static bool hasData(AppState a, String sid, int i) {
    for (final c in activeCourses(a)) {
      if (col(a.rowOf(c.id, sid), i) != null) return true;
    }
    return false;
  }

  static double maxGen(AppState a, int i) {
    var s = 0.0;
    for (final c in activeCourses(a)) {
      s += c.max * kMult[i];
    }
    return s;
  }

  /// Pourcentage tronque a une decimale (ROUNDDOWN d'Excel).
  static double pct(double tot, double max) {
    if (max <= 0) return 0;
    return (tot * 100 / max * 10 + 1e-9).floorToDouble() / 10;
  }

  static String place(AppState a, String sid, int i) {
    if (!hasData(a, sid, i)) return '/';
    final mine = total(a, sid, i);
    var better = 0;
    var part = 0;
    for (final s in a.students) {
      if (!hasData(a, s.id, i)) continue;
      part++;
      if (total(a, s.id, i) > mine + 1e-9) better++;
    }
    return '${better + 1}/$part';
  }

  static String appr(double p) {
    if (p <= 0) return '';
    if (p < 50) return 'M';
    if (p < 55) return 'AB';
    if (p < 70) return 'B';
    if (p < 80) return 'TB';
    return 'E';
  }

  static double annualPct(AppState a, String sid) =>
      pct(total(a, sid, 8), maxGen(a, 8));

  /// 'passe', 'double' ou '' (pas encore de donnees).
  static String decision(AppState a, Student s) {
    if (s.decision == 'passe' || s.decision == 'double') return s.decision;
    if (!hasData(a, s.id, 8)) return '';
    return annualPct(a, s.id) >= 50 ? 'passe' : 'double';
  }

  static List<PalmaresRow> palmares(AppState a) {
    final data = a.students.where((s) => hasData(a, s.id, 8)).toList();
    final tot = {for (final s in data) s.id: total(a, s.id, 8)};
    data.sort((x, y) => tot[y.id]!.compareTo(tot[x.id]!));
    final out = <PalmaresRow>[];
    for (var n = 0; n < data.length; n++) {
      final s = data[n];
      var place = n + 1;
      if (n > 0 && (tot[s.id]! - tot[data[n - 1].id]!).abs() < 1e-9) {
        place = out.last.place;
      }
      final p = annualPct(a, s.id);
      final d = decision(a, s);
      out.add(PalmaresRow(
        s,
        p,
        place,
        appr(p),
        d == 'passe' ? 'Réussite' : (d == 'double' ? 'Echec' : ''),
      ));
    }
    return out;
  }
}
