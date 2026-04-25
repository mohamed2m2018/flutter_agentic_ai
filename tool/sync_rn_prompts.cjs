#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const flutterRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(flutterRoot, '..');
const rnRoot = path.resolve(repoRoot, 'react-native-ai-agent');
const ts = require(path.join(rnRoot, 'node_modules', 'typescript'));

const outputPath = path.join(
  flutterRoot,
  'lib',
  'src',
  'core',
  'rn_prompt_bundle.g.dart'
);

const cache = new Map();
const styles = ['warm-concise', 'wow-service', 'neutral-professional'];
const languages = ['en', 'ar'];
const bools = [false, true];

function resolveModule(specifier, fromDir) {
  if (!specifier.startsWith('.')) {
    return require.resolve(specifier, { paths: [fromDir, rnRoot] });
  }

  const candidates = [
    path.resolve(fromDir, specifier),
    path.resolve(fromDir, `${specifier}.ts`),
    path.resolve(fromDir, `${specifier}.js`),
    path.resolve(fromDir, specifier, 'index.ts'),
    path.resolve(fromDir, specifier, 'index.js'),
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  throw new Error(`Unable to resolve module "${specifier}" from ${fromDir}`);
}

function loadTsModule(filePath) {
  const normalizedPath = path.resolve(filePath);
  if (cache.has(normalizedPath)) {
    return cache.get(normalizedPath);
  }

  const source = fs.readFileSync(normalizedPath, 'utf8');
  const transpiled = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2020,
      esModuleInterop: true,
    },
    fileName: normalizedPath,
  }).outputText;

  const module = { exports: {} };
  cache.set(normalizedPath, module.exports);

  const localRequire = (specifier) => {
    const resolved = resolveModule(specifier, path.dirname(normalizedPath));
    if (resolved.endsWith('.ts')) {
      return loadTsModule(resolved);
    }
    return require(resolved);
  };

  const wrapper = new Function(
    'require',
    'module',
    'exports',
    '__filename',
    '__dirname',
    transpiled
  );
  wrapper(
    localRequire,
    module,
    module.exports,
    normalizedPath,
    path.dirname(normalizedPath)
  );

  cache.set(normalizedPath, module.exports);
  return module.exports;
}

function replacePlatformNouns(text) {
  return text
    .replace(/\bReact Native mobile application\b/g, 'Flutter mobile application')
    .replace(/\bReact Native mobile app\b/g, 'Flutter mobile app')
    .replace(/\bReact Native app\b/g, 'Flutter app')
    .replace(/\bReact Native\b/g, 'Flutter');
}

function keyFor(parts) {
  return parts.join('|');
}

function dartStringLiteral(value) {
  return JSON.stringify(value).replace(/\$/g, '\\$');
}

function emitMap(name, entries) {
  const rows = Object.entries(entries)
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([key, value]) => `    ${dartStringLiteral(key)}: ${dartStringLiteral(value)},`)
    .join('\n');
  return `  static const Map<String, String> ${name} = <String, String>{\n${rows}\n  };`;
}

function buildBundle() {
  const systemPromptModule = loadTsModule(
    path.join(rnRoot, 'src', 'core', 'systemPrompt.ts')
  );
  const supportStyleModule = loadTsModule(
    path.join(rnRoot, 'src', 'support', 'supportStyle.ts')
  );
  const supportPromptModule = loadTsModule(
    path.join(rnRoot, 'src', 'support', 'supportPrompt.ts')
  );

  const textPrompts = {};
  const voicePrompts = {};
  const knowledgePrompts = {};
  const supportModePrompts = {};
  const supportStylePrompts = {};
  const supportStyleTones = {};

  for (const style of styles) {
    const preset = supportStyleModule.resolveSupportStyle(style);
    supportModePrompts[style] = replacePlatformNouns(
      supportPromptModule.buildSupportPrompt({
        enabled: true,
        persona: { preset: style },
      })
    );
    supportStylePrompts[style] = replacePlatformNouns(
      supportStyleModule.buildSupportStylePrompt(style)
    );
    supportStyleTones[style] = replacePlatformNouns(preset.tone);
  }

  for (const language of languages) {
    for (const hasKnowledge of bools) {
      knowledgePrompts[keyFor([language, hasKnowledge ? '1' : '0'])] =
        replacePlatformNouns(
          systemPromptModule.buildKnowledgeOnlyPrompt(language, hasKnowledge)
        );

      for (const style of styles) {
        voicePrompts[keyFor([language, hasKnowledge ? '1' : '0', style])] =
          replacePlatformNouns(
            systemPromptModule.buildVoiceSystemPrompt(
              language,
              undefined,
              hasKnowledge,
              style
            )
          );

        for (const isCopilot of bools) {
          textPrompts[
            keyFor([
              language,
              hasKnowledge ? '1' : '0',
              isCopilot ? '1' : '0',
              style,
            ])
          ] = replacePlatformNouns(
            systemPromptModule.buildSystemPrompt(
              language,
              hasKnowledge,
              isCopilot,
              style
            )
          );
        }
      }
    }
  }

  return `// GENERATED CODE - DO NOT MODIFY BY HAND.
//
// Source of truth:
// - react-native-ai-agent/src/core/systemPrompt.ts
// - react-native-ai-agent/src/support/supportStyle.ts
//
// Generated by: node tool/sync_rn_prompts.cjs

library;

class RnPromptBundle {
${emitMap('textPrompts', textPrompts)}

${emitMap('voicePrompts', voicePrompts)}

${emitMap('knowledgePrompts', knowledgePrompts)}

${emitMap('supportModePrompts', supportModePrompts)}

${emitMap('supportStylePrompts', supportStylePrompts)}

${emitMap('supportStyleTones', supportStyleTones)}
}
`;
}

const generated = buildBundle();

if (process.argv.includes('--check')) {
  const existing = fs.existsSync(outputPath)
    ? fs.readFileSync(outputPath, 'utf8')
    : '';
  if (existing !== generated) {
    process.stderr.write(
      `RN prompt bundle is out of sync.\nRun: node tool/sync_rn_prompts.cjs\n`
    );
    process.exit(1);
  }
  process.stdout.write('RN prompt bundle is in sync.\n');
  process.exit(0);
}

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, generated);
process.stdout.write(`Generated ${outputPath}\n`);
