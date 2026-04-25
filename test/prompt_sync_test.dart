import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/src/core/rn_prompt_bundle.g.dart';
import 'package:mobileai_flutter/src/core/system_prompt.dart';
import 'package:mobileai_flutter/src/support/support_prompt.dart';
import 'package:mobileai_flutter/src/support/types.dart';

void main() {
  test('RN prompt bundle stays in sync with React Native source', () async {
    final result = await Process.run(
      'node',
      const ['tool/sync_rn_prompts.cjs', '--check'],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('system prompt wrappers resolve exact generated RN prompt text', () {
    expect(
      buildSystemPrompt(
        'en',
        hasKnowledge: true,
        isCopilot: true,
        supportStyle: 'warm-concise',
      ),
      RnPromptBundle.textPrompts['en|1|1|warm-concise'],
    );

    expect(
      buildVoiceSystemPrompt(
        'ar',
        hasKnowledge: false,
        supportStyle: 'neutral-professional',
      ),
      RnPromptBundle.voicePrompts['ar|0|neutral-professional'],
    );

    expect(
      buildKnowledgeOnlyPrompt('en', hasKnowledge: true),
      RnPromptBundle.knowledgePrompts['en|1'],
    );
  });

  test('support prompt uses exact RN generated wording when uncustomized', () {
    expect(
      buildSupportPrompt(
        const SupportModeConfig(
          enabled: true,
          supportStyle: 'wow-service',
        ),
      ),
      RnPromptBundle.supportModePrompts['wow-service'],
    );
  });
}
