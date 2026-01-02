/// Utility class for converting emojis to ASCII representations.
///
/// G1 glasses have limited character support, so emojis need to be
/// converted to ASCII approximations.
class EmojiConverter {
  EmojiConverter._();

  static final Map<String, String> _emojiToAsciiMap = {
    '😀': ':D',
    '😁': ':D',
    '😂': ':\'D',
    '🤣': ':\'D',
    '😃': ':)',
    '😄': ':)',
    '😅': ':)',
    '😆': ':D',
    '😉': ';)',
    '😊': ':)',
    '😋': ':P',
    '😎': 'B)',
    '😍': '<3',
    '😘': ':*',
    '😗': ':*',
    '😙': ':*',
    '😚': ':*',
    '🙂': ':)',
    '🤗': '(:',
    '🤔': ':/',
    '😐': ':|',
    '😑': '-_-',
    '😶': '-_-',
    '🙄': '>:(',
    '😏': ':]',
    '😣': '>:(',
    '😥': ':(',
    '😮': ':O',
    '🤐': ':X',
    '😯': ':O',
    '😪': '-_-',
    '😫': '>:(',
    '😴': '-_-',
    '😌': ':)',
    '😛': ':P',
    '😜': ';P',
    '😝': ';P',
    '🤤': ':P',
    '😒': ':(',
    '😓': ':(',
    '😔': ':(',
    '😕': ':(',
    '🙃': ':)',
    '😲': ':O',
    '☹️': ':(',
    '🙁': ':(',
    '😖': '>:(',
    '😞': ':(',
    '😟': ':(',
    '😤': '>:(',
    '😢': ':\'(',
    '😭': ':\'(',
    '😦': ':O',
    '😧': ':O',
    '😨': ':O',
    '😩': '>:(',
    '😬': ':S',
    '😰': ':(',
    '😱': ':O',
    '😵': ':O',
    '😡': '>:(',
    '😠': '>:(',
    '🤬': '>:(',
    '😷': ':X',
    '🤒': ':(',
    '🤕': ':(',
    '🤢': ':(',
    '🤮': ':(',
    '🤧': ':(',
    '😇': 'O:)',
    '🥰': '<3',
    '🥵': ':(',
    '🥶': ':(',
    '🥳': ':D',
    '🥴': ':S',
    '🥺': ':\'(',
    '🤠': ':D',
    '🤡': ':O',
    '🤥': ':(',
    '🤫': ':X',
    '🤭': ':O',
    '🧐': ':O',
    '🤓': ':)',
    '😈': '>:)',
    '👿': '>:(',
    '👹': '>:(',
    '👺': '>:(',
    '💀': ':(',
    '☠️': ':(',
    '👻': ':)',
    '👽': ':)',
    '👾': ':)',
    '🤖': ':)',
    '🎃': ':)',
    '😺': ':)',
    '😸': ':)',
    '😹': ':D',
    '😻': '<3',
    '😼': ':)',
    '😽': ':*',
    '🙀': ':O',
    '😿': ':\'(',
    '😾': '>:(',
    '❤️': '<3',
    '💔': '</3',
    '💕': '<3',
    '💖': '<3',
    '💗': '<3',
    '💘': '<3',
    '💙': '<3',
    '💚': '<3',
    '💛': '<3',
    '💜': '<3',
    '🖤': '<3',
    '💯': '100',
    '💢': '>:(',
    '💥': '*',
    '💦': '~',
    '💨': '~',
    '💫': '*',
    '💬': '...',
    '🗨️': '...',
    '🗯️': '...',
    '💭': '...',
    '👍': '+1',
    '👎': '-1',
    '👌': 'OK',
    '✌️': 'V',
    '🤞': 'X',
    '🤟': 'ILY',
    '🤘': 'ROCK',
    '👋': 'Hi',
    '🖐️': 'Hi',
    '✋': 'Hi',
    '👏': '*clap*',
    '🙌': '*yay*',
    '🙏': '*pray*',
    '✅': '[v]',
    '❌': '[x]',
    '❓': '?',
    '❗': '!',
    '⭐': '*',
    '🌟': '*',
    '✨': '*',
    '🔥': '*fire*',
    '💡': '*idea*',
    '⚠️': '!',
    '🎵': '~',
    '🎶': '~~',
    '➡️': '->',
    '⬅️': '<-',
    '⬆️': '^',
    '⬇️': 'v',
    '↗️': '/^',
    '↘️': 'v\\',
    '↙️': '/v',
    '↖️': '^\\',
    '🔴': '(R)',
    '🟢': '(G)',
    '🔵': '(B)',
    '⚪': '(W)',
    '⚫': '(B)',
    '🟡': '(Y)',
    '🟠': '(O)',
    '🟣': '(P)',
  };

  /// Convert all emojis in text to ASCII representations.
  static String convert(String text) {
    String result = text;
    
    _emojiToAsciiMap.forEach((emoji, ascii) {
      result = result.replaceAll(emoji, ascii);
    });
    
    // Remove any remaining emojis that weren't in our map
    // This regex matches most emoji ranges
    result = result.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}]|'  // Emoticons
        r'[\u{1F300}-\u{1F5FF}]|'  // Misc Symbols and Pictographs
        r'[\u{1F680}-\u{1F6FF}]|'  // Transport and Map
        r'[\u{1F1E0}-\u{1F1FF}]|'  // Flags
        r'[\u{2600}-\u{26FF}]|'    // Misc symbols
        r'[\u{2700}-\u{27BF}]|'    // Dingbats
        r'[\u{FE00}-\u{FE0F}]|'    // Variation Selectors
        r'[\u{1F900}-\u{1F9FF}]|'  // Supplemental Symbols and Pictographs
        r'[\u{1FA00}-\u{1FA6F}]|'  // Chess Symbols
        r'[\u{1FA70}-\u{1FAFF}]|'  // Symbols and Pictographs Extended-A
        r'[\u{231A}-\u{231B}]|'    // Watch, Hourglass
        r'[\u{23E9}-\u{23F3}]|'    // Fast Forward etc.
        r'[\u{23F8}-\u{23FA}]',    // Pause etc.
        unicode: true,
      ),
      '',
    );
    
    return result;
  }

  /// Add a custom emoji to ASCII mapping.
  static void addMapping(String emoji, String ascii) {
    _emojiToAsciiMap[emoji] = ascii;
  }
}
