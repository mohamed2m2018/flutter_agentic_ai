# flutter_agentic_ai

> Embed intelligent AI agents into any Flutter app — with a single widget.

[![pub version](https://img.shields.io/pub/v/flutter_agentic_ai.svg)](https://pub.dev/packages/flutter_agentic_ai)
[![GitHub Repository](https://img.shields.io/badge/GitHub-Repository-blue?logo=github)](https://github.com/mohamed2m2018/flutter_agentic_ai)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`flutter_agentic_ai` lets users talk to your app in plain language and get things done. The agent navigates, taps, fills forms, and completes multi-step tasks — without you writing any automation code. Works out of the box on any production app with zero widget instrumentation.

---

## ✨ Features

- 🤖 **Natural language tasks** — users describe what they want, the agent does it
- 🗺️ **Autonomous navigation** — seamlessly routes through your app (currently requires `go_router`)
- 💬 **Floating chat bar** — draggable FAB + expandable panel, ready out of the box
- 🔄 **Live thinking indicator** — status overlay with cancel support
- 🛡️ **Security guardrails** — blacklist elements, mask PII, or disable UI control entirely
- 🌍 **RTL / Arabic support** — full right-to-left layout built in
- ⚡ **Zero setup** — no native code, no permissions, just wrap your `MaterialApp`
- 🔌 **Gemini powered** — built-in Gemini provider with proxy URL support for production

---

## 🚀 Quick Start

> [!IMPORTANT]
> **Navigation Requirement**: The autonomous navigation engine currently **requires `go_router`**. If your app uses standard `Navigator` or another routing package, the agent can still tap, type, and scroll, but it will not be able to autonomously route between screens.

### 1. Install

```yaml
dependencies:
  flutter_agentic_ai: ^0.1.0
```

### 2. Wrap your app

```dart
import 'package:flutter_agentic_ai/flutter_agentic_ai.dart';

// Pass your API key via --dart-define (never hardcode it)
const apiKey = String.fromEnvironment('GEMINI_API_KEY');

return AiAgent(
  apiKey: apiKey,
  router: router,           // your GoRouter instance
  instructions: 'You are a helpful assistant for MyApp.',
  accentColor: Colors.deepPurple,
  onResult: (result) => debugPrint(result.message),
  child: MaterialApp.router(
    routerConfig: router,
    title: 'MyApp',
  ),
);
```

Run with:
```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

---

## 📖 `AiAgent` Props

### Provider

| Prop | Type | Description |
|------|------|-------------|
| `apiKey` | `String?` | Gemini API key. **Dev/prototyping only** — use `proxyUrl` in production. |
| `provider` | `AiProvider?` | Pre-configured provider instance (takes precedence over `apiKey`). |
| `proxyUrl` | `String?` | Your backend proxy URL — keeps API keys off the device. |
| `proxyHeaders` | `Map<String, String>?` | Auth headers to send with proxy requests. |
| `model` | `String?` | Override the Gemini model (default: `gemini-2.5-flash`). |

### Behavior

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `maxSteps` | `int` | `15` | Maximum agent steps per task. |
| `instructions` | `String?` | — | System-level instructions for every interaction. |
| `router` | `dynamic` | — | `go_router` instance for deep navigation (currently the only supported router). |
| `language` | `String` | `'en'` | `'en'` or `'ar'` — controls locale and RTL layout. |
| `maxTokenBudget` | `int?` | — | Auto-stop when token budget is exceeded. |
| `maxCostUsd` | `double?` | — | Auto-stop when estimated cost exceeds this value. |
| `debug` | `bool` | `false` | Enable verbose debug logging. |

### Lifecycle Callbacks

| Prop | Type | Description |
|------|------|-------------|
| `onResult` | `(ExecutionResult) → void` | Called when the agent finishes a task. |
| `onBeforeStep` | `(int stepCount) → Future<void>` | Called before each agent step. |
| `onAfterStep` | `(List<AgentStep>) → Future<void>` | Called after each step. |
| `onStatusUpdate` | `(String) → void` | Live status text for custom UI integration. |

### Security

| Prop | Type | Description |
|------|------|-------------|
| `interactiveBlacklist` | `List<GlobalKey>?` | Elements the AI must **not** interact with. |
| `interactiveWhitelist` | `List<GlobalKey>?` | If set, AI can **only** interact with these elements. |
| `transformScreenContent` | `(String) → Future<String>` | Mask PII before the AI sees screen content. |
| `enableUiControl` | `bool` | `false` for knowledge-only mode. Default: `true`. |

### UI

| Prop | Type | Description |
|------|------|-------------|
| `accentColor` | `Color?` | Accent color for FAB and send button. |
| `theme` | `AgentChatBarTheme?` | Full chat bar theme override. |
| `showChatBar` | `bool` | Show/hide the floating chat bar. Default: `true`. |

---

## 🛡️ Security Guardrails

### Block sensitive UI areas

```dart
final _paymentKey = GlobalKey();

AiAgent(
  interactiveBlacklist: [_paymentKey],
  child: Scaffold(
    body: Container(key: _paymentKey, child: CreditCardForm()),
  ),
);
```

### Mask PII before the AI sees it

```dart
AiAgent(
  transformScreenContent: (content) async {
    return content
      .replaceAll(RegExp(r'\b\d{16}\b'), '****-****-****-****')
      .replaceAll(RegExp(r'[\w.]+@[\w.]+'), '[email]');
  },
  child: ...,
)
```

### Knowledge-only mode

```dart
AiAgent(
  enableUiControl: false,
  instructions: 'Answer questions about the app only.',
  child: ...,
)
```

### Production proxy

```dart
AiAgent(
  proxyUrl: 'https://api.myapp.com/ai',
  proxyHeaders: {'Authorization': 'Bearer $userToken'},
  child: ...,
)
```

> ⚠️ Using `apiKey` directly in a release build will log a security warning. Use `proxyUrl` in production.

---

## 🎨 Custom Theme

```dart
AiAgent(
  theme: AgentChatBarTheme(
    primaryColor: Colors.indigo,
    backgroundColor: const Color(0xFF1A1A2E),
    textColor: Colors.white,
  ),
  child: ...,
)
```

---

## 🪝 Access the Agent Anywhere

Trigger the agent from any widget in the tree:

```dart
final agent = AiAgentScope.of(context);

ElevatedButton(
  onPressed: () => agent.send('Add the first item to cart'),
  child: const Text('Let AI do it'),
);
```

---

## ⚙️ Custom Actions

Register custom Dart functions the agent can call:

```dart
actionRegistry.register(AgentAction(
  name: 'open_support_chat',
  description: 'Opens the in-app support chat',
  parameters: {},
  handler: (_) async {
    SupportChat.show();
    return ActionResult(success: true);
  },
));
```

---

## 📦 Requirements

- Flutter `>=3.0.0`
- Dart `>=3.0.0`
- `go_router` (required for autonomous navigation)
- Gemini API key — get one free at [Google AI Studio](https://aistudio.google.com)

---

## 📄 License

MIT © 2025 MobileAI
