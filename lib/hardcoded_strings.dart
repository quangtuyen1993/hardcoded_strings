import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:hardcoded_strings/src/hardcoded_strings.dart';

PluginBase createPlugin() => StringsHardCodedLint();

class StringsHardCodedLint extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    const HardCodedStringsRule(),
  ];
}
