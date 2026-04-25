library;

import 'rn_prompt_bundle.g.dart';

String buildSystemPrompt(
  String language, {
  bool hasKnowledge = false,
  bool isCopilot = true,
  String supportStyle = 'warm-concise',
  String? userInstructions,
}) {
  final key = _textPromptKey(
    language: language,
    hasKnowledge: hasKnowledge,
    isCopilot: isCopilot,
    supportStyle: supportStyle,
  );
  final prompt =
      RnPromptBundle.textPrompts[key] ??
      RnPromptBundle.textPrompts[_textPromptKey(
        language: 'en',
        hasKnowledge: hasKnowledge,
        isCopilot: isCopilot,
        supportStyle: 'warm-concise',
      )]!;
  return _appendAppInstructions(prompt, userInstructions);
}

String buildKnowledgeOnlyPrompt(
  String language, {
  bool hasKnowledge = false,
  String? userInstructions,
}) {
  final key = _knowledgePromptKey(
    language: language,
    hasKnowledge: hasKnowledge,
  );
  final prompt =
      RnPromptBundle.knowledgePrompts[key] ??
      RnPromptBundle.knowledgePrompts[_knowledgePromptKey(
        language: 'en',
        hasKnowledge: hasKnowledge,
      )]!;
  return _appendAppInstructions(prompt, userInstructions);
}

String buildVoiceSystemPrompt(
  String language, {
  bool hasKnowledge = false,
  String supportStyle = 'warm-concise',
  String? userInstructions,
}) {
  final key = _voicePromptKey(
    language: language,
    hasKnowledge: hasKnowledge,
    supportStyle: supportStyle,
  );
  final prompt =
      RnPromptBundle.voicePrompts[key] ??
      RnPromptBundle.voicePrompts[_voicePromptKey(
        language: 'en',
        hasKnowledge: hasKnowledge,
        supportStyle: 'warm-concise',
      )]!;
  final guardedPrompt = _normalizeLanguage(language) == 'ar'
      ? prompt
      : '$prompt\n\n<voice_language_guard>\nSpeak English unless the user explicitly asks you to use another language. If input transcription looks like noise, punctuation, or unrelated non-English fragments, do not act on it; ask the user to repeat the command in English.\n</voice_language_guard>';
  return _appendAppInstructions(guardedPrompt, userInstructions);
}

String _textPromptKey({
  required String language,
  required bool hasKnowledge,
  required bool isCopilot,
  required String supportStyle,
}) {
  return '${_normalizeLanguage(language)}|${hasKnowledge ? '1' : '0'}|${isCopilot ? '1' : '0'}|${_normalizeSupportStyle(supportStyle)}';
}

String _voicePromptKey({
  required String language,
  required bool hasKnowledge,
  required String supportStyle,
}) {
  return '${_normalizeLanguage(language)}|${hasKnowledge ? '1' : '0'}|${_normalizeSupportStyle(supportStyle)}';
}

String _knowledgePromptKey({
  required String language,
  required bool hasKnowledge,
}) {
  return '${_normalizeLanguage(language)}|${hasKnowledge ? '1' : '0'}';
}

String _normalizeLanguage(String language) {
  return language.trim().toLowerCase() == 'ar' ? 'ar' : 'en';
}

String _normalizeSupportStyle(String supportStyle) {
  const known = <String>{'warm-concise', 'wow-service', 'neutral-professional'};
  final normalized = supportStyle.trim();
  return known.contains(normalized) ? normalized : 'warm-concise';
}

String _appendAppInstructions(String prompt, String? userInstructions) {
  final instructions = userInstructions?.trim();
  if (instructions == null || instructions.isEmpty) {
    return prompt;
  }
  return '$prompt\n\n<app_instructions>\n$instructions\n</app_instructions>';
}
