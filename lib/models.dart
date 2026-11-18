import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'database_service.dart';
import 'models.dart';

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

// ── AppState ────────────────────────────────────────────────

class AppState extends ChangeNotifier {
  ClassInfo info = ClassInfo();
  List<Course> courses = [];
  List<Student> students = [];
  int revision = 0;
  String selectedCourse = 'religion';

  // Cache local des notes : courseId -> studentId -> [P1,P2,Ex1,P3,P4,Ex2]
  final _marksCache = <String, Map<String, List<double?>>>{};

  Timer? _timer;
  int _counter = 0;

  /// Génère un ID unique pour un nouvel élève ou cours.
  String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  /// Chargement initial depuis SQLite.
  Future<void> load() async {
    try {
      await DatabaseService.init();

      // Migration depuis SharedPreferences si donnée ancienne présente
      final migrated = await DatabaseService.importFromSharedIfNeeded();
      if (migrated) debugPrint('Migration SharedPreferences → SQLite OK');

      // Charger les données
      await _loadAll();
    } catch (e) {
      debugPrint('Chargement impossible : $e');
    }
  }

  Future<void> _loadAll() async {
    // Info
    final infoMap = await DatabaseService.loadClassInfo();
    if (infoMap.isNotEmpty) {
      info = ClassInfo(
        province: infoMap['province'] ?? info.province,
        city: infoMap['city'] ?? info.city,
        commune: infoMap['commune'] ?? info.commune,
        school: infoMap['school'] ?? info.school,
        code: infoMap['code'] ?? info.code,
        year: infoMap['year'] ?? info.year,
        className: infoMap['className'] ?? info.className,
        title: infoMap['title'] ?? info.title,
        teacher: infoMap['teacher'] ?? info.teacher,
      );
    }

    // Courses
    final courseRows = await DatabaseService.loadCourses();
    if (courseRows.isEmpty) {
      courses = defaultCourses();
      // Sauvegarder les cours par défaut
      for (final c in courses) {
        await DatabaseService.saveCourse(CourseEntry(
          id: c.id,
          name: c.name,
          max: c.max,
          active: c.active,
          teacher: c.teacher,
        ));
      }
    } else {
      courses = courseRows.map((r) => Course(
            id: r['id'] as String,
            name: r['name'] as String,
            max: (r['max'] as num).toInt(),
            active: (r['active'] as int) == 1,
            teacher: r['teacher'] as String,
          )).toList();
    }

    // Students
    final stuRows = await DatabaseService.loadStudents();
    students = stuRows.map((r) => Student(
          id: r['id'] as String,
          name: r['name'] as String,
          sex: r['sex'] as String,
          birthPlace: r['birthPlace'] as String,
          birthDate: r['birthDate'] as String,
          permNo: r['permNo'] as String,
          idNo: r['idNo'] as String,
          decision: r['decision'] as String,
        )).toList();

    // Settings
    selectedCourse =
        await DatabaseService.getAppSetting('selected_course', 'religion');
    revision = await DatabaseService.getRevision();

    notifyListeners();
  }

  /// Sérialisation JSON complète (pour backup/export).
  Future<String> exportJson() async {
    return DatabaseService.exportJson();
  }

  /// Restauration depuis un JSON (pour restore/import).
  Future<void> importJson(String text) async {
    await DatabaseService.importJson(text);
    await _loadAll();
  }

  /// Persist une modification (note seule → immediate; autre → debounce).
  void changed() {
    notifyListeners();
  }

  /// Retourne une copie de la ligne en cache (null si non chargée).
  List<double?>? getCachedRow(String courseId, String studentId) {
    final byStudent = _marksCache[courseId];
    return byStudent?[studentId];
  }

  /// Renvoie la ligne de 6 valeurs pour un cours/élève.
  List<double?> rowOf(String courseId, String studentId) {
    // Vérifier le cache
    final byStudent = _marksCache[courseId];
    if (byStudent != null && byStudent.containsKey(studentId)) {
      return byStudent[studentId]!;
    }
    // Charger depuis la DB
    final row = DatabaseService.loadMarkRow(courseId, studentId);
    row.then((list) {
      _marksCache.putIfAbsent(courseId, () => {})[studentId] = list;
    });
    return List<double?>.filled(6, null);
  }

  /// Mettre à jour une note et persist en BDD.
  Future<void> setMark(
      String courseId, String studentId, int idx, double? v) async {
    // Lire la ligne actuelle
    final byStudent = _marksCache[courseId] ?? {};
    final row = byStudent[studentId] ?? List<double?>.filled(6, null);
    while (row.length < 6) row.add(null);
    row[idx] = v;
    byStudent[studentId] = row;
    _marksCache[courseId] = byStudent;

    await DatabaseService.saveMark(courseId, studentId, {idx: v});
    changed();
  }

  /// Tri alphabétique des élèves.
  void sortStudents() {
    students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Ajouter un élève.
  Future<void> addStudent(Student s) async {
    students.add(s);
    sortStudents();
    await DatabaseService.saveStudent(StudentEntry(
      id: s.id,
      name: s.name,
      sex: s.sex,
      birthPlace: s.birthPlace,
      birthDate: s.birthDate,
      permNo: s.permNo,
      idNo: s.idNo,
      decision: s.decision,
    ));
    changed();
  }

  /// Supprimer un élève.
  Future<void> removeStudent(Student s) async {
    students.removeWhere((x) => x.id == s.id);
    await DatabaseService.removeStudent(s.id);
    changed();
  }

  /// Ajouter un cours.
  Future<void> addCourse(String name, int max) async {
    final id = newId();
    courses.add(Course(id: id, name: name, max: max));
    await DatabaseService.saveCourse(CourseEntry(id: id, name: name, max: max));
    changed();
  }

  /// Supprimer un cours.
  Future<void> removeCourse(Course c) async {
    courses.removeWhere((x) => x.id == c.id);
    _marksCache.remove(c.id);
    await DatabaseService.removeCourse(c.id);
    if (selectedCourse == c.id) {
      selectedCourse = courses.firstOrNull?.id ?? kConduct;
    }
    changed();
  }

  /// Effacer toutes les notes (conserve élèves + cours).
  Future<void> clearMarks() async {
    await DatabaseService.clearMarks();
    _marksCache.clear();
    changed();
  }

  /// Sélectionner un cours actif.
  void selectCourse(String id) {
    selectedCourse = id;
    DatabaseService.setAppSetting('selected_course', id);
    changed();
  }
}

final app = AppState();

class PalmaresRow {
  final Student student;
  final double pct;
  final int place;
  final String appr;
  final String obs;
  PalmaresRow(this.student, this.pct, this.place, this.appr, this.obs);
}

// ── Calc (logique pure — inchangée) ─────────────────────────

class Calc {
  static double? col(List<double?> r, int i) {
    switch (i) {
      case 0: return r[0];
      case 1: return r[1];
      case 2: return r[2];
      case 3:
        if (r[0] == null || r[1] == null || r[2] == null) return null;
        return r[0]! + r[1]! + r[2]!;
      case 4: return r[3];
      case 5: return r[4];
      case 6: return r[5];
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

  /// Pourcentage tronqué à une décimale (ROUNDDOWN d'Excel).
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

  /// 'passe', 'double' ou '' (pas encore de données).
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
        s, p, place, appr(p),
        d == 'passe' ? 'Réussite' : (d == 'double' ? 'Echec' : ''),
      ));
    }
    return out;
  }
}
