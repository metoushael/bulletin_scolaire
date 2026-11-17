import 'package:flutter/material.dart';

const Color kNavy = Color(0xFF1B365D);
const Color kPaper = Color(0xFFF4F2EC);
const Color kRule = Color(0xFFCFC9BA);
const Color kHead = Color(0xFFE6E2D6);

const TextStyle kSerif = TextStyle(
  fontFamily: 'Georgia',
  fontFamilyFallback: ['Times New Roman', 'serif'],
);

InputDecoration inputDeco(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(2)),
    );

/// Zone centrale limitee en largeur, defilable.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: children,
        ),
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  final String text;
  final String? sub;
  const PageTitle(this.text, {super.key, this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: kSerif.copyWith(
                fontSize: 24, fontWeight: FontWeight.bold, color: kNavy),
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(sub!, style: const TextStyle(color: Colors.black54)),
            ),
          const SizedBox(height: 8),
          Container(height: 2, color: kNavy),
        ],
      ),
    );
  }
}

/// Bloc encadre avec titre, a la maniere d'une rubrique de formulaire.
class Panel extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const Panel({super.key, required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kRule),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: kHead,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        letterSpacing: 0.8,
                        color: kNavy),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

/// Champ de texte qui garde son propre controleur.
class SettingField extends StatefulWidget {
  final String label;
  final String value;
  final double width;
  final ValueChanged<String> onChanged;
  const SettingField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.width = 260,
  });

  @override
  State<SettingField> createState() => _SettingFieldState();
}

class _SettingFieldState extends State<SettingField> {
  late final TextEditingController c = TextEditingController(text: widget.value);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: c,
        decoration: inputDeco(widget.label),
        onChanged: widget.onChanged,
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String ok = 'Confirmer'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}
