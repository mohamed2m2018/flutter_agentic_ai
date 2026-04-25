# mobileai_flutter

Flutter SDK for MobileAI Cloud by Twomilia.

MobileAI Cloud is the product, Twomilia is the company, and `https://mobileai.cloud` is the canonical product domain.

`mobileai_flutter` adds a UI-aware agent to a Flutter app with:

- floating chat UI
- widget-tree-first screen understanding
- built-in UI tools like tap, type, scroll, long press, slider, picker, date, and guidance overlays
- rich chat blocks and `AIZone` screen interventions
- app-registered actions with `AIAction`
- app-registered live data sources with `AIData`
- navigation adapters for `go_router` and `Navigator`
- consent gating, telemetry, conversation persistence, voice mode, and support mode

This package is the standalone Flutter SDK in `mobileai-flutter/`. It is separate from the React Native and web packages.

## Install

From pub.dev:

```yaml
dependencies:
  mobileai_flutter: ^0.2.3
```

For local development in this monorepo:

```yaml
dependencies:
  mobileai_flutter:
    path: ../mobileai-flutter
```

Import:

```dart
import 'package:mobileai_flutter/mobileai_flutter.dart';
```

## Quick Start

Wrap the top-level app widget that owns navigation.

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/billing', builder: (_, __) => const BillingScreen()),
  ],
);

const apiKey = String.fromEnvironment('GEMINI_API_KEY');

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return AIAgent(
      apiKey: apiKey,
      router: router,
      instructions: 'You are a helpful assistant for this app.',
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }
}
```

Run with:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

For production, prefer `proxyUrl` instead of shipping raw provider keys in the app.

## What `AIAgent` Supports Today

The main widget in [lib/src/widgets/ai_agent.dart](/Users/mohamedsalah/mobileai-suite-copy/mobileai-flutter/lib/src/widgets/ai_agent.dart) currently exposes:

- provider configuration: `apiKey`, `provider`, `proxyUrl`, `proxyHeaders`, `model`
- navigation integration: `router`, `routerAdapter`, `navigatorKey`, `screenMap`
- runtime behavior: `maxSteps`, `instructions`, `language`, `interactionMode`, `enableUiControl`
- UI customization: `theme`, `richUiTheme`, `accentColor`, `showChatBar`
- lifecycle hooks: `onResult`, `onBeforeStep`, `onAfterStep`, `onStatusUpdate`
- consent and persistence: `consent`, `conversationPersistenceKey`
- telemetry: `telemetry`
- support and voice: `supportMode`, `enableVoice`, `voiceProxyUrl`, `voiceProxyHeaders`
- screen filtering and transforms: `interactiveBlacklist`, `interactiveWhitelist`, `transformScreenContent`
- block actions: `blockActionHandlers`

## Navigation Support

### `go_router`

```dart
AIAgent(
  apiKey: apiKey,
  router: router,
  child: MaterialApp.router(routerConfig: router),
)
```

`AIAgent` builds the `GoRouterAdapter` internally from `router`. Pass
`routerAdapter` only when you need to override route catalog or navigation
behavior.

### Flutter `Navigator`

```dart
final navigatorKey = GlobalKey<NavigatorState>();

AIAgent(
  apiKey: apiKey,
  navigatorKey: navigatorKey,
  routerAdapter: NavigatorRouterAdapter(
    navigatorKey: navigatorKey,
    availableScreens: const ['/', '/billing', '/settings'],
  ),
  child: MaterialApp(
    navigatorKey: navigatorKey,
    routes: {
      '/': (_) => const HomeScreen(),
      '/billing': (_) => const BillingScreen(),
      '/settings': (_) => const SettingsScreen(),
    },
  ),
)
```

Navigation rule: direct agent navigation should only be used for safe top-level destinations. Detail screens that require an item id or prior selection should still be reached by tapping through the UI.

`screenMap` is a generated hint layer. It can add titles, descriptions, and
route-chain hints to the prompt, but the live router/adapter remains the source
of truth for current screen and available routes.

## Built-In Agent Tools

The runtime currently registers these built-in tools:

| Tool | Purpose |
|------|---------|
| `tap` | Tap an interactive element |
| `type` | Enter text into an input |
| `scroll` | Scroll content |
| `long_press` | Long-press elements |
| `adjust_slider` | Set slider values |
| `select_picker` | Select picker/dropdown values |
| `set_date` | Set date values |
| `guide_user` | Show visual highlight guidance |
| `navigate` | Navigate to safe top-level screens |
| `wait` | Pause for loading/transitions |
| `done` | Finish the task with a user-facing reply |
| `ask_user` | Request clarification, approval, or freeform user input |
| `query_data` | Query app-registered live data sources |
| `query_knowledge` | Query the knowledge layer when configured internally |
| `simplify_zone` | Reduce clutter in an `AIZone` |
| `restore_zone` | Restore a simplified/injected `AIZone` |
| `render_block` | Render a registered block into an `AIZone` |
| `inject_card` | Deprecated alias for `render_block` |

Tool availability can change if you disable UI control, omit data sources, or use support/knowledge-specific runtime paths.

## Custom Actions

Use `AIAction` to expose app-side functions the agent can call directly.

```dart
AIAction(
  action: ActionDefinition(
    name: 'open_support_chat',
    description: 'Open the in-app support chat drawer.',
    parameters: const {},
    handler: (_) async {
      debugPrint('Opening support chat');
      return {'ok': true};
    },
  ),
  child: const HomeScreen(),
)
```

## App Data

Use `AIData` to register live app-owned data sources the agent can query with `query_data`.

```dart
AIData(
  definition: DataDefinition(
    name: 'catalog_context',
    description: 'Returns the featured products shown in the catalog.',
    handler: (context) async {
      return {
        'screen': context.screenName,
        'featured': [
          {'name': 'Starter Plan', 'price': '\$29'},
          {'name': 'Growth Plan', 'price': '\$99'},
        ],
      };
    },
  ),
  child: const CatalogScreen(),
)
```

`AIData` is the main public path for structured live app data in `0.2.3`.

## Rich Chat UI

Assistant replies can include structured rich content, not just plain strings.

Built-in blocks registered by default:

- `FactCard`
- `ProductCard`
- `ActionCard`
- `ComparisonCard`
- `FormCard`

Use `RichContentRenderer` in custom surfaces, or let the built-in chat UI render them automatically.

## `AIZone` / Contextual UI

Use `AIZone` to define local surfaces where the agent may simplify content, guide the user, or render a block.

```dart
AIZone(
  id: 'pricing-summary',
  allowSimplify: true,
  allowInjectBlock: true,
  interventionEligible: true,
  proactiveIntervention: false,
  child: const PricingTable(),
)
```

You can also allow custom blocks per zone:

```dart
AIZone(
  id: 'checkout-help',
  allowInjectBlock: true,
  blocks: [
    BlockDefinition(
      name: 'CheckoutHint',
      allowedPlacements: const [BlockPlacement.zone],
      builder: (context, props) => Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFFE8F0FE),
        child: Text('${props['text'] ?? ''}'),
      ),
    ),
  ],
  child: const CheckoutScreen(),
)
```

## Access the Controller From the Tree

```dart
final agent = context.ai;

