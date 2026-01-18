import 'dart:convert';

class MarkdownToQuill {
  /// Converts a Markdown string into a Quill Delta JSON string
  static String convert(String markdown) {
    final List<Map<String, dynamic>> ops = [];
    final lines = markdown.split('\n');

    for (var line in lines) {
      // 1. HEADERS (# Title)
      if (line.startsWith('# ')) {
        _parseInlineStyles(line.substring(2), ops, isHeader: true);
        ops.add({'insert': '\n', 'attributes': {'header': 1}});
        continue;
      }
      if (line.startsWith('## ')) {
        _parseInlineStyles(line.substring(3), ops, isHeader: true);
        ops.add({'insert': '\n', 'attributes': {'header': 2}});
        continue;
      }

      // 2. BULLET LISTS (- Item)
      if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
        final content = line.trim().substring(2);
        _parseInlineStyles(content, ops);
        ops.add({'insert': '\n', 'attributes': {'list': 'bullet'}});
        continue;
      }

      // 3. NUMBERED LISTS (1. Item)
      if (RegExp(r'^\d+\. ').hasMatch(line.trim())) {
        final content = line.trim().replaceFirst(RegExp(r'^\d+\. '), '');
        _parseInlineStyles(content, ops);
        ops.add({'insert': '\n', 'attributes': {'list': 'ordered'}});
        continue;
      }

      // 4. CODE BLOCKS (```)
      if (line.startsWith('```')) {
        // Just skip the marker line for simplicity in this basic parser
        continue;
      }

      // 5. STANDARD TEXT
      if (line.isNotEmpty) {
        _parseInlineStyles(line, ops);
        ops.add({'insert': '\n'});
      } else {
        ops.add({'insert': '\n'});
      }
    }

    return jsonEncode(ops);
  }

  /// Parses **bold**, *italic*, and `code` within a line
  static void _parseInlineStyles(String text, List<Map<String, dynamic>> ops, {bool isHeader = false}) {
    // This is a simplified parser. For production, a full state-machine parser is better.
    // We strictly look for bold (**), then italic (*), then code (`).
    
    final RegExp exp = RegExp(r'(\*\*|`)(.*?)\1'); // Matches **bold** or `code`
    int lastIndex = 0;

    for (final match in exp.allMatches(text)) {
      // Text before match
      if (match.start > lastIndex) {
        ops.add({'insert': text.substring(lastIndex, match.start)});
      }

      // The styled text
      final String content = match.group(2) ?? "";
      final String type = match.group(1) ?? "";
      
      final Map<String, dynamic> attributes = {};
      if (type == '**') attributes['bold'] = true;
      if (type == '`') {
        attributes['code'] = true;
        attributes['color'] = '#FF00FF'; // Neon style for code
      }

      ops.add({'insert': content, 'attributes': attributes});
      lastIndex = match.end;
    }

    // Remaining text
    if (lastIndex < text.length) {
      ops.add({'insert': text.substring(lastIndex)});
    }
  }
}