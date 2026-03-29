## 0.1.0

- **Overlay UI**: Floating `AgentChatBar` (draggable FAB + expandable panel) and `AgentOverlay` thinking indicator
- **Security guardrails**: `interactiveBlacklist`, `interactiveWhitelist`, `transformScreenContent`, `enableUiControl`
- **Production apiKey warning**: logs a security notice in release builds when `proxyUrl` is not set
- **Flattened API**: `AiAgent` now exposes flat top-level props (`apiKey`, `maxSteps`, `instructions`, `router`, `accentColor`) matching the React Native SDK's API surface
- **Cancellation**: `cancel()` support on `AgentRuntime` and `AiAgentController`
- **RTL / Arabic support**: chat bar placeholder and layout respect `language: 'ar'`
- **History summarization**: compresses long task histories to prevent context overflow
- **Budget guards**: `maxTokenBudget` and `maxCostUsd` stop runaway tasks

## 0.0.1

- Initial release
