import 'package:flutter_test/flutter_test.dart';

import 'package:fifteen_puzzle_self/main.dart';

void main() {
  testWidgets('15 Puzzle app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FifteenPuzzleApp());

    // Verify that the app title appears.
    expect(find.text('15 Puzzle (IDA* Solver)'), findsOneWidget);
    
    // Verify that shuffle button exists.
    expect(find.text('Shuffle'), findsOneWidget);
  });
}
