import 'package:flutter/material.dart';

import '../models.dart';
import '../pdf_service.dart';
import '../widgets.dart';
import 'pdf_screen.dart';

class PalmaresScreen extends StatelessWidget {
  const PalmaresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = Calc.palmares(app);
    final success = rows.where((r) => r.obs == 'Réussite').length;
    final fail = rows.where((r) => r.obs == 'Echec').length;

    return PageBody(children: [
      const PageTitle('Palmarès',
          sub: 'Classement de fin d\'année selon le total général.'),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: rows.isEmpty
              ? null
              : () => openPdf(
                    context,
                    'Palmarès - ${app.info.className}',
                    'palmares_${app.info.className}.pdf',
                    () => buildPalmaresPdf(app),
                  ),
          icon: const Icon(Icons.print_outlined),
          label: const Text('Fiche de proclamation (PDF)'),
        ),
      ),
      const SizedBox(height: 14),
      Panel(
        title: 'Statistiques',
        child: Wrap(
          spacing: 28,
          runSpacing: 8,
          children: [
            _stat('Inscrits', app.students.length),
            _stat('Participants', rows.length),
            _stat('Réussites', success),
            _stat('Échecs', fail),
            _stat('Abandons', app.students.length - rows.length),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (rows.isEmpty)
        const Panel(
          title: 'Classement',
          child: Text('Le classement apparaîtra dès que des cotes seront saisies.'),
        )
      else
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kRule),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Place')),
                DataColumn(label: Text('Nom et post-nom')),
                DataColumn(label: Text('Sexe')),
                DataColumn(label: Text('%')),
                DataColumn(label: Text('Appl.')),
                DataColumn(label: Text('Obs.')),
              ],
              rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(Text('${r.place}')),
                    DataCell(Text(r.student.name)),
                    DataCell(Text(r.student.sex)),
                    DataCell(Text(fmt(r.pct))),
                    DataCell(Text(r.appr)),
                    DataCell(Text(r.obs)),
                  ]),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _stat(String label, int v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$v',
              style: kSerif.copyWith(
                  fontSize: 24, fontWeight: FontWeight.bold, color: kNavy)),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      );
}
