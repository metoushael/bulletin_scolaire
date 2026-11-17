import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets.dart';

class ClassScreen extends StatelessWidget {
  const ClassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final i = app.info;
    final r = app.revision;

    Widget f(String label, String value, void Function(String) set,
        {double w = 260}) {
      return SettingField(
        key: ValueKey('$label-$r'),
        label: label,
        value: value,
        width: w,
        onChanged: (v) {
          set(v);
          app.changed();
        },
      );
    }

    return PageBody(children: [
      const PageTitle('Classe et élèves',
          sub: 'Renseignements repris sur chaque bulletin.'),
      Panel(
        title: 'Renseignements généraux',
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            f('École', i.school, (v) => i.school = v),
            f('Code', i.code, (v) => i.code = v, w: 160),
            f('Province', i.province, (v) => i.province = v),
            f('Ville', i.city, (v) => i.city = v),
            f('Commune / Territoire', i.commune, (v) => i.commune = v),
            f('Année scolaire', i.year, (v) => i.year = v, w: 160),
            f('Classe', i.className, (v) => i.className = v, w: 160),
            f('Titulaire de la classe', i.teacher, (v) => i.teacher = v),
            f('Intitulé sur le bulletin', i.title, (v) => i.title = v, w: 420),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Panel(
        title: 'Liste des élèves (${app.students.length})',
        action: Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => showBulkDialog(context),
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text('Ajouter une liste'),
            ),
            FilledButton.icon(
              onPressed: () => showStudentDialog(context),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        child: app.students.isEmpty
            ? const Text(
                'Aucun élève pour le moment. Ajoutez-les un par un ou collez toute la liste de la classe.')
            : Column(
                children: [
                  for (var n = 0; n < app.students.length; n++)
                    _StudentRow(n + 1, app.students[n]),
                ],
              ),
      ),
    ]);
  }
}

class _StudentRow extends StatelessWidget {
  final int n;
  final Student s;
  const _StudentRow(this.n, this.s);

  @override
  Widget build(BuildContext context) {
    final details = [
      if (s.sex.isNotEmpty) s.sex,
      if (s.birthPlace.isNotEmpty) s.birthPlace,
      if (s.birthDate.isNotEmpty) s.birthDate,
      if (s.permNo.isNotEmpty) 'N° perm. ${s.permNo}',
    ].join('  ·  ');
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kRule)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: SizedBox(
          width: 30,
          child: Text('$n', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: details.isEmpty ? null : Text(details),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showStudentDialog(context, student: s),
            ),
            IconButton(
              tooltip: 'Supprimer',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  'Supprimer cet élève ?',
                  'Les cotes de ${s.name} seront aussi supprimées.',
                  ok: 'Supprimer',
                );
                if (ok) app.removeStudent(s);
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showStudentDialog(BuildContext context, {Student? student}) async {
  final name = TextEditingController(text: student?.name ?? '');
  final place = TextEditingController(text: student?.birthPlace ?? '');
  final date = TextEditingController(text: student?.birthDate ?? '');
  final perm = TextEditingController(text: student?.permNo ?? '');
  final idNo = TextEditingController(text: student?.idNo ?? '');
  var sex = student?.sex ?? '';

  Widget gap() => const SizedBox(height: 10);

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(student == null ? 'Nouvel élève' : "Modifier l'élève"),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  textCapitalization: TextCapitalization.characters,
                  decoration: inputDeco('Noms et post-noms'),
                ),
                gap(),
                SegmentedButton<String>(
                  emptySelectionAllowed: true,
                  segments: const [
                    ButtonSegment(value: 'M', label: Text('Masculin')),
                    ButtonSegment(value: 'F', label: Text('Féminin')),
                  ],
                  selected: sex.isEmpty ? <String>{} : {sex},
                  onSelectionChanged: (s) =>
                      setS(() => sex = s.isEmpty ? '' : s.first),
                ),
                gap(),
                TextField(
                    controller: place, decoration: inputDeco('Lieu de naissance')),
                gap(),
                TextField(
                    controller: date,
                    decoration: inputDeco('Date de naissance', hint: 'JJ/MM/AAAA')),
                gap(),
                TextField(controller: perm, decoration: inputDeco('N° permanent')),
                gap(),
                TextField(
                    controller: idNo, decoration: inputDeco('N° d\'identification')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer')),
        ],
      ),
    ),
  );

  if (ok == true && name.text.trim().isNotEmpty) {
    if (student == null) {
      app.addStudent(Student(
        id: app.newId(),
        name: name.text.trim(),
        sex: sex,
        birthPlace: place.text.trim(),
        birthDate: date.text.trim(),
        permNo: perm.text.trim(),
        idNo: idNo.text.trim(),
      ));
    } else {
      student.name = name.text.trim();
      student.sex = sex;
      student.birthPlace = place.text.trim();
      student.birthDate = date.text.trim();
      student.permNo = perm.text.trim();
      student.idNo = idNo.text.trim();
      app.sortStudents();
      app.changed();
    }
  }
}

Future<void> showBulkDialog(BuildContext context) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ajouter une liste d\'élèves'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Un élève par ligne : NOM ET POST-NOM ; SEXE (M ou F). Le sexe est facultatif.'),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              maxLines: 10,
              minLines: 6,
              decoration: inputDeco('Liste', hint: 'AISHA RADJABU;F'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ajouter')),
      ],
    ),
  );
  if (ok != true) return;
  for (final line in c.text.split('\n')) {
    final t = line.trim();
    if (t.isEmpty) continue;
    final parts = t.split(RegExp(r'[;,\t]'));
    final name = parts.first.trim();
    if (name.isEmpty) continue;
    var sex = '';
    if (parts.length > 1) {
      final x = parts[1].trim().toUpperCase();
      if (x == 'M' || x == 'F') sex = x;
    }
    app.students.add(Student(id: app.newId(), name: name.toUpperCase(), sex: sex));
  }
  app.sortStudents();
  app.changed();
}
