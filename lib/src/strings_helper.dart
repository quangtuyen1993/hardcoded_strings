import 'package:analyzer/dart/ast/ast.dart';

bool hasIgnoreComment(StringLiteral node) {
  final compilationUnit = node.thisOrAncestorOfType<CompilationUnit>();
  if (compilationUnit == null) return false;

  final lineInfo = compilationUnit.lineInfo;
  final location = lineInfo.getLocation(node.offset);
  final line = location.lineNumber;

  // Check for ignore comment on the same line or the line before
  final source = compilationUnit.toSource();
  final lines = source.split('\n');

  if (line > 0 && line <= lines.length) {
    // Check current line
    final currentLine = lines[line - 1];
    if (_containsIgnoreComment(currentLine)) return true;

    // Check previous line
    if (line > 1) {
      final previousLine = lines[line - 2];
      if (_containsIgnoreComment(previousLine)) return true;
    }
  }

  return false;
}

bool _containsIgnoreComment(String line) {
  final ignorePatterns = [
    RegExp(r'//\s*ignore:\s*avoid_hardcoded_strings_in_widgets'),
    RegExp(r'//\s*ignore_for_file:\s*avoid_hardcoded_strings_in_widgets'),
    RegExp(r'//\s*ignore:\s*hardcoded.string', caseSensitive: false),
    RegExp(r'//\s*hardcoded.ok', caseSensitive: false),
  ];

  return ignorePatterns.any((pattern) => pattern.hasMatch(line));
}
