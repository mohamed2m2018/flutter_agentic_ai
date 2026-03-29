import 'package:flutter/rendering.dart';

import 'types.dart';

/// ElementTreeWalker — Walks Flutter's SemanticsNode tree to discover
/// interactive elements and their real labels.
///
/// Analogue to React Native's FiberTreeWalker but for Flutter:
/// - Uses SemanticsNode tree instead of Fiber node tree
/// - Reads node.label / node.hint / node.tooltip for real text
/// - Checks SemanticsAction.tap / scrollUp / isTextField flags for type
/// - Stores semanticsNodeId so TapTool can dispatch via SemanticsOwner.performAction
///
/// Every Material/Cupertino widget auto-populates the semantics tree:
/// NavigationBar → "Home", "Profile" labels
/// Tab → "Tab 1 of 3" labels
/// ElevatedButton → button label
/// TextField → hint/label text
class ElementTreeWalker {
  final AgentConfig config;

  ElementTreeWalker(this.config);

  /// Walk the semantics tree and return all interactive + labeled elements.
  List<InteractiveElement> walk(dynamic rootContext) {
    final results = <InteractiveElement>[];

    // Access the semantics owner from the pipeline
    final owner = RendererBinding.instance.rootPipelineOwner.semanticsOwner;
    if (owner == null) {
      return results;
    }

    final root = owner.rootSemanticsNode;
    if (root == null) return results;

    final counter = _Counter(1);
    _visitNode(root, results, counter: counter, depth: 0);

    return results;
  }

  void _visitNode(
    SemanticsNode node,
    List<InteractiveElement> results, {
    required _Counter counter,
    required int depth,
  }) {
    if (depth > 15) return;

    final data = node.getSemanticsData();
    // ignore: deprecated_member_use
    final flags = data.flags;
    final actions = data.actions;

    // Skip hidden nodes (but still visit their children)
    final isHidden = (flags & SemanticsFlag.isHidden.index) != 0;

    if (!isHidden) {
      final label = _resolveLabel(data);
      final isTappable = (actions & SemanticsAction.tap.index) != 0;
      final isScrollable =
          (actions & SemanticsAction.scrollUp.index) != 0 ||
          (actions & SemanticsAction.scrollDown.index) != 0 ||
          (actions & SemanticsAction.scrollLeft.index) != 0 ||
          (actions & SemanticsAction.scrollRight.index) != 0;
      final isTextField = (flags & SemanticsFlag.isTextField.index) != 0;
      final isButton = (flags & SemanticsFlag.isButton.index) != 0;
      final isCheckable = (flags & SemanticsFlag.hasCheckedState.index) != 0;
      final isSlider = (flags & SemanticsFlag.isSlider.index) != 0;
      final isSelected = (flags & SemanticsFlag.isSelected.index) != 0;
      final hasEnabledState = (flags & SemanticsFlag.hasEnabledState.index) != 0;
      final isEnabled = (flags & SemanticsFlag.isEnabled.index) != 0;
      final isDisabled = hasEnabledState && !isEnabled;

      final isInteractive = (isTappable || isTextField || isScrollable || isSlider) && !isDisabled;
      final hasContent = label.isNotEmpty;

      if (hasContent || isInteractive) {
        // Determine type
        ElementType type;
        if (isTextField) {
          type = ElementType.textInput;
        } else if (isSlider) {
          type = ElementType.slider;
        } else if (isCheckable) {
          type = ElementType.checkbox;
        } else if (isScrollable) {
          type = ElementType.scrollable;
        } else if (isTappable || isButton) {
          type = ElementType.pressable;
        } else {
          type = ElementType.text;
        }

        // State attributes
        final stateParts = <String>[];
        if (isCheckable) {
          final isChecked = (flags & SemanticsFlag.isChecked.index) != 0;
          stateParts.add('checked="$isChecked"');
        }
        if (isSelected) stateParts.add('selected="true"');
        if (isDisabled) stateParts.add('enabled="false"');
        if (data.value.isNotEmpty) stateParts.add('value="${data.value}"');

        final displayLabel = label.isNotEmpty ? label : _fallbackLabel(type);

        // Only emit nodes that have a label or are interactive
        if (displayLabel.isNotEmpty || isInteractive) {
          results.add(InteractiveElement(
            index: counter.value,
            label: displayLabel,
            type: type,
            semanticsNodeId: node.id,
            properties: {
              if (stateParts.isNotEmpty) 'state': stateParts.join(' '),
            },
          ));
          counter.value++;
        }
      }
    }

    // Always visit children
    node.visitChildren((child) {
      _visitNode(child, results, counter: counter, depth: depth + 1);
      return true;
    });
  }

  String _resolveLabel(SemanticsData data) {
    if (data.label.isNotEmpty) return data.label.replaceAll('\n', ' ').trim();
    if (data.hint.isNotEmpty) return data.hint.trim();
    if (data.tooltip.isNotEmpty) return data.tooltip.trim();
    return '';
  }

  String _fallbackLabel(ElementType type) {
    switch (type) {
      case ElementType.textInput:
        return 'Text Field';
      case ElementType.scrollable:
        return 'Scrollable Area';
      case ElementType.checkbox:
        return 'Checkbox';
      case ElementType.slider:
        return 'Slider';
      case ElementType.pressable:
        return 'Interactive Element';
      default:
        return '';
    }
  }
}

/// Mutable counter for recursive index tracking without closures.
class _Counter {
  int value;
  _Counter(this.value);
}
