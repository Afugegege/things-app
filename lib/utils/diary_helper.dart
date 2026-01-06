import '../models/chat_model.dart';

class DiaryHelper {
  // 1. The Main Logic (Sleep Threshold)
  static List<ChatMessage> getSessionMessages(List<ChatMessage> allMessages) {
    if (allMessages.isEmpty) return [];

    // Sort: Newest first
    allMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    DateTime? lastSleepTime;
    
    // Scan backwards to find a 4+ hour gap after 4:00 AM
    for (int i = 0; i < allMessages.length - 1; i++) {
      final currentMsgTime = allMessages[i].timestamp;
      final previousMsgTime = allMessages[i + 1].timestamp;
      final gap = currentMsgTime.difference(previousMsgTime);

      if (gap.inHours >= 4 && currentMsgTime.hour >= 4) {
        lastSleepTime = currentMsgTime;
        break; 
      }
    }

    if (lastSleepTime != null) {
      return allMessages.where((msg) => 
        msg.timestamp.isAfter(lastSleepTime!.subtract(const Duration(minutes: 1)))
      ).toList();
    } else {
      // Fallback: Last 24 hours
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      return allMessages.where((msg) => msg.timestamp.isAfter(yesterday)).toList();
    }
  }

  // 2. Alias for compatibility (if your code calls getLogsForToday)
  static List<ChatMessage> getLogsForToday(List<ChatMessage> msgs) {
    return getSessionMessages(msgs);
  }

  // 3. String Formatter (Fixes the 'formatForAI' error)
  static String formatForAI(List<ChatMessage> messages) {
    return messages.reversed.map((m) {
      return "[${m.isUser ? 'User' : 'AI'}]: ${m.text}";
    }).join("\n");
  }
}