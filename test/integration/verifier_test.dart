import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';

void main() {
  group('Verification System Integration', () {
    late OutcomeVerifier verifier;
    late MockProvider mockProvider;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockProvider = MockProvider();
      verifier = OutcomeVerifier(
        provider: mockProvider,
        config: AgentConfig(),
      );
    });

    group('Critical Action Detection', () {
      test('identifies commit-like actions as critical', () {
        final action = VerificationAction(
          toolName: 'tap',
          args: {'index': 0},
          label: 'Submit Button',
        );

        expect(verifier.isCriticalAction(action), true);
      });

      test('identifies save actions as critical', () {
        final action = VerificationAction(
          toolName: 'tap',
          args: {'index': 0},
          label: 'Save Changes',
        );

        expect(verifier.isCriticalAction(action), true);
      });

      test('identifies confirm actions as critical', () {
        final action = VerificationAction(
          toolName: 'tap',
          args: {'index': 0},
          label: 'Confirm Purchase',
        );

        expect(verifier.isCriticalAction(action), true);
      });

      test('identifies add and remove actions as critical', () {
        final addAction = VerificationAction(
          toolName: 'tap',
          args: {'index': 0},
          label: 'Add to Cart',
        );
        final removeAction = VerificationAction(
          toolName: 'tap',
          args: {'index': 1},
          label: 'Remove item',
        );

        expect(verifier.isCriticalAction(addAction), true);
        expect(verifier.isCriticalAction(removeAction), true);
      });

      test('non-commit actions are not critical', () {
        final action = VerificationAction(
          toolName: 'tap',
          args: {'index': 0},
          label: 'View Details',
        );

        expect(verifier.isCriticalAction(action), false);
      });

      test('elements with requiresConfirmation are always critical', () {
        final element = InteractiveElement(
          index: 0,
          type: ElementType.pressable,
          label: 'Random Button',
          properties: {'requiresConfirmation': true},
        );

        final action = VerificationAction(
          toolName: 'tap',
          args: {'index': 0},
          label: 'Random Button',
          targetElement: element,
        );

        expect(verifier.isCriticalAction(action), true);
      });
    });

    group('Deterministic Verification', () {
      test('detects error signals in screen content', () async {
        final context = VerificationContext(
          goal: 'Submit form',
          action: const VerificationAction(
            toolName: 'tap',
            args: {'index': 0},
            label: 'Submit',
          ),
          preAction: const VerificationSnapshot(
            screenName: 'Form',
            screenContent: '[0] Submit button',
            elements: [],
          ),
          postAction: const VerificationSnapshot(
            screenName: 'Form',
            screenContent: '[0] Submit button\n[1] Error: Required field missing',
            elements: [],
          ),
        );

        final result = await verifier.verify(context);

        expect(result.status, VerificationStatus.error);
        expect(result.source, 'deterministic');
        expect(result.evidence, contains('error'));
      });

      test('detects navigation as success', () async {
        final context = VerificationContext(
          goal: 'Navigate to home',
          action: const VerificationAction(
            toolName: 'tap',
            args: {'index': 0},
            label: 'Home',
          ),
          preAction: const VerificationSnapshot(
            screenName: 'Details',
            screenContent: '[0] Home button',
            elements: [],
          ),
          postAction: const VerificationSnapshot(
            screenName: 'Home',
            screenContent: '[1] Profile button\n[2] Settings button',
            elements: [],
          ),
        );

        final result = await verifier.verify(context);

        expect(result.status, VerificationStatus.success);
        expect(result.source, 'deterministic');
        expect(result.evidence, contains('navigated'));
      });

      test('detects success signals in screen content', () async {
        final context = VerificationContext(
          goal: 'Submit form',
          action: const VerificationAction(
            toolName: 'tap',
            args: {'index': 0},
            label: 'Submit',
          ),
          preAction: const VerificationSnapshot(
            screenName: 'Form',
            screenContent: '[0] Submit button',
            elements: [],
          ),
          postAction: const VerificationSnapshot(
            screenName: 'Form',
            screenContent: 'Success! Your changes have been saved.',
            elements: [],
          ),
        );

        final result = await verifier.verify(context);

        expect(result.status, VerificationStatus.success);
        expect(result.source, 'deterministic');
        expect(result.evidence, contains('success'));
      });

      test('returns uncertain when outcome is unclear', () async {
        final context = VerificationContext(
          goal: 'Tap button',
          action: const VerificationAction(
            toolName: 'tap',
            args: {'index': 0},
            label: 'Random Button',
          ),
          preAction: const VerificationSnapshot(
            screenName: 'Home',
            screenContent: '[0] Random Button\n[1] Other Button',
            elements: [],
          ),
          postAction: const VerificationSnapshot(
            screenName: 'Home',
            screenContent: '[0] Random Button\n[1] Other Button',
            elements: [],
          ),
        );

        final result = await verifier.verify(context);

        expect(result.status, VerificationStatus.uncertain);
        expect(result.source, 'deterministic');
      });
    });

    group('Error Classification', () {
      test('classifies network errors as uncontrollable', () async {
        final context = VerificationContext(
          goal: 'Submit form',
          action: const VerificationAction(
            toolName: 'tap',
            args: {'index': 0},
            label: 'Submit',
          ),
          preAction: const VerificationSnapshot(
            screenName: 'Form',
            screenContent: '[0] Submit button',
            elements: [],
          ),
          postAction: const VerificationSnapshot(
            screenName: 'Form',
            screenContent: 'Network error: Unable to connect to server',
            elements: [],
          ),
        );

        final result = await verifier.verify(context);

        expect(result.status, VerificationStatus.error);
        expect(result.failureKind, VerificationFailureKind.uncontrollable);
      });

      test('classifies validation errors as controllable', () async {
        final context = VerificationContext(
          goal: 'Submit form',
          action: const VerificationAction(
            toolName: 'tap',
            args: {'index': 0},
            label: 'Submit',
          ),
          preAction: const VerificationSnapshot(
            screenName: 'Form',
            screenContent: '[0] Submit button',
            elements: [],
          ),
          postAction: const VerificationSnapshot(
            screenName: 'Form',
            screenContent: 'Error: Email field is required',
            elements: [],
          ),
        );

        final result = await verifier.verify(context);

        expect(result.status, VerificationStatus.error);
        expect(result.failureKind, VerificationFailureKind.controllable);
      });
    });

    group('Verifier Configuration', () {
      test('isEnabled returns true when config enabled is null (default)', () {
        final config = AgentConfig();
        final testVerifier = OutcomeVerifier(
          provider: mockProvider,
          config: config,
        );

        expect(testVerifier.isEnabled(), true);
      });

      test('isEnabled returns value from config', () {
        final config = AgentConfig(
          verifier: VerifierConfig(enabled: false),
        );
        final testVerifier = OutcomeVerifier(
          provider: mockProvider,
          config: config,
        );

        expect(testVerifier.isEnabled(), false);
      });

      test('getMaxFollowupSteps returns value from config', () {
        final config = AgentConfig(
          verifier: VerifierConfig(maxFollowupSteps: 5),
        );
        final testVerifier = OutcomeVerifier(
          provider: mockProvider,
          config: config,
        );

        expect(testVerifier.getMaxFollowupSteps(), 5);
      });

      test('getMaxFollowupSteps returns default when not configured', () {
        final config = AgentConfig();
        final testVerifier = OutcomeVerifier(
          provider: mockProvider,
          config: config,
        );

        expect(testVerifier.getMaxFollowupSteps(), 2);
      });
    });
  });
}

// Mock provider for testing
class MockProvider extends AiProvider {
  bool shouldReturnVerification = false;
  VerificationStatus? mockStatus;
  VerificationFailureKind? mockFailureKind;
  String? mockEvidence;

  @override
  Future<ProviderResult> generateContent({
    required String systemPrompt,
    required String userMessage,
    required List<ToolDefinition> tools,
    required List<AgentStep> history,
    String? screenshotBase64,
  }) async {
    if (shouldReturnVerification && mockStatus != null) {
      return ProviderResult(
        actionName: 'report_verification',
        actionParams: {
          'status': mockStatus == VerificationStatus.success ? 'success' :
                     mockStatus == VerificationStatus.error ? 'error' : 'uncertain',
          'failureKind': mockFailureKind == VerificationFailureKind.controllable ? 'controllable' : 'uncontrollable',
          'evidence': mockEvidence ?? 'Mock verification result',
        },
      );
    }

    return ProviderResult(
      actionName: 'done',
      actionParams: {'success': true, 'text': 'Test complete'},
    );
  }
}
