import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models.dart';
import 'screens/bulletins_screen.dart';
import 'screens/class_screen.dart';
import 'screens/marks_screen.dart';
import 'screens/palmares_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const BulletinApp());
}

class BulletinApp extends StatelessWidget {
  const BulletinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bulletin Scolaire',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kNavy,
          primary: kNavy,
        ).copyWith(surface: kPaper),
        scaffoldBackgroundColor: kPaper,
        appBarTheme: const AppBarTheme(
          backgroundColor: kNavy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
        ),
      ),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  static const _labels = ['Classe', 'Cotes', 'Bulletins', 'Palmarès', 'Réglages'];
  static const _icons = [
    Icons.groups_outlined,
    Icons.edit_note_outlined,
    Icons.description_outlined,
    Icons.format_list_numbered,
    Icons.settings_outlined,
  ];
  static const _iconsOn = [
    Icons.groups,
    Icons.edit_note,
    Icons.description,
    Icons.format_list_numbered,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final wide = MediaQuery.of(context).size.width >= 840;
        const pages = <Widget>[
          ClassScreen(),
          MarksScreen(),
          BulletinsScreen(),
          PalmaresScreen(),
          SettingsScreen(),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.info.school,
                  style: kSerif.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Année scolaire ${app.info.year}  ·  ${app.info.className}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: index,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (i) => setState(() => index = i),
                      destinations: [
                        for (var i = 0; i < _labels.length; i++)
                          NavigationRailDestination(
                            icon: Icon(_icons[i]),
                            selectedIcon: Icon(_iconsOn[i]),
                            label: Text(_labels[i]),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: pages[index]),
                  ],
                )
              : pages[index],
          bottomNavigationBar:
              wide ? null : _buildBottomNav(),
        );
      },
    );
  }

  BottomNavigationBar _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: index,
      onTap: (i) => setState(() => index = i),
      type: BottomNavigationBarType.fixed,
      items: [
        for (var i = 0; i < _labels.length; i++)
          BottomNavigationBarItem(
            icon: Icon(_icons[i]),
            activeIcon: Icon(_iconsOn[i]),
            label: _labels[i],
          ),
      ],
    );
  }
}
