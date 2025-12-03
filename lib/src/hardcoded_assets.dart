import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:hardcoded_strings/src/strings_helper.dart';

class HardCodedAssetsRule extends DartLintRule {
  const HardCodedAssetsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'hardcoded_assets',
    problemMessage: 'Avoid using hardcoded assets in the code.',
    correctionMessage: 'Consider using localization or constants for assets.',
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
    if (hasIgnoreComment(node)) return;
    if (!AssetPathValidator.isAssetPath(node)) return;
    
    final assetMethodCall = AssetHandlerFactory.findAssetMethodCall(node);
    if (assetMethodCall == null) return;
    
    reporter.atNode(assetMethodCall, _code);
  }

  @override
  List<DartFix> getFixes() => [_ExtractToFlutterGenFix()];
}

class _ExtractToFlutterGenFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    Diagnostic analysisError,
    List<Diagnostic> others,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final type = node.staticType;
      if (type == null) return;
      
      final element = type.element;
      if (element is! ClassElement) return;
      
      final className = element.name;
      final handler = AssetHandlerFactory.create(className);
      if (handler == null) return;
      
      if (!handler.canHandle(node.constructorName.name?.name)) return;

      final assetPathNode = _findAssetPathNode(node.argumentList);
      if (assetPathNode == null) return;
      
      final stringValue = assetPathNode.stringValue;
      if (stringValue == null || stringValue.isEmpty) return;

      final flutterGenPath = AssetPathConverter.convert(stringValue);
      if (flutterGenPath == null) return;

      final suffix = handler.getSuffix(stringValue);
      final remainingArgs = _getRemainingArguments(node.argumentList, assetPathNode);
      final replacement = ReplacementBuilder.build(flutterGenPath, remainingArgs, suffix);

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Extract to flutter_gen: $flutterGenPath',
        priority: 70,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(node.sourceRange, replacement);
      });
    });
  }

  StringLiteral? _findAssetPathNode(ArgumentList argumentList) {
    for (final arg in argumentList.arguments) {
      if (arg is SimpleStringLiteral) {
        final stringValue = arg.stringValue;
        if (stringValue != null && AssetPathValidator.isAssetPath(arg)) {
          return arg;
        }
      } else if (arg is NamedExpression && arg.expression is SimpleStringLiteral) {
        final stringLiteral = arg.expression as SimpleStringLiteral;
        if (AssetPathValidator.isAssetPath(stringLiteral)) {
          return stringLiteral;
        }
      }
    }
    return null;
  }

  List<String> _getRemainingArguments(ArgumentList argumentList, StringLiteral assetPathNode) {
    final remainingArgs = <String>[];
    bool foundAssetPath = false;

    for (final arg in argumentList.arguments) {
      if (!foundAssetPath && identical(arg, assetPathNode)) {
        foundAssetPath = true;
        continue;
      }
      if (arg is NamedExpression && identical(arg.expression, assetPathNode)) {
        foundAssetPath = true;
        continue;
      }

      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        final expression = arg.expression;
        remainingArgs.add('$name: ${expression.toSource()}');
      } else {
        remainingArgs.add(arg.toSource());
      }
    }

    return remainingArgs;
  }
}

/// Abstract handler for different asset types
abstract class AssetHandler {
  bool canHandle(String? constructorName);
  String getSuffix(String assetPath);
}

/// Handler for Image.asset()
class ImageAssetHandler implements AssetHandler {
  @override
  bool canHandle(String? constructorName) => constructorName == 'asset';

  @override
  String getSuffix(String assetPath) {
    final lowerPath = assetPath.toLowerCase();
    return lowerPath.endsWith('.svg') ? 'svg' : 'image';
  }
}

/// Handler for SvgPicture.asset()
class SvgPictureAssetHandler implements AssetHandler {
  @override
  bool canHandle(String? constructorName) => constructorName == 'asset';

  @override
  String getSuffix(String assetPath) => 'svg';
}

/// Handler for AssetImage()
class AssetImageHandler implements AssetHandler {
  @override
  bool canHandle(String? constructorName) => true; // AssetImage doesn't have named constructor

  @override
  String getSuffix(String assetPath) => 'provider';
}

