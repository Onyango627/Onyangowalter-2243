import 'package:flutter_test/flutter_test.dart';
import 'package:pos_retail_app/main.dart';
import 'package:pos_retail_app/services/app_state.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows the POS welcome screen', (WidgetTester tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const PosApp(),
      ),
    );

    expect(find.text('POS Retail Pro'), findsOneWidget);
    expect(find.text('Run your store\nwith confidence'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
