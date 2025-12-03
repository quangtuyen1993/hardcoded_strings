import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:hardcoded_strings/src/strings_helper.dart';

class HardCodedStringsRule extends DartLintRule {
  const HardCodedStringsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'hardcoded_strings',
    problemMessage: 'Avoid using hardcoded strings in the code.',
    correctionMessage: 'Consider using localization or constants for strings.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((node) {
      if (node.thisOrAncestorOfType<Directive>() != null) {
        return;
      }
      _checkStringLiteral(node, reporter);
    });
  }

  void _checkStringLiteral(StringLiteral node, DiagnosticReporter reporter) {
    // Check for ignore comments
    if (hasIgnoreComment(node)) return;

    // Only check strings that are passed to widgets
    if (!_isPassedToWidget(node)) return;

    // Skip empty strings
    if (node.stringValue?.isEmpty ?? true) return;

    // Skip very short strings (single characters, operators, etc.)
    if (node.stringValue!.length <= 2) return;

    // Skip strings used as map keys
    if (_isMapKey(node)) return;

    // Skip strings in widget properties where hardcoding is acceptable
    if (_isAcceptableWidgetProperty(node)) return;

    // Skip strings that look like technical identifiers or configuration
    if (_isTechnicalString(node.stringValue!)) return;

    reporter.atNode(node, _code);
  }
}

bool _isMapKey(StringLiteral node) {
  final parent = node.parent;

  // Check if this string is used as an index in bracket notation (map['key'])
  if (parent is IndexExpression) {
    return parent.index == node;
  }

  // Check if this string is used as a key in map literal ({key: value})
  if (parent is MapLiteralEntry) {
    return parent.key == node;
  }

  return false;
}

bool _isPassedToWidget(StringLiteral node) {
  // We only consider strings that are direct arguments of a widget
  // constructor call. This avoids flagging strings located inside
  // callback/function bodies (e.g., logger.info('...') inside a
  // BlocListener listener).

  // Find the nearest ArgumentList ancestor that contains this string.
  final argumentList = node.thisOrAncestorOfType<ArgumentList>();
  if (argumentList == null) return false;

  // If there is a FunctionExpression/FunctionBody between the string
  // and the ArgumentList, then this string belongs to a different
  // invocation (e.g., a callback body) and should not be treated as
  // a widget argument.
  AstNode? walker = node.parent;
  while (walker != null && walker != argumentList) {
    if (walker is FunctionExpression || walker is FunctionBody) {
      return false;
    }
    walker = walker.parent;
  }

  // Ensure that this argument list belongs to an InstanceCreationExpression
  // (i.e., a constructor call) and that the constructed type is a Widget.
  final owner = argumentList.parent;
  if (owner is! InstanceCreationExpression) return false;

  final type = owner.staticType;
  if (type == null || !_isFlutterWidget(type.element)) return false;

  // Verify the string is directly part of this ArgumentList (either as a
  // positional argument or as the value of a NamedExpression).
  for (final arg in argumentList.arguments) {
    if (identical(arg, node)) return true;
    if (arg is NamedExpression && identical(arg.expression, node)) {
      return true;
    }
  }

  return false;
}

bool _isFlutterWidget(Element? element) {
  if (element == null) return false;

  // Check if the class extends Widget, StatefulWidget, or StatelessWidget
  if (element is ClassElement) {
    return _extendsWidget(element);
  }

  return false;
}

bool _extendsWidget(ClassElement element) {
  // Check the inheritance chain for Widget classes
  ClassElement? current = element;

  while (current != null) {
    final className = current.name;

    // Common Flutter widget base classes
    if (_isWidgetBaseClass(className ?? '')) {
      return true;
    }

    // Check supertype
    final supertype = current.supertype;
    if (supertype != null) {
      current =
          supertype.element is ClassElement
              ? supertype.element as ClassElement
              : null;
    } else {
      break;
    }
  }

  return false;
}

bool _isWidgetBaseClass(String className) {
  const widgetBaseClasses = {
    'Widget',
    'StatelessWidget',
    'StatefulWidget',
    'InheritedWidget',
    'RenderObjectWidget',
    'LeafRenderObjectWidget',
    'SingleChildRenderObjectWidget',
    'MultiChildRenderObjectWidget',
    'ProxyWidget',
    'ParentDataWidget',
    'InheritedTheme',
    'PreferredSizeWidget',
  };

  return widgetBaseClasses.contains(className);
}

bool _isAcceptableWidgetProperty(StringLiteral node) {
  final parent = node.parent;
  if (parent is! NamedExpression) return false;

  final propertyName = parent.name.label.name;

  // Widget properties where hardcoded strings are commonly acceptable
  const acceptableProperties = {
    // Accessibility and semantics
    'semanticsLabel',
    'excludeSemantics',

    // Technical identifiers
    'restorationId',
    'heroTag',
    'key',
    'debugLabel',

    // Asset and resource references
    'fontFamily',
    'package',
    'name', // Asset names
    'asset', // Asset paths
    // Development and debugging
    'tooltip', // Can be acceptable for simple tooltips
    // Widget-specific technical properties
    'textDirection', // When passed as string
    'locale', // Language codes
    'materialType',
    'clipBehavior',
    'crossAxisAlignment',
    'mainAxisAlignment',
    'textAlign',
    'textBaseline',
    'overflow',
    'softWrap',
    'textScaleFactor',
  };

  return acceptableProperties.contains(propertyName);
}

bool _isTechnicalString(String value) {
  // Skip strings that are clearly technical or configuration values
  final technicalPatterns = [
    // URLs
    RegExp(r'^\w+://'),
    // Email addresses
    RegExp(r'^[\w\-\.]+@[\w\-\.]+\.\w+'),
    // Hex colors
    RegExp(r'^#[0-9A-Fa-f]{3,8}'),
    // Numbers with optional units
    RegExp(r'^\d+(\.\d+)?[a-zA-Z]*'),
    // CONSTANT_CASE (all caps with underscores, at least 2 parts)
    RegExp(r'^[A-Z][A-Z0-9]*_[A-Z0-9_]*'),
    // snake_case identifiers (lowercase with underscores, at least 2 parts)
    RegExp(r'^[a-z]+_[a-z_]+'),
    // File paths
    RegExp(r'^/[\w/\-\.]*'),
    // Dotted notation (e.g., package.asset)
    RegExp(r'^\w+\.\w+'),
    // File names with extensions
    RegExp(r'^[\w\-]+\.[\w]+'),
    // Identifiers with numbers/underscores/hyphens (but not pure words)
    RegExp(r'^[a-zA-Z0-9]*[_\-0-9]+[a-zA-Z0-9_\-]*'),
  ];

  return technicalPatterns.any((pattern) => pattern.hasMatch(value.trim()));
}

