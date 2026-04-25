import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) {
  final projectRoot = Directory.current.path;
  final routerPath = args.isNotEmpty
      ? args.first
      : '$projectRoot/example/lib/router.dart';
  final outputPath = args.length > 1
      ? args[1]
      : '$projectRoot/example/lib/ai_screen_map.dart';

  final generator = _FlutterScreenMapGenerator(projectRoot);
  final result = generator.generate(routerPath: routerPath);

  File(outputPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(result.render());

  stdout.writeln('Generated screen map: $outputPath');
  stdout.writeln('Routes: ${result.routes.length}');
}

class _FlutterScreenMapGenerator {
  final String projectRoot;

  _FlutterScreenMapGenerator(this.projectRoot);

  _GeneratedScreenMap generate({required String routerPath}) {
    final routerFile = File(routerPath);
    final routerDir = routerFile.parent.path;
    final routerSource = routerFile.readAsStringSync();
    final classToFile = _buildClassToFileMap(routerSource, routerDir);
    final routes = _parseRoutes(routerSource, classToFile);
    final routePaths = routes.map((route) => route.path).toList(growable: false);
    final screenEntries = <_GeneratedScreenEntry>[];
    final edges = <String, Set<String>>{
      for (final route in routes) route.path: <String>{},
    };

    final safeTopLevelRoutes = routes
        .where((route) => route.safeDirectNavigation)
        .map((route) => route.path)
        .toList(growable: false);

    for (final from in safeTopLevelRoutes) {
      for (final to in safeTopLevelRoutes) {
        if (from != to) {
          edges[from]!.add(to);
        }
      }
    }

    for (final route in routes) {
      final source = route.sourceFile != null ? File(route.sourceFile!).readAsStringSync() : '';
      final title = _extractTitle(source, route.path);
      final labels = _extractVisibleLabels(source);
      final dynamicSummaries = _extractDynamicStructureSummaries(
        source,
        routePath: route.path,
        title: title,
      );
      final navigatesTo = _extractNavigationTargets(
        source,
        routePaths,
      );
      final parentRoute = _findParentRoute(route.path, routePaths);
      if (parentRoute != null) {
        edges[parentRoute]?.add(route.path);
      }
      edges[route.path]!.addAll(navigatesTo);

      screenEntries.add(
        _GeneratedScreenEntry(
          path: route.path,
          title: title,
          description: _buildDescription(
            title: title,
            routePath: route.path,
            labels: labels,
            dynamicSummaries: dynamicSummaries,
          ),
          safeDirectNavigation: route.safeDirectNavigation,
        ),
      );
    }

    final orderedEdges = <String, List<String>>{};
    for (final route in routes) {
      final routeEdges = edges[route.path] ?? const <String>{};
      orderedEdges[route.path] = routePaths
          .where((path) => routeEdges.contains(path))
          .toList(growable: false);
    }

    final chains = _buildChains(
      routePaths: routePaths,
      edges: orderedEdges,
      starts: safeTopLevelRoutes,
    );

    return _GeneratedScreenMap(
      generatedAt: DateTime.now().toUtc(),
      routes: screenEntries.map((entry) {
        return entry.copyWith(
          navigatesTo: orderedEdges[entry.path]!,
        );
      }).toList(growable: false),
      chains: chains,
    );
  }

  Map<String, String> _buildClassToFileMap(String routerSource, String routerDir) {
    final classToFile = <String, String>{};
    final importMatches = RegExp(r"import '([^']+)';").allMatches(routerSource);
    for (final match in importMatches) {
      final importPath = match.group(1)!;
      if (importPath.startsWith('package:')) continue;
      final resolved = File('$routerDir/$importPath').absolute.path;
      if (!File(resolved).existsSync()) continue;
      final source = File(resolved).readAsStringSync();
      final classMatches = RegExp(r'class\s+([A-Za-z0-9_]+)\s+').allMatches(source);
      for (final classMatch in classMatches) {
        final className = classMatch.group(1)!;
        classToFile.putIfAbsent(className, () => resolved);
      }
    }
    return classToFile;
  }

  List<_RouteRecord> _parseRoutes(String source, Map<String, String> classToFile) {
    final matches = RegExp(
      r"GoRoute\s*\(\s*path:\s*'([^']+)'\s*,\s*builder:\s*\([^)]*\)\s*=>\s*(?:const\s+)?([A-Za-z0-9_]+)\(",
      dotAll: true,
    ).allMatches(source);

    return matches.map((match) {
      final path = _normalizePath(match.group(1)!);
      final className = match.group(2)!;
      return _RouteRecord(
        path: path,
        widgetClass: className,
        sourceFile: classToFile[className],
        safeDirectNavigation: _isSafeDirectNavigation(path),
      );
    }).toList(growable: false);
  }

  String _extractTitle(String source, String routePath) {
    if (source.isEmpty) {
      return _humanizeRoute(routePath);
    }

    final patterns = <RegExp>[
      RegExp(r"AppBar\([\s\S]*?title:\s*(?:const\s+)?Text\(\s*'([^']+)'", dotAll: true),
      RegExp(r'AppBar\([\s\S]*?title:\s*(?:const\s+)?Text\(\s*"([^"]+)"', dotAll: true),
      RegExp(r"FlexibleSpaceBar\([\s\S]*?title:\s*(?:const\s+)?Text\(\s*'([^']+)'", dotAll: true),
      RegExp(r'FlexibleSpaceBar\([\s\S]*?title:\s*(?:const\s+)?Text\(\s*"([^"]+)"', dotAll: true),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(source);
      if (match != null) {
        final title = _normalizeText(match.group(1)!);
        if (_isUsefulLiteral(title)) {
          return title;
        }
      }
    }

    return _humanizeRoute(routePath);
  }

  List<String> _extractVisibleLabels(String source) {
    if (source.isEmpty) return const <String>[];

    final results = <String>[];
    final patterns = <RegExp>[
      RegExp(r"Text\(\s*'([^']+)'"),
      RegExp(r'Text\(\s*"([^"]+)"'),
      RegExp(r"hintText:\s*'([^']+)'"),
      RegExp(r'hintText:\s*"([^"]+)"'),
      RegExp(r"tooltip:\s*'([^']+)'"),
      RegExp(r'tooltip:\s*"([^"]+)"'),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(source)) {
        final value = _normalizeText(match.group(1)!);
        if (_isUsefulLiteral(value) && !results.contains(value)) {
          results.add(value);
        }
      }
    }

    return results;
  }

  List<String> _extractDynamicStructureSummaries(
    String source, {
    required String routePath,
    required String title,
  }) {
    if (source.isEmpty) return const <String>[];

    final summaries = <String>[];
    final snippets = <String>[
      ..._extractWindowedSnippets(
        source,
        patterns: const <String>[
          'ListView.builder(',
          'GridView.builder(',
        ],
        windowSize: 1600,
      ),
      ..._extractWindowedRegexSnippets(
        source,
        pattern: RegExp(r'\.map\s*\(\s*\([^\)]*\)\s*(?:=>|\{)'),
        windowSize: 1400,
      ),
    ];

    for (final snippet in snippets) {
      final summary = _summarizeDynamicRowStructure(
        snippet,
        routePath: routePath,
        title: title,
      );
      if (summary.isNotEmpty && !summaries.contains(summary)) {
        summaries.add(summary);
      }
    }

    return summaries;
  }

  List<String> _extractWindowedSnippets(
    String source, {
    required List<String> patterns,
    required int windowSize,
  }) {
    final snippets = <String>[];
    for (final pattern in patterns) {
      var start = 0;
      while (true) {
        final index = source.indexOf(pattern, start);
        if (index < 0) break;
        final end = math.min(source.length, index + windowSize);
        snippets.add(source.substring(index, end));
        start = index + pattern.length;
      }
    }
    return snippets;
  }

  List<String> _extractWindowedRegexSnippets(
    String source, {
    required RegExp pattern,
    required int windowSize,
  }) {
    final snippets = <String>[];
    for (final match in pattern.allMatches(source)) {
      final end = math.min(source.length, match.start + windowSize);
      snippets.add(source.substring(match.start, end));
    }
    return snippets;
  }

  String _summarizeDynamicRowStructure(
    String snippet, {
    required String routePath,
    required String title,
  }) {
    final normalized = snippet.replaceAll(RegExp(r'\s+'), ' ');
    final fields = <String>[];

    if (_hasAnyPattern(normalized, <RegExp>[
      RegExp("(?:\\.(?:product\\.)?(?:name|title|label|displayName)\\b|\\[['\"](?:name|title|label|displayName)['\"]\\])"),
      RegExp(r'Text\(\s*[A-Za-z_][A-Za-z0-9_\.]*\.(?:product\.)?(?:name|title|label|displayName)\b'),
    ])) {
      fields.add('name');
    }

    if (_hasAnyPattern(normalized, <RegExp>[
      RegExp(r'\bImage(?:\.[A-Za-z_][A-Za-z0-9_]*)?\s*\('),
      RegExp(r"\b[a-z][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*\.(?:image|thumbnail|photo)\b"),
      RegExp("\\[['\"](?:image|thumbnail|photo)['\"]\\]"),
    ])) {
      fields.add('product image');
    }

    if (_hasAnyPattern(normalized, <RegExp>[
      RegExp(r'Color:'),
      RegExp("\\.(?:color|colour)\\b|\\[['\"](?:color|colour)['\"]\\]"),
    ])) {
      fields.add('color');
    }

    if (_hasAnyPattern(normalized, <RegExp>[
      RegExp("\\.(?:price|amount|cost)\\b|\\[['\"](?:price|amount|cost)['\"]\\]"),
    ])) {
      fields.add('price');
    }

    final hasQuantityField = _hasAnyPattern(normalized, <RegExp>[
      RegExp(r'\.(?:quantity|qty|count)\b'),
      RegExp(r'updateQuantity\s*\('),
    ]);
    final hasQuantityButtons = _hasAnyPattern(normalized, <RegExp>[
      RegExp(r'Icons\.remove_circle_outline'),
      RegExp(r'Icons\.add_circle_outline'),
      RegExp(r'\bIconButton\s*\('),
    ]);
    if (hasQuantityField && hasQuantityButtons) {
      fields.add('quantity controls');
    } else if (hasQuantityField) {
      fields.add('quantity');
    }

    if (_hasAnyPattern(normalized, <RegExp>[
      RegExp(r"Text\(\s*'Add'\s*\)"),
      RegExp(r'Text\(\s*"Add"\s*\)'),
      RegExp(r"child:\s*const\s+Text\(\s*'Add'\s*\)"),
      RegExp(r'child:\s*const\s+Text\(\s*"Add"\s*\)'),
      RegExp(r"label:\s*Text\(\s*'Add'\s*\)"),
      RegExp(r'label:\s*Text\(\s*"Add"\s*\)'),
    ])) {
      fields.add('add button');
    }

    final dedupedFields = <String>[];
    for (final field in fields) {
      if (!dedupedFields.contains(field)) {
        dedupedFields.add(field);
      }
    }

    final hasProductSignals = dedupedFields.any((field) => const <String>{
      'product image',
      'color',
      'price',
      'quantity',
      'quantity controls',
      'add button',
    }.contains(field));
    final hasProductRouteContext = routePath.contains('/cart') ||
        routePath.contains('/search') ||
        routePath.contains('/category') ||
        routePath.contains('/product') ||
        routePath == '/home' ||
        title.toLowerCase().contains('cart') ||
        title.toLowerCase().contains('search') ||
        title.toLowerCase().contains('category') ||
        title.toLowerCase().contains('product');
    final shouldUseProductName = hasProductSignals || hasProductRouteContext;
    final normalizedFields = dedupedFields
        .map((field) => field == 'name' && shouldUseProductName ? 'product name' : field)
        .toList(growable: false);

    if (normalizedFields.isEmpty || (normalizedFields.length == 1 && normalizedFields.first == 'name')) {
      return '';
    }

    return '${_dynamicListPrefix(routePath, title)} with ${normalizedFields.join(', ')}';
  }

  bool _hasAnyPattern(String source, List<RegExp> patterns) {
    for (final pattern in patterns) {
      if (pattern.hasMatch(source)) {
        return true;
      }
    }
    return false;
  }

  String _dynamicListPrefix(String routePath, String title) {
    final normalizedTitle = title.toLowerCase();
    final normalizedRoute = routePath.toLowerCase();
    if (normalizedTitle.contains('cart') || normalizedRoute.contains('/cart')) {
      return 'cart items list';
    }
    if (normalizedTitle.contains('search') || normalizedRoute.contains('/search')) {
      return 'search results list';
    }
    return 'items list';
  }

  List<String> _extractNavigationTargets(String source, List<String> knownPaths) {
    if (source.isEmpty) return const <String>[];

    final targets = <String>[];
    final pattern = RegExp(r"context\.(?:push|go)\(\s*'([^']+)'\s*\)");
    for (final match in pattern.allMatches(source)) {
      final rawPath = match.group(1)!;
      final normalized = _matchPathTemplate(rawPath, knownPaths);
      if (normalized != null && !targets.contains(normalized)) {
        targets.add(normalized);
      }
    }
    return targets;
  }

  String? _matchPathTemplate(String rawPath, List<String> knownPaths) {
    final normalizedTemplate = _normalizePath(rawPath);
    final templateSegments = normalizedTemplate
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment.contains(r'${') ? '*' : segment)
        .toList(growable: false);

    for (final knownPath in knownPaths) {
      final knownSegments = knownPath.split('/').where((segment) => segment.isNotEmpty).toList(growable: false);
      if (knownSegments.length != templateSegments.length) {
        continue;
      }

      var matches = true;
      for (var index = 0; index < knownSegments.length; index += 1) {
        final templateSegment = templateSegments[index];
        final knownSegment = knownSegments[index];
        if (templateSegment == '*') {
          if (!knownSegment.startsWith(':')) {
            matches = false;
            break;
          }
          continue;
        }
        if (templateSegment != knownSegment) {
          matches = false;
          break;
        }
      }

      if (matches) {
        return knownPath;
      }
    }

    return null;
  }

  String? _findParentRoute(String path, List<String> knownPaths) {
    final segments = path.split('/').where((segment) => segment.isNotEmpty).toList(growable: false);
    if (segments.length < 2) return null;

    for (var cut = segments.length - 1; cut >= 1; cut -= 1) {
      final candidate = '/${segments.take(cut).join('/')}';
      if (knownPaths.contains(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  List<List<String>> _buildChains({
    required List<String> routePaths,
    required Map<String, List<String>> edges,
    required List<String> starts,
  }) {
    final chains = <List<String>>[];
    final seen = <String>{};
    final startSet = starts.toSet();
    final maxDepth = routePaths.length;

    for (final start in starts) {
      void walk(List<String> path, int topLevelTransitions) {
        if (path.length > 1) {
          final key = path.join('>');
          if (seen.add(key)) {
            chains.add(List<String>.from(path));
          }
        }

        if (path.length >= maxDepth) {
          return;
        }

        for (final next in edges[path.last] ?? const <String>[]) {
          if (path.contains(next)) {
            continue;
          }

          final nextTopLevelTransitions =
              startSet.contains(next) && next != start
              ? topLevelTransitions + 1
              : topLevelTransitions;
          if (nextTopLevelTransitions > 1) {
            continue;
          }

          walk(<String>[...path, next], nextTopLevelTransitions);
        }
      }

      walk(<String>[start], 0);
    }

    return chains;
  }

  String _buildDescription({
    required String title,
    required String routePath,
    required List<String> labels,
    required List<String> dynamicSummaries,
  }) {
    final filteredLabels = labels
        .where((label) => label != title)
        .where((label) => !_looksLikeTopLevelTab(label))
        .where((label) => !_looksLikeProfileIdentity(label))
        .where((label) => !_looksLikeTransientUiCopy(label))
        .take(5)
        .toList(growable: false);
    final parts = <String>[
      ...dynamicSummaries.take(2),
      ...filteredLabels,
    ];

    if (parts.isEmpty) {
      return '${_humanizeRoute(routePath)} screen.';
    }
    return '$title screen with ${parts.join(', ')}.';
  }

  String _humanizeRoute(String routePath) {
    final segments = routePath
        .split('/')
        .where((segment) => segment.isNotEmpty && !segment.startsWith(':'))
        .map((segment) => segment.replaceAll('-', ' '))
        .map((segment) => segment[0].toUpperCase() + segment.substring(1))
        .toList(growable: false);
    if (segments.isEmpty) {
      return 'Screen';
    }
    return segments.join(' ');
  }

  bool _isSafeDirectNavigation(String path) {
    final segments = path.split('/').where((segment) => segment.isNotEmpty).toList(growable: false);
    return segments.length == 1 && segments.every((segment) => !segment.startsWith(':'));
  }

  String _normalizePath(String path) {
    final normalized = path.trim().replaceAll(RegExp(r'/+'), '/');
    if (normalized.isEmpty) return '/';
    if (!normalized.startsWith('/')) return '/$normalized';
    return normalized.endsWith('/') && normalized.length > 1
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  String _normalizeText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isUsefulLiteral(String value) {
    if (value.isEmpty) return false;
    if (value.contains(r'${') || value.contains(r'$')) return false;
    if (value.contains('Error:')) return false;
    if (_looksLikeTransientUiCopy(value)) return false;
    return true;
  }

  bool _looksLikeTopLevelTab(String value) {
    const tabLabels = <String>{'Home', 'Search', 'Cart', 'Profile'};
    return tabLabels.contains(value);
  }

  bool _looksLikeProfileIdentity(String value) {
    if (value.contains('@')) return true;
    if (value.length <= 2) return true;
    return false;
  }

  bool _looksLikeTransientUiCopy(String value) {
    final normalized = value.toLowerCase();
    return normalized == 'add' ||
        normalized == 'add to cart' ||
        normalized == 'added to cart' ||
        normalized == 'your cart is empty' ||
        normalized == 'start shopping' ||
        normalized == 'error' ||
        normalized.startsWith('error ') ||
        normalized.startsWith('logged out') ||
        normalized.contains('successfully') ||
        normalized.contains('not implemented') ||
        normalized == 'view all' ||
        normalized.startsWith('invalid ') ||
        normalized.endsWith(' applied!') ||
        normalized.startsWith('no products found') ||
        normalized.startsWith('error loading') ||
        normalized.startsWith('loading');
  }
}

class _RouteRecord {
  final String path;
  final String widgetClass;
  final String? sourceFile;
  final bool safeDirectNavigation;

  const _RouteRecord({
    required this.path,
    required this.widgetClass,
    required this.sourceFile,
    required this.safeDirectNavigation,
  });
}

class _GeneratedScreenEntry {
  final String path;
  final String title;
  final String description;
  final bool safeDirectNavigation;
  final List<String> navigatesTo;

  const _GeneratedScreenEntry({
    required this.path,
    required this.title,
    required this.description,
    required this.safeDirectNavigation,
    this.navigatesTo = const <String>[],
  });

  _GeneratedScreenEntry copyWith({
    List<String>? navigatesTo,
  }) {
    return _GeneratedScreenEntry(
      path: path,
      title: title,
      description: description,
      safeDirectNavigation: safeDirectNavigation,
      navigatesTo: navigatesTo ?? this.navigatesTo,
    );
  }
}

class _GeneratedScreenMap {
  final DateTime generatedAt;
  final List<_GeneratedScreenEntry> routes;
  final List<List<String>> chains;

  const _GeneratedScreenMap({
    required this.generatedAt,
    required this.routes,
    required this.chains,
  });

  String render() {
    final buffer = StringBuffer();
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.');
    buffer.writeln('//');
    buffer.writeln('// Source: example/lib/router.dart');
    buffer.writeln('// Generated by: dart run tool/generate_screen_map.dart');
    buffer.writeln();
    buffer.writeln("import 'package:mobileai_flutter/mobileai_flutter.dart';");
    buffer.writeln();
    buffer.writeln('final shopFlowScreenMap = ScreenMap(');
    buffer.writeln("  generatedAt: '${generatedAt.toIso8601String()}',");
    buffer.writeln("  framework: 'go_router',");
    buffer.writeln('  screens: <String, ScreenMapEntry>{');
    for (final route in routes) {
      buffer.writeln("    '${_escape(route.path)}': ScreenMapEntry(");
      buffer.writeln("      title: '${_escape(route.title)}',");
      buffer.writeln("      description: '${_escape(route.description)}',");
      if (route.navigatesTo.isEmpty) {
        buffer.writeln('      navigatesTo: const <String>[],');
      } else {
        buffer.writeln('      navigatesTo: const <String>[');
        for (final target in route.navigatesTo) {
          buffer.writeln("        '${_escape(target)}',");
        }
        buffer.writeln('      ],');
      }
      buffer.writeln('      safeDirectNavigation: ${route.safeDirectNavigation},');
      buffer.writeln('    ),');
    }
    buffer.writeln('  },');
    buffer.writeln('  chains: const <List<String>>[');
    for (final chain in chains) {
      buffer.writeln('    <String>[');
      for (final route in chain) {
        buffer.writeln("      '${_escape(route)}',");
      }
      buffer.writeln('    ],');
    }
    buffer.writeln('  ],');
    buffer.writeln(');');
    return buffer.toString();
  }

  String _escape(String value) {
    return value.replaceAll('\\', r'\\').replaceAll("'", r"\'");
  }
}
