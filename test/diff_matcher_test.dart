import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:dart_quill_delta/dart_quill_delta.dart' as dqd;
import '../lib/utils/diff_matcher.dart';
import '../lib/utils/markdown_to_quill.dart';

void main() {
  group('DiffMatcher tests', () {
    test('findBestMatchRange matches exact and substring phrases', () {
      const doc = 'First line\nTarget paragraph to change\nLast line';
      
      final exactRange = DiffMatcher.findBestMatchRange(doc, 'Target paragraph to change');
      expect(exactRange, isNotNull);
      expect(doc.substring(exactRange!.start, exactRange.end), 'Target paragraph to change');

      final lineRange = DiffMatcher.findBestMatchRange(doc, 'Target paragraph');
      expect(lineRange, isNotNull);
      expect(doc.substring(lineRange!.start, lineRange.end), contains('Target paragraph'));
    });

    test('buildPreviewDocument formats deletion with strike and insertion below', () {
      final initialDoc = markdownToQuill('Line 1\nLine 2 to replace\nLine 3');
      final text = initialDoc.toPlainText();
      final start = text.indexOf('Line 2 to replace');
      final length = 'Line 2 to replace'.length;

      final target = DiffTarget(
        start: start,
        length: length,
        originalText: 'Line 2 to replace',
        suggestedText: 'Line 2 newly improved',
      );

      final previewDoc = DiffMatcher.buildPreviewDocument(
        originalDoc: initialDoc,
        target: target,
      );

      final deltaOps = previewDoc.toDelta().toJson();
      // Check that at least one op has strike: true and deletion color
      final strikeOp = deltaOps.firstWhere(
        (op) => op['attributes'] != null && op['attributes']['strike'] == true,
        orElse: () => <String, dynamic>{},
      );
      expect(strikeOp.isNotEmpty, isTrue);
      expect(strikeOp['insert'], contains('Line 2 to replace'));

      // Check that preview text has addition color
      final additionOp = deltaOps.firstWhere(
        (op) => op['attributes'] != null && op['attributes']['color'] == DiffMatcher.additionColor,
        orElse: () => <String, dynamic>{},
      );
      expect(additionOp.isNotEmpty, isTrue);
      expect(additionOp['insert'], contains('Line 2 newly improved'));
    });

    test('buildCommittedDocument cleanly replaces target range with clean styling', () {
      final initialDoc = markdownToQuill('Line 1\nLine 2 to replace\nLine 3');
      final prePreviewDelta = dqd.Delta.from(initialDoc.toDelta());
      final text = initialDoc.toPlainText();
      final start = text.indexOf('Line 2 to replace');
      final length = 'Line 2 to replace'.length;

      final target = DiffTarget(
        start: start,
        length: length,
        originalText: 'Line 2 to replace',
        suggestedText: 'Line 2 newly improved',
      );

      final committedDoc = DiffMatcher.buildCommittedDocument(
        prePreviewDelta: prePreviewDelta,
        target: target,
      );

      final plain = committedDoc.toPlainText();
      expect(plain, contains('Line 2 newly improved'));
      expect(plain, isNot(contains('Line 2 to replace')));

      // Ensure no leftover strike attributes exist
      final ops = committedDoc.toDelta().toJson();
      final hasStrike = ops.any((op) => op['attributes'] != null && op['attributes']['strike'] == true);
      expect(hasStrike, isFalse);
    });

    test('buildCommittedDocument replaces whole document without duplication', () {
      final initialDoc = markdownToQuill('Original Paragraph 1\nOriginal Paragraph 2\nOriginal Paragraph 3');
      final prePreviewDelta = dqd.Delta.from(initialDoc.toDelta());
      final fullText = initialDoc.toPlainText();

      final target = DiffTarget(
        start: 0,
        length: fullText.length,
        originalText: fullText,
        suggestedText: 'Brand new rewritten note with shiny content',
      );

      final committedDoc = DiffMatcher.buildCommittedDocument(
        prePreviewDelta: prePreviewDelta,
        target: target,
      );

      final plain = committedDoc.toPlainText();
      expect(plain, contains('Brand new rewritten note with shiny content'));
      expect(plain, isNot(contains('Original Paragraph 1')));
      expect(plain, isNot(contains('Original Paragraph 2')));
      expect(plain, isNot(contains('Original Paragraph 3')));
    });
  });
}
