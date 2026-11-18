import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
              'Les données sont enregistrées en base SQLite sur cet appareil. '
              'Pour les transférer d\'un appareil à l\'autre, exportez ou importez '
              'un fichier JSON.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await saveBackupFile(context);
                  },
                  icon: const Icon(Icons.save_as_outlined, size: 18),
                  label: const Text('Exporter le fichier'),
                ),
                OutlinedButton.icon(
                  onPressed: () => loadBackupFile(context),
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: const Text('Importer le fichier'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    // Copier aussi vers presse-papiers
                    final data = await app.exportJson();
                    await Clipboard.setData(ClipboardData(text: data));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Données copiées dans le presse-papiers.')));
                    }
                  },
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Copier le backup'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _restoreDialog(context),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Coller & restaurer'),
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

/// Sauvegarder les données dans un fichier JSON sur le stockage externe.
Future<void> saveBackupFile(BuildContext context) async {
  try {
    final dir = await getExternalStorageDirectory();
    final fallbackDir = await getApplicationDocumentsDirectory();
    // Utiliser External si disponible, sinon Documents
    final targetDir = dir ?? fallbackDir;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${targetDir.path}/bulletin_scolaire_backup_$timestamp.json');
    final data = await app.exportJson();
    await file.writeAsString(data);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Fichier enregistré dans ${targetDir.path}'),
        duration: const Duration(seconds: 3),
      ));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur lors de la sauvegarde : $e'),
        backgroundColor: Colors.red,
      ));
    }
  }
}

/// Charger les données depuis un fichier JSON.
Future<void> loadBackupFile(BuildContext context) async {
  try {
    final dir = await getExternalStorageDirectory();
    final fallbackDir = await getApplicationDocumentsDirectory();
    final targetDir = dir ?? fallbackDir;
    final files = await targetDir.list().toList();
    final backupFiles = files
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    backupFiles.sort((a, b) => b.path.compareTo(a.path));

    if (backupFiles.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun fichier de sauvegarde trouvé.')));
      }
      return;
    }

    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choisir une sauvegarde'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView(
            children: [
              for (final f in backupFiles)
                ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(f.path.split('/').last),
                  subtitle: Text(f.statSync().modified.toString().split('.')[0]),
                  onTap: () => Navigator.pop(ctx, f.path),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Annuler')),
        ],
      ),
    );
    if (chosen == null) return;
    final file = File(chosen);
    final content = await file.readAsString();
    await _restoreJson(context, content);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur lecture fichier : $e'),
        backgroundColor: Colors.red,
      ));
    }
  }
}

/// Restaurer depuis un JSON déjà chargé en mémoire.
Future<void> _restoreJson(BuildContext context, String json) async {
  try {
    final valid = jsonDecode(json) as Map<String, dynamic>;
    if (!valid.containsKey('version') && !valid.containsKey('info')) {
      throw FormatException('JSON invalide');
    }
    await app.importJson(json);
    app.changed();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sauvegarde restaurée.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Sauvegarde invalide, rien n'a été modifié."),
        backgroundColor: Colors.red,
      ));
    }
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
        child: SingleChildScrollView(
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
  await _restoreJson(context, c.text.trim());
}

Future<void> _courseDialog(BuildContext context, {Course? course}) async {
  final name = TextEditingController(text: course?.name ?? '');
  final maxText = '${course?.max ?? 20}';
  final maxCtrl = TextEditingController(text: maxText);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(course == null ? 'Nouveau cours' : 'Modifier le cours'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: inputDeco('Intitulé du cours')),
              const SizedBox(height: 10),
              TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    inputDeco('Maxima par période', hint: '10, 20, 40, 50...'),
              ),
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
  );
  final m = int.tryParse(maxCtrl.text.trim());
  if (ok != true || name.text.trim().isEmpty || m == null || m <= 0) return;
  if (course == null) {
    app.addCourse(name.text.trim(), m);
  } else {
    course.name = name.text.trim();
    course.max = m;
    app.changed();
  }
}
