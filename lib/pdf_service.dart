import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'models.dart';

pw.ThemeData _theme() => pw.ThemeData.withFont(
      base: pw.Font.times(),
      bold: pw.Font.timesBold(),
      italic: pw.Font.timesItalic(),
      boldItalic: pw.Font.timesBoldItalic(),
    );

pw.Widget _cell(
  String t, {
  bool bold = false,
  double size = 8,
  pw.TextAlign align = pw.TextAlign.center,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
    child: pw.Text(
      t,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

pw.Widget _line(String t,
    {double size = 8.5, bool bold = false, bool strike = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Text(
      t,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        decoration: strike ? pw.TextDecoration.lineThrough : null,
      ),
    ),
  );
}

String _dots(String v, [int n = 18]) => v.isEmpty ? ''.padRight(n, '.') : v;

Future<Uint8List> buildBulletinsPdf(AppState a, List<Student> list) async {
  final doc = pw.Document(theme: _theme());
  if (list.isEmpty) {
    doc.addPage(pw.Page(build: (ctx) => pw.Text('Aucun élève.')));
  }
  for (final s in list) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 22),
        build: (ctx) => pw.FittedBox(
          fit: pw.BoxFit.scaleDown,
          alignment: pw.Alignment.topCenter,
          child: pw.SizedBox(width: 539, child: _bulletin(a, s)),
        ),
      ),
    );
  }
  return doc.save();
}

pw.Widget _bulletin(AppState a, Student s) {
  final i = a.info;

  // Regroupement des cours par maxima (10, 20, 40, 50...), du plus petit au plus grand.
  final groups = <int, List<Course>>{};
  for (final c in a.courses.where((c) => c.active)) {
    groups.putIfAbsent(c.max, () => []).add(c);
  }
  final keys = groups.keys.toList()..sort();

  final rows = <pw.TableRow>[];
  rows.add(pw.TableRow(
    decoration: pw.BoxDecoration(color: PdfColors.grey300),
    children: [
      _cell('BRANCHES', bold: true),
      for (final l in kColLabels) _cell(l, bold: true),
      _cell('REPECH. %', bold: true, size: 6.5),
      _cell('SIGNAT. PROF.', bold: true, size: 6.5),
    ],
  ));

  for (final m in keys) {
    rows.add(pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _cell('MAXIMA', bold: true, align: pw.TextAlign.left),
        for (var k = 0; k < 9; k++) _cell('${m * kMult[k]}', bold: true),
        _cell(''),
        _cell(''),
      ],
    ));
    for (final c in groups[m]!) {
      final row = a.rowOf(c.id, s.id);
      rows.add(pw.TableRow(children: [
        _cell(c.name, align: pw.TextAlign.left),
        for (var k = 0; k < 9; k++)
          _cell(fmt(Calc.col(row, k)), bold: k == 3 || k == 7 || k == 8),
        _cell(''),
        _cell(''),
      ]));
    }
  }

  final has = [for (var k = 0; k < 9; k++) Calc.hasData(a, s.id, k)];
  final tot = [for (var k = 0; k < 9; k++) Calc.total(a, s.id, k)];
  final mx = [for (var k = 0; k < 9; k++) Calc.maxGen(a, k)];
  final pc = [for (var k = 0; k < 9; k++) Calc.pct(tot[k], mx[k])];
  const periodCols = [0, 1, 4, 5];
  final conduct = a.rowOf(kConduct, s.id);

  pw.TableRow summary(String label, String Function(int k) f,
      {bool bold = false, bool shade = false}) {
    return pw.TableRow(
      decoration: shade ? pw.BoxDecoration(color: PdfColors.grey200) : null,
      children: [
        _cell(label, bold: true, align: pw.TextAlign.left),
        for (var k = 0; k < 9; k++) _cell(f(k), bold: bold),
        _cell(''),
        _cell(''),
      ],
    );
  }

  rows.add(summary('MAXIMA GENER.', (k) => fmt(mx[k]), bold: true, shade: true));
  rows.add(summary('TOTAUX', (k) => has[k] ? fmt(tot[k]) : '', bold: true));
  rows.add(summary('POURCENTAGE', (k) => has[k] ? fmt(pc[k]) : '', bold: true));
  rows.add(summary("PLACE / NBRE D'ELEVES", (k) => Calc.place(a, s.id, k)));
  rows.add(summary('APPLICATION',
      (k) => periodCols.contains(k) && has[k] ? Calc.appr(pc[k]) : ''));
  rows.add(summary('CONDUITE',
      (k) => periodCols.contains(k) ? fmt(Calc.col(conduct, k)) : ''));

  final widths = <int, pw.TableColumnWidth>{
    0: pw.FlexColumnWidth(3.2),
    1: pw.FlexColumnWidth(0.95),
    2: pw.FlexColumnWidth(0.95),
    3: pw.FlexColumnWidth(0.95),
    4: pw.FlexColumnWidth(0.95),
    5: pw.FlexColumnWidth(0.95),
    6: pw.FlexColumnWidth(0.95),
    7: pw.FlexColumnWidth(0.95),
    8: pw.FlexColumnWidth(0.95),
    9: pw.FlexColumnWidth(0.95),
    10: pw.FlexColumnWidth(1.0),
    11: pw.FlexColumnWidth(1.5),
  };

  pw.Widget top(String t, int flex) => pw.Expanded(
        flex: flex,
        child: pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          child: _cell(t, bold: true),
        ),
      );

  final dec = Calc.decision(a, s);
  final today = '${i.city}, le ...../...../20....';

  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Center(child: _line('République Démocratique du Congo', size: 9, bold: true)),
      pw.Center(
          child: _line(
              "MINISTERE DE L'ENSEIGNEMENT PRIMAIRE, SECONDAIRE ET TECHNIQUE",
              size: 8.5)),
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _line('N° ID. : ${_dots(s.idNo)}'),
                _line('PROVINCE : ${i.province}'),
                _line('VILLE : ${i.city}'),
                _line('COMMUNE / TER. : ${i.commune}'),
                _line('ECOLE : ${i.school}', bold: true),
                _line('CODE : ${_dots(i.code, 12)}'),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _line('ELEVE : ${s.name}', bold: true),
                _line('SEXE : ${s.sex}'),
                _line('NE(E) A : ${s.birthPlace}, LE ${s.birthDate}'),
                _line('CLASSE : ${i.className}'),
                _line('N° PERM. : ${_dots(s.permNo, 14)}'),
                _line('ANNEE SCOLAIRE : ${i.year}'),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text(
          'BULLETIN DE LA ${i.title}',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            decoration: pw.TextDecoration.underline,
          ),
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Row(children: [
        top('', 320),
        top('PREMIER SEMESTRE', 380),
        top('SECOND SEMESTRE', 380),
        top('', 95),
        top('EXAMEN DE REPECHAGE', 100),
        top('', 150),
      ]),
      pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        columnWidths: widths,
        children: rows,
      ),
      pw.SizedBox(height: 8),
      _line("- L'élève ne pourra passer dans la classe supérieure s'il n'a subi avec succès un examen de repêchage en : ........................................"),
      _line("- L'élève passe dans la classe supérieure", strike: dec == 'double'),
      _line("- L'élève double sa classe", strike: dec == 'passe'),
      pw.SizedBox(height: 4),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: _line('Fait à $today'),
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _line("Signature de l'élève")),
          pw.Expanded(child: _line('Signature du Responsable')),
          pw.Expanded(child: _line("Sceau de l'école")),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _line("Le Chef d'Etablissement"),
                _line('(Nom et signature)'),
              ],
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 36),
      _line('Note importante : Le bulletin est sans valeur s\'il est raturé ou surchargé',
          size: 7.5),
      _line('Interdiction formelle de reproduire ce bulletin sous peines des sanctions prévues par la loi',
          size: 7.5),
    ],
  );
}