/// Factory to create appropriate asset handler
class AssetHandlerFactory {
  static AssetHandler? create(String? className) {
    switch (className) {
      case 'Image':
        return ImageAssetHandler();
      case 'SvgPicture':
        return SvgPictureAssetHandler();
      case 'AssetImage':
        return AssetImageHandler();
      default:
        return null;
    }
  }

  static InstanceCreationExpression? findAssetMethodCall(StringLiteral node) {
    final argumentList = node.thisOrAncestorOfType<ArgumentList>();
    if (argumentList == null) return null;

    final owner = argumentList.parent;
    if (owner is! InstanceCreationExpression) return null;

    final constructorCall = owner;
    final type = constructorCall.staticType;
    if (type == null) return null;

    final element = type.element;
    if (element is! ClassElement) return null;

    final className = element.name;
    final handler = create(className);
    if (handler == null) return null;

    final constructorName = constructorCall.constructorName.name?.name;
    if (!handler.canHandle(constructorName)) return null;

    if (!_isDirectArgument(node, argumentList)) return null;

    return constructorCall;
  }

  static bool _isDirectArgument(StringLiteral node, ArgumentList argumentList) {
    for (final arg in argumentList.arguments) {
      if (identical(arg, node)) return true;
      if (arg is NamedExpression && identical(arg.expression, node)) {
        return true;
      }
    }
    return false;
  }
}

/// Validates if a string literal is an asset path
class AssetPathValidator {
  static bool isAssetPath(StringLiteral node) {
    final path = node.stringValue ?? '';
    return path.startsWith('assets/') || path.startsWith('lib/assets/');
  }
}

/// Converts asset path to flutter_gen format
class AssetPathConverter {
  static String? convert(String assetPath) {
    final pathInfo = _parsePath(assetPath);
    if (pathInfo == null) return null;

    final segments = pathInfo.pathWithoutPrefix.split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) return null;

    final lastSegment = segments.last;
    final lastSegmentWithoutExt = lastSegment.contains('.')
        ? lastSegment.substring(0, lastSegment.lastIndexOf('.'))
        : lastSegment;

    final fileNameCamelCase = StringConverter.snakeCaseToCamelCase(lastSegmentWithoutExt);
    final pathSegments = <String>[];

    // Add lib.assets prefix if needed
    if (pathInfo.isLibAssets) {
      pathSegments.add('lib');
      pathSegments.add('assets');
    }

    // Add path segments (excluding the file name)
    pathSegments.addAll(
      segments
          .sublist(0, segments.length - 1)
          .map((segment) => StringConverter.snakeCaseToCamelCase(segment)),
    );

    // Add file name
    pathSegments.add(fileNameCamelCase);

    return 'Assets.${pathSegments.join('.')}';
  }

  static _PathInfo? _parsePath(String assetPath) {
    if (assetPath.startsWith('lib/assets/')) {
      return _PathInfo(
        pathWithoutPrefix: assetPath.substring(10),
        isLibAssets: true,
      );
    } else if (assetPath.startsWith('assets/')) {
      return _PathInfo(
        pathWithoutPrefix: assetPath.substring(7),
        isLibAssets: false,
      );
    }
    return null;
  }
}

class _PathInfo {
  final String pathWithoutPrefix;
  final bool isLibAssets;

  _PathInfo({required this.pathWithoutPrefix, required this.isLibAssets});
}

/// Builds replacement string for flutter_gen
class ReplacementBuilder {
  static String build(String flutterGenPath, List<String> remainingArgs, String suffix) {
    if (remainingArgs.isEmpty) {
      return '$flutterGenPath.$suffix()';
    }
    return '$flutterGenPath.$suffix(${remainingArgs.join(', ')})';
  }
}

/// String conversion utilities
class StringConverter {
  static String snakeCaseToCamelCase(String input) {
    if (input.isEmpty) return input;

    final parts = input.split('_');
    if (parts.length == 1) return input;

    final result = StringBuffer(parts[0]);
    for (var i = 1; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        result.write(parts[i][0].toUpperCase());
        if (parts[i].length > 1) {
          result.write(parts[i].substring(1));
        }
      }
    }

    return result.toString();
  }
}
