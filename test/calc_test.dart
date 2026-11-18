import 'package:flutter_test/flutter_test.dart';

// Import les fonctions et classes nécessaires depuis models.dart
// Pour tester sans SQLite, on isole la logique pure de Calc.

void main() {
  // ── Helpers isolés (copie fidèle de la logique Calc) ───────
  const List<int> kMult = [1, 1, 2, 4, 1, 1, 2, 4, 8];

  double? col(List<double?> r, int i) {
    switch (i) {
      case 0: return r[0];
      case 1: return r[1];
      case 2: return r[2];
      case 3:
        if (r[0] == null || r[1] == null || r[2] == null) return null;
        return r[0]! + r[1]! + r[2]!;
      case 4: return r[3];
      case 5: return r[4];
      case 6: return r[5];
      case 7:
        if (r[3] == null || r[4] == null || r[5] == null) return null;
        return r[3]! + r[4]! + r[5]!;
      default:
        final a = col(r, 3);
        final b = col(r, 7);
        if (a == null || b == null) return null;
        return a + b;
    }
  }

  double pct(double tot, double max) {
    if (max <= 0) return 0;
    return (tot * 100 / max * 10 + 1e-9).floorToDouble() / 10;
  }

  String appr(double p) {
    if (p <= 0) return '';
    if (p < 50) return 'M';
    if (p < 55) return 'AB';
    if (p < 70) return 'B';
    if (p < 80) return 'TB';
    return 'E';
  }

  String fmt(double? v, {int dec = 1}) {
    if (v == null) return '';
    var s = v.toStringAsFixed(dec);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s.replaceAll('.', ',');
  }

  // ── Tests ──────────────────────────────────────────────────

  group('col() — calcul d\'une colonne', () {
    test('renvoie la valeur brute pour P1 (i=0)', () {
      expect(col([15.0, null, null, null, null, null], 0), 15.0);
    });

    test('renvoie la somme P1+P2+Exa pour Total S1 (i=3)', () {
      final row = [10.0, 12.0, 8.0, null, null, null];
      expect(col(row, 3), 30.0);
    });

    test('renvoie null si une valeur est manquante pour Total S1', () {
      final row = [10.0, null, 8.0, null, null, null];
      expect(col(row, 3), isNull);
    });

    test('renvoie la somme P3+P4+Exa pour Total S2 (i=7)', () {
      final row = [null, null, null, 14.0, 16.0, 20.0];
      expect(col(row, 7), 50.0);
    });

    test('Total général (i=8) = Total S1 + Total S2', () {
      final row = [10.0, 12.0, 8.0, 14.0, 16.0, 20.0];
      expect(col(row, 8), equals(col(row, 3) + col(row, 7)));
      expect(col(row, 8), 100.0);
    });

    test('renvoie null si manque des données pour Total général', () {
      // Pas assez de data pour Total S2
      final row = [10.0, 12.0, 8.0, null, null, null];
      expect(col(row, 8), isNull);
    });
  });

  group('pct() — pourcentage tronqué', () {
    test('calcul un pourcentage exact', () {
      expect(pct(50.0, 100.0), 50.0);
    });

    test('tronque à une décimale vers le bas', () {
      // Exemple : 19/40 = 47.5%
      expect(pct(19.0, 40.0), 47.5);
    });

    test('tronque un résultat avec plusieurs décimales', () {
      // 7/20 = 35.0%, mais prenons un cas non rond
      // 13/40 = 32.5%
      expect(pct(13.0, 40.0), 32.5);
      // 11/40 = 27.5%
      expect(pct(11.0, 40.0), 27.5);
    });

    test('retourne 0 si le maximum est nul', () {
      expect(pct(0.0, 0.0), 0);
    });

    test('retourne 0 si total est nul', () {
      expect(pct(0.0, 50.0), 0);
    });

    test('gère les valeurs maximales', () {
      expect(pct(100.0, 100.0), 100.0);
      expect(pct(50.0, 50.0), 100.0);
    });
  });

  group('appr() — appréciation', () {
    test('note >= 80 -> E (Excellent)', () {
      expect(appr(80.0), 'E');
      expect(appr(100.0), 'E');
      expect(appr(95.5), 'E');
    });

    test('note >= 70 et < 80 -> TB (Très Bien)', () {
      expect(appr(70.0), 'TB');
      expect(appr(79.9), 'TB');
    });

    test('note >= 55 et < 70 -> B (Bien)', () {
      expect(appr(55.0), 'B');
      expect(appr(69.9), 'B');
    });

    test('note >= 50 et < 55 -> AB (Assez Bien)', () {
      expect(appr(50.0), 'AB');
      expect(appr(54.9), 'AB');
    });

    test('note < 50 -> M (Médiocre)', () {
      expect(appr(0.1), 'M');
      expect(appr(49.9), 'M');
      expect(appr(30.0), 'M');
    });

    test('note <= 0 -> chaîne vide', () {
      expect(appr(0), '');
      expect(appr(-1), '');
    });
  });

  group('fmt() — formatage de nombre', () {
    test('formate avec virgule comme séparateur', () {
      expect(fmt(15.5), '15,5');
    });

    test('supprime les zéros inutiles', () {
      expect(fmt(15.0), '15');
      expect(fmt(10.00), '10');
    });

    test('gère null', () {
      expect(fmt(null), '');
    });

    test('conserve la précision demandée', () {
      expect(fmt(12.345, dec: 2), '12,34');
    });
  });

  group('Colonne maxima générés (kMult)', () {
    test('les multiplicateurs sont corrects', () {
      expect(kMult.length, 9);
      expect(kMult, [1, 1, 2, 4, 1, 1, 2, 4, 8]);
    });

    test('le Total S1 a un multiplicateur de 4 (somme de 1+1+2)', () {
      expect(kMult[3], 4);
    });

    test('le Total général a un multiplicateur de 8 (somme de 4+4)', () {
      expect(kMult[8], 8);
    });
  });

  group('Scénarios intégrés complets', () {
    test('bulletin complet avec tous les examens', () {
      // Simule un élève avec toutes les notes sur 20 par période
      final row = [12.0, 14.0, 10.0, 13.0, 15.0, 11.0];

      // Vérifier chaque colonne
      expect(col(row, 0), 12.0);   // P1
      expect(col(row, 1), 14.0);   // P2
      expect(col(row, 2), 10.0);   // Exa
      expect(col(row, 3), 36.0);   // Total S1
      expect(col(row, 4), 13.0);   // P3
      expect(col(row, 5), 15.0);   // P4
      expect(col(row, 6), 11.0);   // Exa
      expect(col(row, 7), 39.0);   // Total S2
      expect(col(row, 8), 75.0);   // Total général

      // Calculer le pourcentage
      final pctVal = pct(75.0, 150.0); // suppose 150 comme maxima généré
      expect(pctVal, 50.0);

      // Appréciation correspondante
      expect(appr(pctVal), 'AB');
    });

    test('scénario partiel — quelques notes seulement', () {
      final row = [15.0, 16.0, null, null, null, null];

      expect(col(row, 0), 15.0);
      expect(col(row, 1), 16.0);
      expect(col(row, 2), null);       // Exam pas saisi
      expect(col(row, 3), null);       // Total S1 = null car Exam manquant
      expect(col(row, 8), null);       // Total général = null
    });

    test('scénario extrême — tous les zéros', () {
      final row = List<double?>.filled(6, 0.0);
      expect(col(row, 0), 0.0);
      expect(col(row, 3), 0.0);        // 0+0+0
      expect(col(row, 8), 0.0);        // 0+0
      expect(appr(pct(0.0, 100.0)), 'M');
    });

    test('cas limite — note maximale à chaque examen', () {
      final row = [20.0, 20.0, 20.0, 20.0, 20.0, 20.0];
      expect(col(row, 3), 60.0);       // P1+P2+Exa
      expect(col(row, 7), 60.0);       // P3+P4+Exa
      expect(col(row, 8), 120.0);      // Total général
      expect(pct(120.0, 240.0), 50.0); // Sur une max possible de 240
    });
  });
}
