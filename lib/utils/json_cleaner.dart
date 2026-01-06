class JsonCleaner {
  static String clean(String response) {
    // Removes markdown code blocks and extra whitespace
    return response
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
  }
}