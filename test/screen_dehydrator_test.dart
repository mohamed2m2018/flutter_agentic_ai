import 'package:flutter_test/flutter_test.dart';
import 'package:mobileai_flutter/mobileai_flutter.dart';
import 'package:mobileai_flutter/src/core/screen_dehydrator.dart';

void main() {
  test('screen dehydrator uses RN-style element formatting', () {
    final text = ScreenDehydrator.dehydrate(<InteractiveElement>[
      InteractiveElement(
        index: 1,
        type: ElementType.pressable,
        label: 'Fashion',
        properties: <String, dynamic>{
          'role': 'button',
          'selected': true,
          'enabled': true,
        },
      ),
      InteractiveElement(
        index: 2,
        type: ElementType.textInput,
        label: 'Search products...',
        properties: <String, dynamic>{
          'role': 'textbox',
          'value': 'cotton t-shirts',
          'hint': 'Search products...',
        },
      ),
      InteractiveElement(
        index: 3,
        type: ElementType.text,
        label: '\$19.99',
      ),
      InteractiveElement(
        index: 4,
        type: ElementType.scrollable,
        label: 'Vertical scroll area',
        properties: <String, dynamic>{
          'role': 'scrollable',
          'enabled': true,
          'orientation': 'vertical',
        },
      ),
    ]);

    expect(text, contains('[1]<pressable role="button" selected="true" enabled="true">Fashion />'));
    expect(text, contains('[2]<text-input role="textbox" value="cotton t-shirts" hint="Search products...">Search products... />'));
    expect(text, contains('Visible Content:'));
    expect(text, contains('- \$19.99'));
    expect(
      text,
      contains(
        '[4]<scrollable role="scrollable" orientation="vertical" enabled="true">Vertical scroll area />',
      ),
    );
  });

  test('screen dehydrator summarizes active state generically', () {
    final summary = ScreenDehydrator.summarizeActiveState(<InteractiveElement>[
      InteractiveElement(
        index: 1,
        type: ElementType.pressable,
        label: 'Fashion',
        properties: <String, dynamic>{
          'role': 'button',
          'selected': true,
          'enabled': true,
        },
      ),
      InteractiveElement(
        index: 2,
        type: ElementType.textInput,
        label: 'Search products...',
        properties: <String, dynamic>{
          'role': 'textbox',
          'value': 'cotton t-shirts',
          'hint': 'Search products...',
        },
      ),
    ]);

    expect(summary, contains('Active UI State:'));
    expect(summary, contains('<pressable> Fashion | selected="true"'));
    expect(summary, contains('<text-input> Search products... | value="cotton t-shirts"'));
  });
}