Future<Uint8List> buildPalmaresPdf(AppState a) async {
  final rows = Calc.palmares(a);
  final i = a.info;
  final doc = pw.Document(theme: _theme());
  final success = rows.where((r) => r.obs == 'Réussite').length;
  final fail = rows.where((r) => r.obs == 'Echec').length;

  pw.Widget head(String t) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 10)),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => [
        pw.Center(
          child: pw.Text(i.school,
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Center(child: head('${i.commune} / ${i.city}')),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            'FICHE DE PROCLAMATION - ANNEE SCOLAIRE ${i.year}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              decoration: pw.TextDecoration.underline,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        head('PERIODE : Fin d\'année'),
        head('CLASSE : ${i.className}'),
        head('TITULAIRE : ${i.teacher}'),
        head('INSCRITS : ${a.students.length} élèves'),
        head('PARTICIPANTS : ${rows.length} élèves'),
        head('REUSSITES : $success élèves'),
        head('ECHECS : $fail élèves'),
        head('ABANDONS : ${a.students.length - rows.length} élèves'),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: <int, pw.TableColumnWidth>{
            0: pw.FlexColumnWidth(0.8),
            1: pw.FlexColumnWidth(4),
            2: pw.FlexColumnWidth(0.8),
            3: pw.FlexColumnWidth(1),
            4: pw.FlexColumnWidth(0.8),
            5: pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _cell('PLACE', bold: true, size: 9),
                _cell('NOM ET POST-NOM', bold: true, size: 9),
                _cell('SEXE', bold: true, size: 9),
                _cell('%', bold: true, size: 9),
                _cell('APPL.', bold: true, size: 9),
                _cell('OBS.', bold: true, size: 9),
              ],
            ),
            for (final r in rows)
              pw.TableRow(children: [
                _cell('${r.place}', size: 9),
                _cell(r.student.name, size: 9, align: pw.TextAlign.left),
                _cell(r.student.sex, size: 9),
                _cell(fmt(r.pct), size: 9),
                _cell(r.appr, size: 9),
                _cell(r.obs, size: 9),
              ]),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
