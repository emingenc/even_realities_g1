/// G1 Protocol Commands
///
/// Command bytes used for communication with Even Realities G1 glasses.
/// Each command is sent as the first byte of a packet to indicate the operation type.
class G1Commands {
  G1Commands._();

  /// Start AI/voice assistant mode
  static const int startAI = 0xF5;

  /// Open/close microphone
  static const int openMic = 0x0E;

  /// Microphone response
  static const int micResponse = 0x0E;

  /// Receive microphone data
  static const int receiveMicData = 0xF1;

  /// Initialize glasses
  static const int init = 0x4D;

  /// Heartbeat to keep connection alive
  static const int heartbeat = 0x25;

  /// Send text result to display
  static const int sendResult = 0x4E;

  /// Quick note list notification
  static const int quickNote = 0x21;

  /// Quick note add/modify/delete
  static const int quickNoteAdd = 0x1E;

  /// Dashboard update command
  static const int dashboard = 0x22;

  /// Send notification to glasses
  static const int notification = 0x4B;

  /// Toggle silent mode
  static const int silentMode = 0x03;

  /// Set brightness level
  static const int brightness = 0x01;

  /// Set dashboard position
  static const int dashboardPosition = 0x26;

  /// Set head-up display angle
  static const int headUpAngle = 0x0B;

  /// Enable/disable head-up display
  static const int headUpDisplay = 0x0C;

  /// Sync time command
  static const int syncTime = 0x09;

  /// Show/hide dashboard
  static const int dashboardShow = 0x06;

  /// Glass wear detection
  static const int glassWear = 0x27;

  /// Send bitmap image
  static const int bmp = 0x15;

  /// CRC checksum
  static const int crc = 0x16;

  /// Setup/configuration
  static const int setup = 0x04;

  /// Navigation command
  static const int navigation = 0x0A;

  /// Clear screen
  static const int clearScreen = 0x18;

  /// Packet end marker
  static const int packetEnd = 0x20;

  /// Translation command
  static const int translate = 0x50;

  /// Original text (translation)
  static const int translateOriginal = 0x0F;

  /// Translated text
  static const int translateResult = 0x0D;

  /// Language setup (translation)
  static const int translateLanguage = 0x1C;

  /// Translate setup
  static const int translateSetup = 0x39;
}

/// AI/Even AI subcommands
class G1AISubCommands {
  G1AISubCommands._();

  /// Exit to dashboard manually
  static const int exitToDashboard = 0x00;

  /// Page control (up/down)
  static const int pageControl = 0x01;

  /// Start wake word detection
  static const int startWakeWord = 0x02;

  /// Stop wake word detection
  static const int stopWakeWord = 0x03;

  /// Start Even AI recording
  static const int startRecording = 0x17; // 23

  /// Stop Even AI recording
  static const int stopRecording = 0x18; // 24
}

/// Response status codes
class G1ResponseStatus {
  G1ResponseStatus._();

  /// Command executed successfully
  static const int success = 0xC9;

  /// Command execution failed
  static const int failure = 0xCA;
}

/// Screen status flags for text display
class G1ScreenStatus {
  G1ScreenStatus._();

  /// AI is displaying content
  static const int displaying = 0x20;

  /// AI display complete
  static const int displayComplete = 0x40;

  /// New content flag
  static const int newContent = 0x10;

  /// Hide screen
  static const int hideScreen = 0x00;

  /// Show screen
  static const int showScreen = 0x01;
}

/// Note subcommands for voice notes
class G1NoteSubCommands {
  G1NoteSubCommands._();

  /// Request audio info
  static const int requestAudioInfo = 0x01;

  /// Request audio data
  static const int requestAudioData = 0x02;

  /// Delete audio stream
  static const int deleteAudioStream = 0x04;

  /// Delete all notes
  static const int deleteAll = 0x05;
}
