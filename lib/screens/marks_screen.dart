import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets.dart';

class MarksScreen extends StatelessWidget {
  const MarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final active = app.courses.where((c) => c.active).toList();
    final ids = [...active.map((c) => c.id), kConduct];
    if (!ids.contains(app.selectedCourse)) app.selectCourse(ids.first);
    final isConduct = app.selectedCourse == kConduct;
    final course = isConduct
        ? null
        : active.firstWhere((c) => c.id == app.selectedCourse);
    final max = isConduct ? 100 : course!.max;
    final cols = isConduct ? [0, 1, 4, 5] : [0, 1, 2, 3, 4, 5, 6, 7, 8];
    const inputCols = [0, 1, 2, 4, 5, 6];

    return PageBody(children: [
      const PageTitle('Saisie des cotes',
          sub: 'Choisissez un cours puis complétez les points de chaque élève.'),
      Panel(
        title: 'Cours',
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: DropdownButton<String>(
                isExpanded: true,
                value: app.selectedCourse,
                items: [
                  for (final c in active)
                    DropdownMenuItem(value: c.id,
                        child: Text('${c.name}  (max. ${c.max})')),
                  const DropdownMenuItem(value: kConduct,
                      child: Text('Conduite  (max. 100)')),
                ],
                onChanged: (v) {
                  if (v != null) app.selectCourse(v);
                },
              ),
            ),
            if (course != null)
              SettingField(
                key: ValueKey('teacher-${course.id}-${app.revision}'),
                label: 'Titulaire du cours',
                value: course.teacher,
                width: 280,
                onChanged: (v) {
                  course.teacher = v;
                  app.changed();
                },
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (app.students.isEmpty)
        const Panel(
          title: 'Élèves',
          child: Text("Ajoutez d'abord les élèves dans l'onglet Classe."),
        )
      else
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kRule),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder.all(color: kRule),
              columnWidths: <int, TableColumnWidth>{
                0: const FixedColumnWidth(36),
                1: const FixedColumnWidth(210),
                for (var k = 0; k < cols.length; k++)
                  k + 2: const FixedColumnWidth(68),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: kHead),
                  children: [
                    _txt('N°', bold: true),
                    _txt('Noms et post-noms', bold: true, left: true),
                    for (final i in cols) _txt(kColLabels[i], bold: true),
                  ],
                ),
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF0EEE6)),
                  children: [
                    _txt(''),
                    _txt('Maxima', left: true),
                    for (final i in cols)
                      _txt(isConduct ? '100' : '${max * kMult[i]}'),
                  ],
                ),
                for (var n = 0; n < app.students.length; n++)
                  _studentRow(n, app.students[n], cols, inputCols, max),
              ],
            ),
          ),
        ),
    ]);
  }

  TableRow _studentRow(
      int n, Student s, List<int> cols, List<int> inputCols, int max) {
    final row = app.rowOf(app.selectedCourse, s.id);
    return TableRow(children: [
      _txt('${n + 1}'),
      _txt(s.name, left: true),
      for (final i in cols)
        inputCols.contains(i)
            ? Padding(
                padding: const EdgeInsets.all(3),
                child: _MarkCell(
                  key: ValueKey(
                      '${app.selectedCourse}-${s.id}-$i-${app.revision}'),
                  courseId: app.selectedCourse,
                  studentId: s.id,
                  dataIdx: kDataIdx[i],
                  max: app.selectedCourse == kConduct
                      ? 100.0
                      : max * kMult[i].toDouble(),
                ),
              )
            : _txt(fmt(Calc.col(row, i)), bold: true),
    ]);
  }

  Widget _txt(String t, {bool bold = false, bool left = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          t,
          textAlign: left ? TextAlign.left : TextAlign.center,
          style: TextStyle(
              fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        ),
      );
}

class _MarkCell extends StatefulWidget {
  final String courseId;
  final String studentId;
  final int dataIdx;
  final double max;
  const _MarkCell({
    super.key,
    required this.courseId,
    required this.studentId,
    required this.dataIdx,
    required this.max,
  });

  @override
  State<_MarkCell> createState() => _MarkCellState();
}

class _MarkCellState extends State<_MarkCell> {
  late final TextEditingController c;
  bool bad = false;

  @override
  void initState() {
    super.initState();
    // Charger la valeur depuis le cache ou directement de la BDD
    final cachedRow = app.getCachedRow(widget.courseId, widget.studentId);
    final val = cachedRow != null && cachedRow.length > widget.dataIdx
        ? cachedRow[widget.dataIdx]
        : null;
    c = TextEditingController(text: fmt(val));
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _onChanged(String t) {
    if (t.trim().isEmpty) {
      setState(() => bad = false);
      app.setMark(widget.courseId, widget.studentId, widget.dataIdx, null);
      return;
    }
    final v = parseNum(t);
    if (v == null || v < 0 || v > widget.max) {
      setState(() => bad = true);
      return;
    }
    setState(() => bad = false);
    app.setMark(widget.courseId, widget.studentId, widget.dataIdx, v);
  }

  @override
  Widget build(BuildContext context) {
    final red = OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    );
    return SizedBox(
      height: 38,
      child: TextField(
        controller: c,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(2)),
          enabledBorder: bad ? red : null,
          focusedBorder: bad ? red : null,
        ),
        onChanged: _onChanged,
      ),
    );
  }
}
