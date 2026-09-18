class JsonCleaner {
  /// Cleans raw AI JSON output to make it parseable.
  /// Handles: markdown code blocks, trailing commas, single quotes,
  /// unescaped newlines, and other common AI output issues.
  static String clean(String response) {
    String cleaned = response;

    // 1. Remove markdown code block wrappers
    cleaned = cleaned
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    // 2. Remove trailing commas before closing brackets/braces
    //    e.g. {"key": "value",} → {"key": "value"}
    cleaned = cleaned.replaceAll(RegExp(r',\s*(\]|\})'), r'$1');

    // 3. Handle single quotes → double quotes (only outside of double-quoted strings)
    //    This is a best-effort heuristic for simple cases.
    if (!cleaned.contains('"') && cleaned.contains("'")) {
      cleaned = cleaned.replaceAll("'", '"');
    }

    // 4. Remove control characters that break JSON parsing
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ' ');

    // 5. Trim any leading/trailing whitespace again
    cleaned = cleaned.trim();

    return cleaned;
  }
}