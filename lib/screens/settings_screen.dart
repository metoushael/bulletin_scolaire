import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageBody(children: [
      const PageTitle('Réglages',
          sub: 'Cours de la classe et sauvegarde des données.'),
      Panel(
        title: 'Cours de la classe',
        action: FilledButton.icon(
          onPressed: () => _courseDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ajouter un cours'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Un cours désactivé n'apparaît ni dans la saisie, ni dans le bulletin, "
              "ni dans le maxima général. Les cours sont regroupés par maxima sur le bulletin.",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            for (final c in app.courses)
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: kRule)),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Switch(
                    value: c.active,
                    onChanged: (v) {
                      c.active = v;
                      app.changed();
                    },
                  ),
                  title: Text(c.name),
                  subtitle: Text('Maxima par période : ${c.max}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Modifier',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _courseDialog(context, course: c),
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await confirmDialog(
                            context,
                            'Supprimer ce cours ?',
                            'Toutes les cotes de « ${c.name} » seront supprimées.',
                            ok: 'Supprimer',
                          );
                          if (ok) app.removeCourse(c);
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Panel(
        title: 'Sauvegarde',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Les données sont enregistrées sur cet appareil. Pour les transférer '
              "d'un appareil à un autre, copiez la sauvegarde puis collez-la dans "
              "l'autre appareil avec « Restaurer ».",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: app.exportJson()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Sauvegarde copiée dans le presse-papiers.')));
                    }
                  },
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copier la sauvegarde'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _restoreDialog(context),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Restaurer'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      'Effacer toutes les cotes ?',
                      'Les élèves et les cours sont conservés, seules les cotes sont supprimées (nouvelle année).',
                      ok: 'Effacer',
                    );
                    if (ok) app.clearMarks();
                  },
                  icon: const Icon(Icons.layers_clear_outlined, size: 18),
                  label: const Text('Effacer les cotes'),
                ),
              ],
            ),
          ],
        ),
      ),
    ]);
  }
}

Future<void> _courseDialog(BuildContext context, {Course? course}) async {
  final name = TextEditingController(text: course?.name ?? '');
  final max = TextEditingController(text: '${course?.max ?? 20}');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(course == null ? 'Nouveau cours' : 'Modifier le cours'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: inputDeco('Intitulé du cours')),
            const SizedBox(height: 10),
            TextField(
              controller: max,
              keyboardType: TextInputType.number,
              decoration: inputDeco('Maxima par période', hint: '10, 20, 40, 50...'),
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
            child: const Text('Enregistrer')),
      ],
    ),
  );
  final m = int.tryParse(max.text.trim());
  if (ok != true || name.text.trim().isEmpty || m == null || m <= 0) return;
  if (course == null) {
    app.addCourse(name.text.trim(), m);
  } else {
    course.name = name.text.trim();
    course.max = m;
    app.changed();
  }
}

Future<void> _restoreDialog(BuildContext context) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Restaurer une sauvegarde'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attention : les données actuelles seront remplacées.'),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              maxLines: 8,
              minLines: 4,
              decoration: inputDeco('Collez la sauvegarde ici'),
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
            child: const Text('Restaurer')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    app.importJson(c.text.trim());
    app.changed();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sauvegarde restaurée.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sauvegarde invalide, rien n\'a été modifié.')));
    }
  }
}
