import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Couche de persistance SQLite pour bulletin_scolaire.
///
/// Migrée depuis [SharedPreferences] pour éviter les limites de taille et
/// offrir des requêtes performantes sur de grandes classes.
class DatabaseService {
  static Database? _database;
  static const String _kSharedKey = 'bulletin_data_v1';

  /// Version du schéma SQLite. À incrémenter si la structure change.
  static const int _schemaVersion = 1;

  // ── Tables ────────────────────────────────────────────────

  static const String _tblInfo = 'class_info';
  static const String _tblStudents = 'students';
  static const String _tblCourses = 'courses';
  static const String _tblMarks = 'marks';
  static const String _tblAppSettings = 'app_settings';

  // ── Init ──────────────────────────────────────────────────

  static Future<void> init() async {
    if (_database != null) return;
    try {
      final db = await _open();
      _database = db;
      debugPrint('SQLite ouvert');
    } catch (e) {
      debugPrint('Erreur opening SQLite : $e');
      rethrow;
    }
  }

  static Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/bulletin.db';
    return openDatabase(
      path,
      version: _schemaVersion,
      onCreate: (db, version) async {
        await _createTables(db);
        // Créer une entrée settings vide par défaut
        await db.insert(_tblAppSettings, {'key': 'revision', 'value': '0'});
      },
      onOpen: (db) {},
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_tblInfo (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tblStudents (
        id         TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        sex        TEXT DEFAULT '',
        birthPlace TEXT DEFAULT '',
        birthDate  TEXT DEFAULT '',
        permNo     TEXT DEFAULT '',
        idNo       TEXT DEFAULT '',
        decision   TEXT DEFAULT 'auto'
      )
    ''');

    await db.execute('''
      CREATE TABLE $_tblCourses (
        id       TEXT PRIMARY KEY,
        name     TEXT NOT NULL,
        max      INTEGER NOT NULL,
        active   INTEGER DEFAULT 1,
        teacher  TEXT DEFAULT ''
      )
    ''');

    // marks : un rang par couple (course_id, student_id), colonnes P1..P4, Ex1, Ex2
    await db.execute('''
      CREATE TABLE $_tblMarks (
        course_id  TEXT,
        student_id TEXT,
        p1         REAL,
        p2         REAL,
        ex1        REAL,
        p3         REAL,
        p4         REAL,
        ex2        REAL,
        PRIMARY KEY (course_id, student_id)
      )
    ''');
  }

  // ── ClassInfo ─────────────────────────────────────────────

  static Future<Map<String, String>> loadClassInfo() async {
    final rows = await _database!.query(_tblInfo);
    final map = <String, String>{};
    for (final r in rows) {
      map[r['key'] as String] = r['value'] as String;
    }
    return map;
  }

  static Future<void> saveClassInfo(Map<String, String> info) async {
    await _deleteAll(_tblInfo);
    for (final e in info.entries) {
      await _database!.insert(_tblInfo, {'key': e.key, 'value': e.value});
    }
  }

  // ── Courses ───────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> loadCourses() async {
    return _database!.query(_tblCourses, orderBy: 'name ASC');
  }

  static Future<void> saveCourse(CourseEntry c) async {
    await _database!.insertOrReplace(_tblCourses, c.toMap());
  }

  static Future<void> removeCourse(String id) async {
    await _database!.delete(_tblCourses, where: 'id = ?', whereArgs: [id]);
    await _database!.delete(
        _tblMarks, where: 'course_id = ?', whereArgs: [id]);
  }

  // ── Students ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> loadStudents() async {
    return _database!.query(_tblStudents, orderBy: 'name ASC');
  }

  static Future<void> saveStudent(StudentEntry s) async {
    await _database!.insertOrReplace(_tblStudents, s.toMap());
  }

  static Future<void> removeStudent(String id) async {
    await _database!.delete(_tblStudents, where: 'id = ?', whereArgs: [id]);
    await _database!.delete(
        _tblMarks, where: 'student_id = ?', whereArgs: [id]);
  }

  // ── Marks (6 slots: idx 0=P1,1=P2,2=Ex1,3=P3,4=P4,5=Ex2) ─

  static Future<List<double?>> loadMarkRow(String courseId, String studentId)
      async {
    final rows = await _database!.query(
      _tblMarks,
      where: 'course_id = ? AND student_id = ?',
      whereArgs: [courseId, studentId],
    );
    if (rows.isEmpty) return List<double?>.filled(6, null);
    final r = rows.first;
    return [
      _r(r['p1']),
      _r(r['p2']),
      _r(r['ex1']),
      _r(r['p3']),
      _r(r['p4']),
      _r(r['ex2']),
    ];
  }

  static Future<void> saveMark(
      String courseId, String studentId, Map<int, double?> marks) async {
    // Charger la ligne existante
    final existing = await loadMarkRow(courseId, studentId);
    // Appliquer les mises à jour
    for (final e in marks.entries) {
      existing[e.key] = e.value;
    }
    await _database!.insertOrReplace(_tblMarks, {
      'course_id': courseId,
      'student_id': studentId,
      'p1': existing[0],
      'p2': existing[1],
      'ex1': existing[2],
      'p3': existing[3],
      'p4': existing[4],
      'ex2': existing[5],
    });
  }

  static Future<void> clearMarks() async {
    await _deleteAll(_tblMarks);
    incrementRevision();
  }

  // ── App Settings ──────────────────────────────────────────

  static Future<String> getAppSetting(String key, String def) async {
    final rows = await _database!.query(
      _tblAppSettings,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return def;
    return rows.first['value'] as String;
  }

  static Future<void> setAppSetting(String key, String value) async {
    await _database!.insertOrReplace(
        _tblAppSettings, {'key': key, 'value': value});
  }

  static Future<int> getRevision() async {
    final v = await getAppSetting('revision', '0');
    return int.tryParse(v) ?? 0;
  }

  static Future<void> incrementRevision() async {
    final r = await getRevision();
    await setAppSetting('revision', '${r + 1}');
  }

  // ── Backup / Restore (JSON) ──────────────────────────────
  // Ces méthodes permettent de sérialiser tout l'état en JSON
  // pour export/import entre appareils (presse-papiers ou fichier).

  static Future<String> exportJson() async {
    final info = await loadClassInfo();
    final courses = await loadCourses();
    final students = await loadStudents();
    final revision = await getRevision();

    // Collecter toutes les notes
    final marksMap = <String, Map<String, List<dynamic>>>{};
    for (final course in courses) {
      final cid = course['id'] as String;
      final byStudent = <String, List<dynamic>>{};
      for (final student in students) {
        final sid = student['id'] as String;
        byStudent[sid] = (await loadMarkRow(cid, sid)).map((v) => v).toList();
      }
      if (byStudent.isNotEmpty) marksMap[cid] = byStudent;
    }

    final selectedCourse =
        await getAppSetting('selected_course', 'religion');

    return jsonEncode({
      'version': 2,
      'info': info,
      'courses': courses,
      'students': students,
      'marks': marksMap,
      'selectedCourse': selectedCourse,
      'revision': revision,
    });
  }

  static Future<void> importJson(String text) async {
    final j = jsonDecode(text) as Map<String, dynamic>;
    final version = (j['version'] as num?)?.toInt() ?? 1;

    // Info
    final infoMap = <String, String>{};
    if (version >= 2) {
      ((j['info'] ?? {}) as Map<String, dynamic>).forEach((k, v) {
        infoMap[k.toString()] = v.toString();
      });
    } else {
      // Legacy format
      final legacy = j['info'] as Map<String, dynamic>? ?? {};
      infoMap['province'] = legacy['province']?.toString() ?? '';
      infoMap['city'] = legacy['city']?.toString() ?? '';
      infoMap['commune'] = legacy['commune']?.toString() ?? '';
      infoMap['school'] = legacy['school']?.toString() ?? '';
      infoMap['code'] = legacy['code']?.toString() ?? '';
      infoMap['year'] = legacy['year']?.toString() ?? '';
      infoMap['className'] = legacy['className']?.toString() ?? '';
      infoMap['title'] = legacy['title']?.toString() ?? '';
      infoMap['teacher'] = legacy['teacher']?.toString() ?? '';
    }
    await saveClassInfo(infoMap);

    // Courses
    await _deleteAll(_tblCourses);
    final List ccourses = j['courses'] as List? ?? [];
    for (final raw in ccourses) {
      final m = raw as Map<String, dynamic>;
      await _database!.insert(_tblCourses, {
        'id': (m['id'] ?? '').toString(),
        'name': (m['name'] ?? '').toString(),
        'max': (m['max'] as num?)?.toInt() ?? 10,
        'active': (m['active'] as bool?) == true ? 1 : 0,
        'teacher': (m['teacher'] ?? '').toString(),
      });
    }

    // Students
    await _deleteAll(_tblStudents);
    final List cstudents = j['students'] as List? ?? [];
    for (final raw in cstudents) {
      final m = raw as Map<String, dynamic>;
      await _database!.insert(_tblStudents, {
        'id': (m['id'] ?? '').toString(),
        'name': (m['name'] ?? '').toString(),
        'sex': (m['sex'] ?? '').toString(),
        'birthPlace': (m['birthPlace'] ?? '').toString(),
        'birthDate': (m['birthDate'] ?? '').toString(),
        'permNo': (m['permNo'] ?? '').toString(),
        'idNo': (m['idNo'] ?? '').toString(),
        'decision': (m['decision'] ?? 'auto').toString(),
      });
    }

    // Marks
    await _deleteAll(_tblMarks);
    final rawMarks = (j['marks'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    rawMarks.forEach((cid, byStudent) {
      (byStudent as Map<String, dynamic>).forEach((sid, arr) {
        final list = ((arr ?? []) as List)
            .map<double?>((x) => x == null ? null : (x as num).toDouble())
            .toList();
        while (list.length < 6) list.add(null);
        saveMark(cid, sid, {
          0: list[0],
          1: list[1],
          2: list[2],
          3: list[3],
          4: list[4],
          5: list[5],
        });
      });
    });

    // Settings
    final sel = (j['selectedCourse'] as String?) ?? 'religion';
    await setAppSetting('selected_course', sel);
    if (j['revision'] != null) {
      await setAppSetting('revision', j['revision'].toString());
    }
  }

  // ── Migration from old SharedPreferences ──────────────────

  static Future<bool> hasSharedData() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kSharedKey) != null;
  }

  static Future<bool> importFromSharedIfNeeded() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kSharedKey);
    if (s == null) return false;
    await importJson(s);
    await p.remove(_kSharedKey);
    return true;
  }

  // ── Stats (pour le palmarès) ──────────────────────────────

  static Future<List<Map<String, dynamic>>> getAllStudentsWithTotal() async {
    // Renvoie tous les élèves avec leur total général calculé côté DB si possible,
    // sinon on renvoie juste les infos brutales. Le calcul complexe se fait dans Calc.
    return _database!.query(_tblStudents, orderBy: 'name ASC');
  }

  // ── Helpers ───────────────────────────────────────────────

  static Future<int> _deleteAll(String table) async {
    return _database!.delete(table);
  }

  static double? _r(dynamic v) => v == null ? null : (v as num).toDouble();
}

// ── Entry helpers ───────────────────────────────────────────

class CourseEntry {
  final String id;
  final String name;
  final int max;
  final bool active;
  final String teacher;
  CourseEntry({
    required this.id,
    required this.name,
    required this.max,
    this.active = true,
    this.teacher = '',
  });
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'max': max,
        'active': active ? 1 : 0,
        'teacher': teacher,
      };
}

class StudentEntry {
  final String id;
  String name;
  String sex;
  String birthPlace;
  String birthDate;
  String permNo;
  String idNo;
  String decision;

  StudentEntry({
    required this.id,
    required this.name,
    this.sex = '',
    this.birthPlace = '',
    this.birthDate = '',
    this.permNo = '',
    this.idNo = '',
    this.decision = 'auto',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sex': sex,
        'birthPlace': birthPlace,
        'birthDate': birthDate,
        'permNo': permNo,
        'idNo': idNo,
        'decision': decision,
      };
}