ElevatedButton(
  onPressed: () => agent.send('Go to billing and explain the current plan'),
  child: const Text('Ask AI'),
)
```

The controller exposes:

- `send(...)`
- `cancel()`
- `clearMessages()`
- `startNewConversation()`
- `isRunning`
- `isAwaitingUserResponse`
- `status`
- `messages`
- `lastResult`

## Consent

Use `AIConsentConfig` to require explicit user opt-in before the assistant can operate.

```dart
AIAgent(
  apiKey: apiKey,
  consent: const AIConsentConfig(
    required: true,
    persist: true,
    title: 'AI Assistant',
    providerLabel: 'Google Gemini',
  ),
  child: MaterialApp.router(routerConfig: router),
)
```

## Telemetry

Use `TelemetryConfig` to enable MobileAI Cloud analytics.

```dart
AIAgent(
  apiKey: apiKey,
  telemetry: const TelemetryConfig(
    enabled: true,
    analyticsKey: 'your_analytics_key',
    baseUrl: 'https://your-backend.example.com',
  ),
  child: MaterialApp.router(routerConfig: router),
)
```

The package also exports the `MobileAI` static telemetry helpers.

## Conversation Persistence

Use `conversationPersistenceKey` to persist and restore conversations across launches.

```dart
AIAgent(
  apiKey: apiKey,
  conversationPersistenceKey: 'main-assistant',
  child: MaterialApp.router(routerConfig: router),
)
```

## Voice and Support Mode

Voice and support mode are available from the public widget surface.

```dart
AIAgent(
  apiKey: apiKey,
  enableVoice: true,
  supportMode: const SupportModeConfig(
    enabled: true,
    supportStyle: 'warm-concise',
    greetingMessage: 'Hi there! How can I help?',
  ),
  child: MaterialApp.router(routerConfig: router),
)
```

`SupportModeConfig` also supports:

- `quickReplies`
- `escalation`
- `csat`
- `businessHours`
- `onRestoreTicket`
- `onRestoreTranscript`
- `onSendHumanMessage`
- `socketUrlBuilder`

## Theming

Two theme layers are available:

- `theme` for the chat shell
- `richUiTheme` for rich chat blocks and `AIZone` surfaces

```dart
AIAgent(
  apiKey: apiKey,
  theme: const AgentChatBarTheme(
    primaryColor: Color(0xFF7B68EE),
  ),
  richUiTheme: RichUiTheme.defaults(),
  child: MaterialApp.router(routerConfig: router),
)
```

## Provider Setup

The package includes:

- `GeminiProvider`
- `OpenAIProvider`
- `createProvider(...)`

Default provider selection in `AIAgent` is:

- Gemini by default
- OpenAI if `model` contains `gpt`
- or an explicit custom `provider`

Example:

```dart
AIAgent(
  provider: OpenAIProvider(
    apiKey: const String.fromEnvironment('OPENAI_API_KEY'),
    modelName: 'gpt-4.1-mini',
  ),
  child: MaterialApp.router(routerConfig: router),
)
```

## Security Notes

- Prefer `proxyUrl` for production traffic instead of shipping raw provider keys in the app.
- Use `interactiveBlacklist`, `interactiveWhitelist`, and `transformScreenContent` to protect sensitive UI.
- Set `enableUiControl: false` for knowledge-only mode.
- Set `showChatBar: false` if you want a custom trigger/UI around the runtime.

## Current Scope

`mobileai_flutter 0.2.3` now includes the core runtime, navigation adapters, live data registration, rich chat blocks, zones, consent, telemetry, support scaffolding, and voice mode surface.

See [doc/parity-matrix.md](doc/parity-matrix.md) for the subsystem-by-subsystem parity snapshot.

## Example App

The local example app in `/example` demonstrates:

- `go_router` integration
- floating AI shell
- route-aware navigation
- rich replies
- registered app data sources
- shopping-style UI traversal

## License

MIT
