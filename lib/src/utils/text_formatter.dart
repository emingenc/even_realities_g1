/// Utility class for formatting text for G1 display.
///
/// Handles line wrapping, pagination, and width calculations
/// for the G1 display.
class TextFormatter {
  TextFormatter._();

  /// Display width in pixels
  static const int displayWidth = 488;

  /// Lines per screen/page
  static const int linesPerScreen = 5;

  /// Maximum chunk size for transmission
  static const int maxChunkSize = 176;

  /// Approximate character width in pixels
  static const int charWidth = 12;

  /// Calculate approximate text width in pixels.
  static int calculateTextWidth(String text) {
    return text.length * charWidth;
  }

  /// Split text into lines based on display width.
  ///
  /// [text] - The text to split
  /// [maxWidth] - Maximum width in pixels
  /// [margin] - Margin in character widths
  static List<String> splitIntoLines(
    String text, {
    int maxWidth = displayWidth,
    int margin = 5,
  }) {
    // Calculate effective width
    final marginWidth = margin * charWidth;
    final effectiveWidth = maxWidth - (2 * marginWidth);

    // Replace special symbols
    text = text.replaceAll('⬆', '^').replaceAll('⟶', '-');

    final lines = <String>[];

    if (text.isEmpty || text == ' ') {
      lines.add(text);
      return lines;
    }

    // Split by newlines first
    final rawLines = text.split('\n');

    for (final rawLine in rawLines) {
      if (rawLine.isEmpty) {
        lines.add('');
        continue;
      }

      int startIndex = 0;
      final lineLength = rawLine.length;

      while (startIndex < lineLength) {
        int endIndex = lineLength;
        final lineWidth = _calculateSubstringWidth(rawLine, startIndex, endIndex);

        if (lineWidth <= effectiveWidth) {
          lines.add(rawLine.substring(startIndex));
          break;
        }

        // Binary search for maximum characters that fit
        int left = startIndex + 1;
        int right = lineLength;
        int bestSplitIndex = startIndex + 1;

        while (left <= right) {
          final mid = left + ((right - left) ~/ 2);
          final width = _calculateSubstringWidth(rawLine, startIndex, mid);

          if (width <= effectiveWidth) {
            bestSplitIndex = mid;
            left = mid + 1;
          } else {
            right = mid - 1;
          }
        }

        // Find a good place to break (preferably at a space)
        int splitIndex = bestSplitIndex;
        bool foundSpace = false;

        for (int i = bestSplitIndex; i > startIndex; i--) {
          if (rawLine[i - 1] == ' ') {
            splitIndex = i;
            foundSpace = true;
            break;
          }
        }

        if (!foundSpace && bestSplitIndex - startIndex > 2) {
          splitIndex = bestSplitIndex;
        }

        final line = rawLine.substring(startIndex, splitIndex).trim();
        lines.add(line);

        // Skip spaces at beginning of next line
        while (splitIndex < lineLength && rawLine[splitIndex] == ' ') {
          splitIndex++;
        }

        startIndex = splitIndex;
      }
    }

    return lines;
  }

  static int _calculateSubstringWidth(String text, int start, int end) {
    return calculateTextWidth(text.substring(start, end));
  }

  /// Add margin/indentation to lines.
  static String addMargins(List<String> lines, {int margin = 5}) {
    final buffer = StringBuffer();
    final indentation = ' ' * margin;

    for (final line in lines) {
      buffer.write(indentation);
      buffer.write(line);
      buffer.write('\n');
    }

    return buffer.toString();
  }

  /// Calculate total number of pages for text.
  static int calculatePageCount(List<String> lines) {
    return (lines.length / linesPerScreen).ceil();
  }

  /// Get lines for a specific page.
  static List<String> getLinesForPage(List<String> lines, int page) {
    final startLine = page * linesPerScreen;
    final endLine = (startLine + linesPerScreen).clamp(0, lines.length);

    if (startLine >= lines.length) {
      return [];
    }

    return lines.sublist(startLine, endLine);
  }

  /// Format text for a line with max characters.
  static List<String> formatTextByLength(String text, {int maxLength = 20}) {
    final words = text.split(' ');
    final lines = <String>[];
    String currentLine = '';

    for (final word in words) {
      if ((currentLine + word).length <= maxLength) {
        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }
        currentLine = word;
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }
}
