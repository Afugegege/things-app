import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/action_registry.dart';
import '../core/action_executor.dart';
import '../core/ambiguity_resolver.dart';
import 'action_field_builder.dart';

// ──────────────────────────────────────────────
//  ACTION PREVIEW SHEET
//  A single, reusable bottom sheet that renders
//  any number of actions using their schemas.
// ──────────────────────────────────────────────

class ActionPreviewSheet extends StatefulWidget {
  final List<ActionIntent> actions;
  final List<ResolutionSuggestion> suggestions;
  final VoidCallback? onDismiss;
  final void Function(List<ActionResult> results)? onComplete;

  const ActionPreviewSheet({
    super.key,
    required this.actions,
    this.suggestions = const [],
    this.onDismiss,
    this.onComplete,
  });

  /// Shows the preview sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<ActionIntent> actions,
    List<ResolutionSuggestion> suggestions = const [],
    void Function(List<ActionResult> results)? onComplete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ActionPreviewSheet(
        actions: actions,
        suggestions: suggestions,
        onDismiss: () => Navigator.pop(ctx),
        onComplete: (results) {
          onComplete?.call(results);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  State<ActionPreviewSheet> createState() => _ActionPreviewSheetState();
}

class _ActionPreviewSheetState extends State<ActionPreviewSheet> {
  late List<ActionIntent> _actions;
  bool _isExecuting = false;
  List<ActionResult>? _results;

  @override
  void initState() {
    super.initState();
    _actions = List.from(widget.actions);
  }

  void _removeAction(int index) {
    setState(() {
      _actions.removeAt(index);
    });
    if (_actions.isEmpty) {
      widget.onDismiss?.call();
    }
  }

  Future<void> _executeAll() async {
    setState(() => _isExecuting = true);

    final results = await ActionExecutor.executeAll(
      _actions,
      context,
      onProgress: (index, status) {
        if (mounted) setState(() {});
      },
    );

    if (mounted) {
      setState(() {
        _isExecuting = false;
        _results = results;
      });

      // Auto-close after brief delay on success
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        widget.onComplete?.call(results);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final accentColor = theme.primaryColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CupertinoIcons.bolt_fill, size: 14, color: textColor),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI ACTIONS',
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1.1),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_actions.length}',
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (!_isExecuting && _results == null)
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: Icon(CupertinoIcons.xmark_circle_fill,
                        color: secondaryColor.withOpacity(0.5), size: 22),
                  ),
              ],
            ),
          ),

          Container(
            height: 1,
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
          ),

          // ── Actions List ──
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _actions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) => _buildActionCard(index),
            ),
          ),

          // ── Warnings ──
          if (_getWarnings().isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _getWarnings().map((w) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(w,
                              style: TextStyle(color: textColor, fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // ── Bottom Actions ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: _results != null
                ? _buildResultsSummary(textColor, secondaryColor)
                : Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                          onPressed: _isExecuting ? null : widget.onDismiss,
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: textColor,
                          borderRadius: BorderRadius.circular(14),
                          onPressed: _isExecuting ? null : _executeAll,
                          child: _isExecuting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? Colors.black : Colors.white,
                                  ),
                                )
                              : Text(
                                  'Confirm All',
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSummary(Color textColor, Color secondaryColor) {
    final successCount = _results!.where((r) => r.isSuccess).length;
    final errorCount = _results!.where((r) => !r.isSuccess).length;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              errorCount == 0
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.exclamationmark_circle,
              color: errorCount == 0 ? Colors.green : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              errorCount == 0
                  ? '$successCount action${successCount > 1 ? 's' : ''} completed!'
                  : '$successCount completed, $errorCount failed',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  List<String> _getWarnings() {
    return widget.suggestions
        .where((s) => s.type == SuggestionType.autoFilled)
        .map((s) => s.message)
        .toList();
  }

  Widget _buildActionCard(int index) {
    final intent = _actions[index];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final definition = intent.definition;
    final isUnknown = definition == null;
    final errors = definition?.validate(intent.data) ?? [];

    // Status-based colors
    Color statusColor = secondaryColor;
    IconData statusIcon = CupertinoIcons.circle;
    String statusLabel = 'PENDING';

    switch (intent.status) {
      case ActionStatus.loading:
        statusColor = textColor;
        statusIcon = CupertinoIcons.arrow_2_circlepath;
        statusLabel = 'RUNNING...';
        break;
      case ActionStatus.success:
        statusColor = Colors.green;
        statusIcon = CupertinoIcons.check_mark_circled_solid;
        statusLabel = 'DONE';
        break;
      case ActionStatus.error:
        statusColor = Colors.redAccent;
        statusIcon = CupertinoIcons.xmark_circle;
        statusLabel = 'FAILED';
        break;
      default:
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnknown
              ? Colors.redAccent.withOpacity(0.5)
              : (intent.status == ActionStatus.success
                  ? Colors.green.withOpacity(0.3)
                  : (isDark ? Colors.white10 : Colors.black12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header ──
          Row(
            children: [
              Icon(definition?.icon ?? CupertinoIcons.question_circle,
                  size: 16, color: textColor),
              const SizedBox(width: 8),
              Text(
                definition?.displayName ??
                    intent.action.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
              const Spacer(),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 10, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (intent.status == ActionStatus.pending && !_isExecuting) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _removeAction(index),
                  child: Icon(CupertinoIcons.minus_circle,
                      size: 18, color: Colors.redAccent.withOpacity(0.7)),
                ),
              ],
            ],
          ),

          if (isUnknown) ...[
            const SizedBox(height: 10),
            const Text(
              'This action type is not recognized and will be skipped.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],

          // ── Editable Fields ──
          if (definition != null &&
              intent.status == ActionStatus.pending &&
              !_isExecuting) ...[
            const SizedBox(height: 12),
            ...definition.schema.map((field) {
              // Skip the "action" key
              final hasFieldError = errors.any((e) => e.contains(field.label));
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ActionFieldBuilder(
                  schema: field,
                  value: intent.data[field.key],
                  hasError: hasFieldError,
                  onChanged: (newValue) {
                    setState(() {
                      intent.data[field.key] = newValue;
                    });
                  },
                ),
              );
            }),
          ],

          // ── Success summary ──
          if (intent.status == ActionStatus.success && _results != null) ...[
            const SizedBox(height: 8),
            Text(
              _results![index].summary,
              style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ],

          // ── Error details ──
          if (intent.status == ActionStatus.error && _results != null) ...[
            const SizedBox(height: 8),
            Text(
              _results![index].summary,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
