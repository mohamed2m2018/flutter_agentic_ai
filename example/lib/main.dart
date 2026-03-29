import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_agentic_ai/flutter_agentic_ai.dart';
import 'router.dart';

void main() {
  runApp(const ProviderScope(child: ShopFlowApp()));
}

class ShopFlowApp extends StatelessWidget {
  const ShopFlowApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Read API key from flutter run --dart-define=GEMINI_API_KEY=...
    const apiKey = String.fromEnvironment('GEMINI_API_KEY');

    return AiAgent(
      apiKey: apiKey,
      router: router,
      maxSteps: 15,
      language: 'en',
      instructions: 'You are a helpful assistant for ShopFlow, an e-commerce app.',
      accentColor: Colors.deepPurple,
      onResult: (result) {
        debugPrint('[ShopFlow] Agent result: ${result.message}');
      },
      child: MaterialApp.router(
        title: 'ShopFlow',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        routerConfig: router,
      ),
    );
  }
}
