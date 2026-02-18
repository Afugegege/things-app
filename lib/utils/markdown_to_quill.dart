
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Converts basic Markdown text into a Quill Document.
/// We return a Document to avoid requiring the 'Delta' type explicitly, 
/// which isn't always exported by the package.
///
/// Usage:
/// final doc = markdownToQuill(text);
/// final delta = doc.toDelta(); // Get Delta
/// final json = delta.toJson(); // Get JSON
quill.Document markdownToQuill(String markdown) {
  final List<Map<String, dynamic>> ops = [];
  final lines = markdown.split('\n');

  for (var line in lines) {
    String content = line;
    Map<String, dynamic>? attributes;

    // 1. Check Block Styles
    if (content.startsWith('# ')) {
      content = content.substring(2);
      attributes = {'header': 1};
    } else if (content.startsWith('## ')) {
      content = content.substring(3);
      attributes = {'header': 2};
    } else if (content.startsWith('### ')) {
      content = content.substring(4);
      attributes = {'header': 3};
    } else if (content.trimLeft().startsWith('- ') || content.trimLeft().startsWith('* ')) {
      content = content.trimLeft().substring(2);
      attributes = {'list': 'bullet'};
    } else {
      final orderedMatch = RegExp(r'^\d+\.\s').firstMatch(content.trimLeft());
      if (orderedMatch != null) {
        content = content.trimLeft().substring(orderedMatch.end);
        attributes = {'list': 'ordered'};
      }
    }

    // 2. Parse Inline Styles (Bold, Italic) -> Add multiple ops
    _parseInlineAndAddOps(ops, content);

    // 3. Add Newline with block attributes
    ops.add({'insert': '\n', 'attributes': attributes});
  }
  
  // Ensure the document ends with a newline (Quill requirement)
  // Our loop adds newline after every line, so we are good.
  // Unless input was empty?
  if (ops.isEmpty) {
    ops.add({'insert': '\n'});
  }

  return quill.Document.fromJson(ops);
}

void _parseInlineAndAddOps(List<Map<String, dynamic>> ops, String text) {
  final boldRegex = RegExp(r'\*\*(.*?)\*\*');
  
  int currentIndex = 0;
  final matches = boldRegex.allMatches(text);
  
  for (final match in matches) {
    if (match.start > currentIndex) {
      _processItalicsAndAddOps(ops, text.substring(currentIndex, match.start));
    }
    
    final boldText = match.group(1) ?? "";
    _processItalicsAndAddOps(ops, boldText, isBold: true);
    
    currentIndex = match.end;
  }
  
  if (currentIndex < text.length) {
    _processItalicsAndAddOps(ops, text.substring(currentIndex));
  }
}

void _processItalicsAndAddOps(List<Map<String, dynamic>> ops, String text, {bool isBold = false}) {
  final italicRegex = RegExp(r'\*(.*?)\*');
  
  int currentIndex = 0;
  final matches = italicRegex.allMatches(text);
  
  for (final match in matches) {
    if (match.start > currentIndex) {
      final segment = text.substring(currentIndex, match.start);
      final attrs = isBold ? {'bold': true} : null;
      _addOp(ops, segment, attrs);
    }
    
    final italicText = match.group(1) ?? "";
    final attrs = <String, dynamic>{'italic': true};
    if (isBold) attrs['bold'] = true;
    
    _addOp(ops, italicText, attrs);
    
    currentIndex = match.end;
  }
  
  if (currentIndex < text.length) {
    final segment = text.substring(currentIndex);
    final attrs = isBold ? {'bold': true} : null;
    _addOp(ops, segment, attrs);
  }
}

void _addOp(List<Map<String, dynamic>> ops, String text, Map<String, dynamic>? attributes) {
  if (text.isEmpty) return;
  final op = <String, dynamic>{'insert': text};
  if (attributes != null) {
    op['attributes'] = attributes;
  }
  ops.add(op);
}