import 'types.dart';

/// ScreenDehydrator converts discovering interactive elements into 
/// a textual representation that the LLM can understand.
class ScreenDehydrator {
  /// Converts the list of interactive elements into a prompt string.
  /// Format: [index] Label (type) - properties
  static String dehydrate(List<InteractiveElement> elements) {
    if (elements.isEmpty) {
      return "No interactive elements detected on this screen.";
    }

    // Sort: high priority first, then normal priority
    final sortedElements = List<InteractiveElement>.from(elements)
      ..sort((a, b) {
        if (a.aiPriority == AiPriority.high && b.aiPriority != AiPriority.high) {
          return -1;
        }
        if (a.aiPriority != AiPriority.high && b.aiPriority == AiPriority.high) {
          return 1;
        }
        return a.index.compareTo(b.index);
      });

    final buffer = StringBuffer();

    for (var element in sortedElements) {
      final typeString = _formatElementType(element.type);
      buffer.write('[${element.index}] ${element.label} ($typeString)');

      if (element.properties.isNotEmpty) {
        final propsList = element.properties.entries
            .where((e) => e.value != null && e.value.toString().isNotEmpty)
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        if (propsList.isNotEmpty) {
           buffer.write(' - { $propsList }');
        }
      }
      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  static String _formatElementType(ElementType type) {
    switch (type) {
      case ElementType.pressable:
        return 'button';
      case ElementType.textInput:
        return 'text-input';
      case ElementType.switchToggle:
        return 'switch';
      case ElementType.scrollable:
        return 'scrollable';
      case ElementType.slider:
        return 'slider';
      case ElementType.picker:
        return 'picker';
      case ElementType.datePicker:
        return 'date-picker';
      case ElementType.checkbox:
        return 'checkbox';
      case ElementType.text:
        return 'text';
    }
  }
}
