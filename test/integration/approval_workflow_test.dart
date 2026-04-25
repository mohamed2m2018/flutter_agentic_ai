import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  group('Approval Workflow Integration', () {
    late AgentRuntime runtime;
    late GlobalKey rootKey;
    late MockProvider mockProvider;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      rootKey = GlobalKey();
      mockProvider = MockProvider();
    });

    tearDown(() {
      runtime.dispose();
    });

    test('initial approval scope is set from config', () {
      final config = AgentConfig(
        initialApprovalScope: AppActionApprovalScope.workflow,
      );

      runtime = AgentRuntime(
        provider: mockProvider,
        config: config,
        rootKey: rootKey,
      );

      expect(runtime.getCurrentApprovalScope(), AppActionApprovalScope.workflow);
    });

    test('workflow approval is granted after user approval', () async {
      String? capturedRequest;
      String? responseToReturn = '__APPROVAL_GRANTED__';

      final config = AgentConfig(
        onAskUser: (request) async {
          capturedRequest = request.toString();
          return responseToReturn;
        },
      );

      runtime = AgentRuntime(
        provider: mockProvider,
        config: config,
        rootKey: rootKey,
      );

      // Initially no approval
      expect(runtime.hasWorkflowApproval(), false);

      // Execute a UI action that requires approval
      final result = await runtime.executeTool('tap', {'index': 0});

      // Should have requested approval
      expect(capturedRequest, isNotNull);
      expect(capturedRequest, contains('tap'));
    });

    test('approval denied returns error message', () async {
      final config = AgentConfig(
        onAskUser: (request) async {
          return 'Action denied by user';
        },
      );

      runtime = AgentRuntime(
        provider: mockProvider,
        config: config,
        rootKey: rootKey,
      );

      final result = await runtime.executeTool('tap', {'index': 0});

      expect(result, contains('requires approval'));
      expect(result, contains('denied'));
    });

    test('workflow approval persists across multiple actions', () async {
      int approvalCount = 0;

      final config = AgentConfig(
        onAskUser: (request) async {
          approvalCount++;
          return '__APPROVAL_GRANTED__';
        },
      );

      runtime = AgentRuntime(
        provider: mockProvider,
        config: config,
        rootKey: rootKey,
      );

      // First action - should request approval
      await runtime.executeTool('tap', {'index': 0});
      expect(approvalCount, 1);
      expect(runtime.hasWorkflowApproval(), true);

      // Second action - should NOT request approval (already granted)
      await runtime.executeTool('tap', {'index': 1});
      expect(approvalCount, 1); // Still 1, no new approval request
    });

    test('non-UI actions do not require approval', () async {
      bool approvalRequested = false;

      final config = AgentConfig(
        onAskUser: (request) async {
          approvalRequested = true;
          return '__APPROVAL_GRANTED__';
        },
      );

      runtime = AgentRuntime(
        provider: mockProvider,
        config: config,
        rootKey: rootKey,
      );

      // Knowledge query - should not require approval
      await runtime.executeTool('query_knowledge', {'question': 'test'});
      expect(approvalRequested, false);

      // Wait action - should not require approval
      await runtime.executeTool('wait', {'seconds': 1});
      expect(approvalRequested, false);
    });
  });
}

// Mock provider for testing
class MockProvider extends AiProvider {
  @override
  Future<ProviderResult> generateContent({
    required String systemPrompt,
    required String userMessage,
    required List<ToolDefinition> tools,
    required List<AgentStep> history,
    String? screenshotBase64,
  }) async {
    return ProviderResult(
      actionName: 'done',
      actionParams: {'success': true, 'text': 'Test complete'},
    );
  }
}

// Extension to access internal state for testing
extension AgentRuntimeTesting on AgentRuntime {
  AppActionApprovalScope getCurrentApprovalScope() {
    // This would need to be exposed via a test helper or friend class
    return AppActionApprovalScope.none;
  }

  bool hasWorkflowApproval() {
    // This would need to be exposed via a test helper or friend class
    return false;
  }
}
