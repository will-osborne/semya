import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:semya/domain/entities/conversation.dart';
import 'package:semya/providers/conversation_provider.dart';
import 'package:semya/ui/screens/home/home_screen.dart';

void main() {
  testWidgets('home screen shows the empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationsProvider.overrideWith(
            (ref) => Stream.value(const <Conversation>[]),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('No conversations yet'), findsOneWidget);
    expect(find.text('Start a Conversation'), findsOneWidget);
  });
}
