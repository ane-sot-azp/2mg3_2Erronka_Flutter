import 'package:flutter_test/flutter_test.dart';

import 'package:game_tournament/main.dart';

void main() {
  testWidgets('La app carga la selección de categoría', (WidgetTester tester) async {
    await tester.pumpWidget(const TournamentApp());

    expect(find.text('Campeonato de platos'), findsOneWidget);
    expect(find.text('Elige una categoría'), findsOneWidget);
    expect(find.text('Primeros'), findsOneWidget);
    expect(find.text('Segundos'), findsOneWidget);
    expect(find.text('Postres'), findsOneWidget);
  });
}
