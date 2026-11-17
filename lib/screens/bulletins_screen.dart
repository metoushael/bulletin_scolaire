import 'package:flutter/material.dart';

import '../models.dart';
import '../pdf_service.dart';
import '../widgets.dart';
import 'pdf_screen.dart';

class BulletinsScreen extends StatelessWidget {
  const BulletinsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final list = List<Student>.from(app.students);
    return PageBody(children: [
      const PageTitle('Bulletins',
          sub: 'Un bulletin par élève, calculé à partir des cotes saisies.'),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: list.isEmpty
              ? null
              : () => openPdf(
                    context,
                    'Bulletins - ${app.info.className}',
                    'bulletins_${app.info.className}.pdf',
                    () => buildBulletinsPdf(app, list),
                  ),
          icon: const Icon(Icons.print_outlined),
          label: const Text('Tous les bulletins (PDF)'),
        ),
      ),
      const SizedBox(height: 14),
      if (list.isEmpty)
        const Panel(
          title: 'Élèves',
          child: Text("Aucun élève. Ajoutez-les dans l'onglet Classe."),
        ),
      for (var n = 0; n < list.length; n++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _StudentCard(n + 1, list[n]),
        ),
    ]);
  }
}

class _StudentCard extends StatelessWidget {
  final int n;
  final Student s;
  const _StudentCard(this.n, this.s);

  @override
  Widget build(BuildContext context) {
    final has = Calc.hasData(app, s.id, 8);
    final p = Calc.annualPct(app, s.id);
    final summary = has
        ? '${fmt(p)} %  ·  Place ${Calc.place(app, s.id, 8)}'
        : 'Total général : pas encore complet';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kRule),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 30,
                child: Text('$n',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text(s.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 2),
            child: Text(summary, style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: s.decision,
                  items: const [
                    DropdownMenuItem(
                        value: 'auto', child: Text('Décision : automatique')),
                    DropdownMenuItem(value: 'passe', child: Text('Passe')),
                    DropdownMenuItem(value: 'double', child: Text('Double')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      s.decision = v;
                      app.changed();
                    }
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () => openPdf(
                    context,
                    s.name,
                    'bulletin_${s.name}.pdf',
                    () => buildBulletinsPdf(app, [s]),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Aperçu / Imprimer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
