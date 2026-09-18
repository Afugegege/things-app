import 'package:flutter/material.dart';
import 'action_registry.dart';

// ──────────────────────────────────────────────
//  ACTION EXECUTOR
//  Batch-executes confirmed ActionIntents sequentially.
// ──────────────────────────────────────────────

class ActionExecutor {
  /// Executes a list of confirmed ActionIntents sequentially.
  /// Updates each intent's status as it progresses.
  /// Returns a summary of results.
  static Future<List<ActionResult>> executeAll(
    List<ActionIntent> actions,
    BuildContext context, {
    void Function(int index, ActionStatus status)? onProgress,
  }) async {
    final results = <ActionResult>[];

    for (int i = 0; i < actions.length; i++) {
      final intent = actions[i];

      // Skip already executed or errored actions
      if (intent.status == ActionStatus.success || intent.status == ActionStatus.error) {
        continue;
      }

      // Update status to loading
      intent.status = ActionStatus.loading;
      onProgress?.call(i, ActionStatus.loading);

      if (intent.definition == null) {
        intent.status = ActionStatus.error;
        results.add(ActionResult.error('Unknown action: "${intent.action}"'));
        onProgress?.call(i, ActionStatus.error);
        continue;
      }

      // Final validation check
      final errors = intent.definition!.validate(intent.data);
      if (errors.isNotEmpty) {
        intent.status = ActionStatus.error;
        results.add(ActionResult.error('Validation failed: ${errors.join(", ")}'));
        onProgress?.call(i, ActionStatus.error);
        continue;
      }

      try {
        // Small delay for visual feedback
        await Future.delayed(const Duration(milliseconds: 400));

        final result = await intent.definition!.execute(intent.data, context);
        intent.status = result.isSuccess ? ActionStatus.success : ActionStatus.error;
        results.add(result);
        onProgress?.call(i, intent.status);
      } catch (e) {
        intent.status = ActionStatus.error;
        results.add(ActionResult.error(e.toString()));
        onProgress?.call(i, ActionStatus.error);
      }
    }

    return results;
  }

  /// Execute a single action.
  static Future<ActionResult> executeSingle(
    ActionIntent intent,
    BuildContext context,
  ) async {
    final results = await executeAll([intent], context);
    return results.isNotEmpty ? results.first : ActionResult.error('No action to execute');
  }
}
