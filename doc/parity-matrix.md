# mobileai_flutter Parity Matrix

This file tracks parity against the React Native SDK. Status values:

- `implemented`
- `adapted`
- `scaffolded`
- `missing`
- `rejected`

## Core Runtime

| Subsystem | Status | Notes |
|---|---|---|
| Agent shell (`AiAgent`) | implemented | Root shell exists and now exposes richer parity-oriented props. |
| Primary `AI*` public naming surface | implemented | `AIAgent`, `AIZone`, `AIAction`, `AIData`, `AIAgentScope` now exist, with `Ai*` aliases preserved. |
| Structured assistant replies | adapted | `AiMessage`, `ExecutionResult`, and rich-node helpers added. Runtime still needs deeper salvage/normalization parity. |
| Action registry | implemented | `AiAction` and `actionRegistry` are working. |
| Data registry | adapted | `AiData` and `dataRegistry` added; runtime consumption still needs to deepen. |
| Block registry | implemented | Global block registry added. |
| Zone registry | implemented | Zones can now simplify, restore, and render injected blocks. |
| Prompt/runtime parity | scaffolded | Current runtime is usable but not yet fully aligned with RN prompt and tool routing behavior. |

## Navigation

| Subsystem | Status | Notes |
|---|---|---|
| `go_router` adapter | implemented | `GoRouterAdapter` added. |
| `Navigator` adapter | implemented | `NavigatorRouterAdapter` added. |
| Public router adapter contract | implemented | `FlutterRouterAdapter` added. |
| Screen-map aware route resolution | scaffolded | Runtime reads `screenMap`, but validation and route enrichment still need deeper parity. |
| Safe top-level-only navigate policy | adapted | Runtime/documentation enforce the rule conceptually; stricter gating still needs work. |
| Platform adapter boundary | adapted | `PlatformAdapter` types and `FlutterPlatformAdapter` are now present and used for screen snapshot reads. |

## Rich UI

| Subsystem | Status | Notes |
|---|---|---|
| Rich node types | implemented | `AiRichNode`, `AiTextNode`, `AiBlockNode` added. |
| Rich content renderer | implemented | `RichContentRenderer` added. |
| Built-in block family | adapted | `FactCard`, `ProductCard`, `ActionCard`, `ComparisonCard`, `FormCard` added as Flutter-native versions. |
| Rich theme tokens | adapted | `RichUiTheme` exists; token depth still trails RN. |
| Deprecated block/card compatibility | adapted | `InfoCard` and `ReviewSummary` wrappers now exist; behavior still simpler than RN. |

## Zones and Interventions

| Subsystem | Status | Notes |
|---|---|---|
| `AiZone` block injection | implemented | `render_block` can render into mounted zones. |
| Zone simplify / restore | implemented | Controller-backed zone actions added. |
| Intervention eligibility flags | implemented | Zone config now carries intervention metadata. |
| Prompt-level strict routing rules | scaffolded | Runtime surface exists; final routing policy still needs parity work. |

## Tools

| Subsystem | Status | Notes |
|---|---|---|
| `tap` / `type` / `scroll` / `keyboard` | implemented | Existing Flutter tools remain wired. |
| `navigate` / `wait` | implemented | Runtime support added. |
| `render_block` / `restore_zone` / `simplify_zone` | implemented | Added in runtime. |
| Deprecated `inject_card` alias | implemented | Delegates to `render_block`. |
| `long_press` | implemented | Dual-strategy: semantics API + widget callback fallback. |
| `adjust_slider` | implemented | Normalized 0.0-1.0 input with auto-range conversion. |
| `select_picker` | implemented | DropdownButton, PopupMenuButton, custom picker support. |
| `set_date` | implemented | ISO 8601 date format with TextField/TextFormField support. |
| `guide_user` | implemented | Overlay-based visual highlighting system. |
| `query_knowledge` | implemented | RAG integration via KnowledgeBaseService. |

## Providers

| Subsystem | Status | Notes |
|---|---|---|
| Gemini provider | implemented | Existing working path. |
| Provider factory | implemented | Added. |
| OpenAI provider | scaffolded | Exported, but transport still throws `UnimplementedError`. |

## Advanced Features

| Subsystem | Status | Notes |
|---|---|---|
| Knowledge base integration | implemented | RAG with `KnowledgeBaseService` and `query_knowledge` tool. |
| Approval workflow | implemented | Multi-level approval with `onAskUser` callback and scope tracking. |
| Outcome verification | implemented | Two-stage verification: deterministic pattern matching + LLM fallback. |
| Error suppression | implemented | FlutterError.onError interception with grace period cleanup. |
| Critical action detection | implemented | Commit-like actions auto-detected for verification. |

## Voice

| Subsystem | Status | Notes |
|---|---|---|
| Public `VoiceService` surface | adapted | RN-shaped scaffold added. |
| Live mobile audio transport | missing | Not implemented yet. |
| Tool-calling during voice | missing | Not implemented yet. |
| Screen-context sync during voice | missing | Not implemented yet. |

## Support

| Subsystem | Status | Notes |
|---|---|---|
| Support types | implemented | Added. |
| Support prompt builder | implemented | Added. |
| Escalate tool | implemented | Added foundation. |
| Report issue tool | implemented | Added foundation. |
| Escalation socket | scaffolded | Surface added; real flow needs deeper integration. |
| CSAT UI | adapted | `CSATSurvey` exists as a Flutter-native component. |
| Full support runtime/shell parity | missing | Still to be integrated into `AiAgent` and runtime. |

## Persistence, Telemetry, Consent

| Subsystem | Status | Notes |
|---|---|---|
| Conversation persistence/replay | adapted | Local structured transcript persistence is implemented; full RN backend conversation flows are still missing. |
| Analytics / telemetry | adapted | `MobileAI` telemetry surface exists with a lightweight hosted event path. |
| Consent flows | adapted | `AIConsentDialog` and persisted consent gating are implemented in `AIAgent`, but still simpler than RN. |

## Packaging

| Subsystem | Status | Notes |
|---|---|---|
| Separate Flutter package | implemented | `mobileai-flutter/` is fully separate from RN/web. |
| `mobileai_flutter` package identity | implemented | Metadata/import surface renamed. |
| Example app updated | implemented | Example now imports `mobileai_flutter`. |
| README rewritten for new package | implemented | Docs now describe the Flutter package directly. |
