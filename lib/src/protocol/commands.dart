/// G1 Protocol Commands
///
/// Command bytes used for communication with Even Realities G1 glasses.
/// Each command is sent as the first byte of a packet to indicate the operation type.
class G1Commands {
  G1Commands._();

  /// Start AI/voice assistant mode
  static const int startAI = 0xF5;

  /// Event stream from device (shares 0xF5 command byte)
  static const int event = 0xF5;

  /// Open/close microphone
  static const int openMic = 0x0E;

  /// Microphone response
  static const int micResponse = 0x0E;

  /// Receive microphone data
  static const int receiveMicData = 0xF1;

  /// Debug log messages (device -> host)
  static const int debug = 0xF4;

  /// MTU set (wiki: 0x4D FB to request 251)
  ///
  /// Kept as `init` for backwards-compatibility with earlier versions.
  static const int init = 0x4D;

  /// MTU set (alias of `init`)
  static const int mtuSet = 0x4D;

  /// Heartbeat to keep connection alive
  static const int heartbeat = 0x25;

  /// Send text result to display
  static const int sendResult = 0x4E;

  /// Text set (alias of `sendResult`)
  static const int textSet = 0x4E;

  /// Quick note list notification
  static const int quickNote = 0x21;

  /// Quick note add/modify/delete
  static const int quickNoteAdd = 0x1E;

  /// Dashboard update command
  static const int dashboard = 0x22;

  /// Send notification to glasses
  static const int notification = 0x4B;

  /// Clear a notification by message id
  static const int notificationClear = 0x4C;

  /// Notification auto display configuration
  static const int notificationAutoDisplay = 0x4F;

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
  ///
  /// Note: the wiki uses 0x09 for Teleprompter Control; time/weather updates are
  /// typically done via Dashboard Set (0x06) subcommands.
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

  /// System control command group
  static const int systemControl = 0x23;

  /// Hardware settings (0x26)
  static const int hardwareSet = 0x26;

  /// Hardware get (0x3F)
  static const int hardwareGet = 0x3F;

  /// Hardware display get (0x3B)
  static const int hardwareDisplayGet = 0x3B;

  /// Head up action set (0x08)
  static const int headUpAction = 0x08;

  /// Language set (0x3D)
  static const int languageSet = 0x3D;

  /// Info battery and firmware get (0x2C)
  static const int infoBatteryFirmware = 0x2C;

  /// Wear detection set (0x27)
  static const int wearDetection = 0x27;

  /// Wear detection get (0x3A)
  static const int wearDetectionGet = 0x3A;

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

/// Hardware Set (0x26) subcommands
class G1HardwareSubCommands {
  G1HardwareSubCommands._();

  /// Set display height and depth
  static const int heightAndDepth = 0x02;

  /// Double tap action setting
  static const int doubleTapAction = 0x04;

  /// Long press action setting
  static const int longPressAction = 0x07;

  /// Activate mic on head lift
  static const int headLiftMic = 0x08;
}

/// Double-tap action options
class G1DoubleTapAction {
  G1DoubleTapAction._();

  /// Close active feature / None
  static const int none = 0x00;

  /// Open Translate
  static const int translate = 0x02;

  /// Open Teleprompter
  static const int teleprompter = 0x03;

  /// Show Dashboard
  static const int dashboard = 0x04;

  /// Open Transcribe
  static const int transcribe = 0x05;
}

/// Head-up action modes
class G1HeadUpAction {
  G1HeadUpAction._();

  /// Show the Dashboard on head lift
  static const int showDashboard = 0x00;

  /// Do nothing on head lift
  static const int doNothing = 0x02;
}

/// Dashboard mode options
class G1DashboardMode {
  G1DashboardMode._();

  /// Full dashboard view
  static const int full = 0x00;

  /// Dual pane view
  static const int dual = 0x01;

  /// Minimal view
  static const int minimal = 0x02;
}

/// Secondary pane options for dashboard
class G1SecondaryPane {
  G1SecondaryPane._();

  /// Notes pane
  static const int notes = 0x00;

  /// Stock/graph pane
  static const int stock = 0x01;

  /// News pane
  static const int news = 0x02;

  /// Calendar pane
  static const int calendar = 0x03;

  /// Map pane
  static const int map = 0x04;

  /// Empty pane
  static const int empty = 0x05;
}

/// System Control (0x23) subcommands
class G1SystemControlSubCommands {
  G1SystemControlSubCommands._();

  /// Enable/disable debug logging (0x6C)
  static const int debugLogging = 0x6C;

  /// Reboot the glasses (0x72)
  static const int reboot = 0x72;

  /// Get firmware build info (0x74)
  static const int firmwareBuildInfo = 0x74;
}

/// System Language IDs for Language Set (0x3D)
///
/// Note: This is different from G1Language in g1_translate.dart which uses
/// string codes for translation features.
class G1SystemLanguage {
  G1SystemLanguage._();

  static const int chinese = 0x01;
  static const int english = 0x02;
  static const int japanese = 0x03;
  static const int french = 0x05;
  static const int german = 0x06;
  static const int spanish = 0x07;
  static const int italian = 0x0E;
}
