import 'dart:convert';

import '../bluetooth/g1_manager.dart';
import '../models/calendar_model.dart';
import '../protocol/commands.dart';

/// Dashboard layout options
enum G1DashboardLayout {
  full([0x08, 0x06, 0x00, 0x00]),
  dual([0x1E, 0x06, 0x01, 0x00]),
  minimal([0x31, 0x06, 0x02, 0x00]);

  final List<int> command;
  const G1DashboardLayout(this.command);
}

/// Dashboard mode (Full, Dual, Minimal)
enum G1DashboardModeType {
  /// Full dashboard with all panes
  full(0x00),

  /// Dual pane view
  dual(0x01),

  /// Minimal view (time only)
  minimal(0x02);

  final int value;
  const G1DashboardModeType(this.value);
}

/// Secondary pane to show on dashboard
enum G1DashboardPane {
  /// Quick notes pane
  notes(0x00),

  /// Stock/graph pane
  stock(0x01),

  /// News pane
  news(0x02),

  /// Calendar pane
  calendar(0x03),

  /// Map pane
  map(0x04),

  /// Empty/none
  empty(0x05);

  final int value;
  const G1DashboardPane(this.value);
}

/// Stock data point for graph display
class G1StockDataPoint {
  final double value;
  final String? label;

  const G1StockDataPoint({required this.value, this.label});
}

/// News item for news pane
class G1NewsItem {
  final String headline;
  final String source;
  final String time;

  const G1NewsItem({
    required this.headline,
    required this.source,
    required this.time,
  });
}

/// G1 Dashboard feature for managing the dashboard display.
class G1Dashboard {
  final G1Manager _manager;
  int _dashboardSeq = 0;

  static const List<int> _dashboardChangeCommand = [0x06, 0x07, 0x00];

  G1Dashboard(this._manager);

  int _nextSeq() {
    final seq = _dashboardSeq;
    _dashboardSeq = (_dashboardSeq + 1) % 256;
    return seq;
  }

  /// Set the dashboard layout.
  Future<void> setLayout(G1DashboardLayout layout) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final command = [..._dashboardChangeCommand, ...layout.command];
    await _manager.sendCommand(command);
  }

  /// Show the dashboard at the specified position.
  ///
  /// This activates the dashboard display using the hardware set command.
  /// Matches Python implementation: construct_dashboard_show_state
  ///
  /// [position] - Dashboard display position (0-8, default 0)
  Future<void> show({int position = 0}) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Python: [Command.DASHBOARD_POSITION, 0x07, 0x00, 0x01, 0x02, state_value, position]
    // Command 0x26 with state ON (0x01)
    final command = [
      G1Commands.dashboardPosition, // 0x26
      0x07, // length
      0x00, // padding
      0x01, // fixed byte
      0x02, // fixed byte
      0x01, // state: ON
      position.clamp(0, 8), // position 0-8
    ];
    await _manager.sendCommand(command);
  }


  /// Hide the dashboard.
  ///
  /// This hides the dashboard display using the hardware set command.
  /// Sends to left glass first, waits 1 second, then sends to right glass
  /// for smooth visual transition.
  ///
  /// [position] - Dashboard display position (0-8, default 0)
  /// [delay] - Delay between left and right glass commands (default 1 second)
  Future<void> hide({
    int position = 0,
    Duration delay = const Duration(seconds: 1),
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Python: [Command.DASHBOARD_POSITION, 0x07, 0x00, 0x01, 0x02, state_value, position]
    // Command 0x26 with state OFF (0x00)
    final command = [
      G1Commands.dashboardPosition, // 0x26
      0x07, // length
      0x00, // padding
      0x01, // fixed byte
      0x02, // fixed byte
      0x00, // state: OFF
      position.clamp(0, 8), // position 0-8
    ];

    // Send to left glass first
    if (_manager.leftGlass != null) {
      await _manager.leftGlass!.sendData(command);
    }

    // Wait for delay
    await Future.delayed(delay);

    // Then send to right glass
    if (_manager.rightGlass != null) {
      await _manager.rightGlass!.sendData(command);
    }
  }

  /// Set dashboard mode and secondary pane.
  ///
  /// [mode] - Dashboard mode (full, dual, minimal)
  /// [secondaryPane] - Which pane to show (only used in full/dual mode)
  Future<void> setPaneMode({
    required G1DashboardModeType mode,
    G1DashboardPane secondaryPane = G1DashboardPane.notes,
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Pane Mode Set: 06 07 00 [seq] 06 [mode] [pane]
    final seq = _nextSeq();
    await _manager.sendCommand([
      G1Commands.dashboardShow,
      0x07, // length
      0x00, // padding
      seq,
      0x06, // subcommand: Pane Mode Set
      mode.value,
      secondaryPane.value,
    ]);
  }

  /// Switch to show the Notes pane on the dashboard.
  ///
  /// Sets the dashboard to dual layout which shows the notes pane.
  Future<void> showNotesPane() async {
    // Use DUAL layout to show notes pane (matches fahrplan reference)
    await setLayout(G1DashboardLayout.dual);
  }

  /// Switch to show the Calendar pane on the dashboard.
  ///
  /// Sets the dashboard to full layout which shows calendar pane.
  Future<void> showCalendarPane() async {
    // Use FULL layout to show calendar pane (matches fahrplan reference)
    await setLayout(G1DashboardLayout.full);
  }

  /// Switch to show the News pane on the dashboard.
  Future<void> showNewsPane() async {
    await setPaneMode(
      mode: G1DashboardModeType.full,
      secondaryPane: G1DashboardPane.news,
    );
  }

  /// Switch to show the Stock/Graph pane on the dashboard.
  Future<void> showStockPane() async {
    await setPaneMode(
      mode: G1DashboardModeType.full,
      secondaryPane: G1DashboardPane.stock,
    );
  }

  /// Switch to show the Map pane on the dashboard.
  Future<void> showMapPane() async {
    await setPaneMode(
      mode: G1DashboardModeType.full,
      secondaryPane: G1DashboardPane.map,
    );
  }

  /// Show a calendar event on the dashboard.
  ///
  /// This sets the dashboard to full layout and displays the calendar event.
  Future<void> showCalendar(G1CalendarModel calendar) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // First set dashboard to full layout (matches fahrplan reference)
    await setLayout(G1DashboardLayout.full);
    
    // Then send the calendar item
    await _manager.sendCommand(calendar.buildDashboardCommand());
  }

  /// Set calendar pane data with multiple events.
  ///
  /// [events] - List of calendar events to display
  Future<void> setCalendarPaneData(List<G1CalendarModel> events) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    if (events.isEmpty) return;

    // Build event entries
    final eventBytes = <int>[];
    for (final event in events) {
      // Title (field 0x01)
      final titleBytes = utf8.encode(event.name);
      eventBytes.add(0x01);
      eventBytes.add(titleBytes.length);
      eventBytes.addAll(titleBytes);

      // Time (field 0x02)
      final timeBytes = utf8.encode(event.time);
      eventBytes.add(0x02);
      eventBytes.add(timeBytes.length);
      eventBytes.addAll(timeBytes);

      // Location (field 0x03)
      final locationBytes = utf8.encode(event.location);
      eventBytes.add(0x03);
      eventBytes.add(locationBytes.length);
      eventBytes.addAll(locationBytes);
    }

    // Pane Calendar Set: 06 [len] 00 [seq] 03 [totalChunks] 00 [chunkIdx] 00 [data...]
    final seq = _nextSeq();
    final payload = <int>[
      0x03, // subcommand: Pane Calendar Set
      0x01, // total chunks
      0x00,
      0x01, // chunk index (1-based)
      0x00,
      0x01, 0x03, 0x03, // fixed header
      events.length,
      ...eventBytes,
    ];

    final length = payload.length + 3; // +3 for len byte, pad, seq
    await _manager.sendCommand([
      G1Commands.dashboardShow,
      length,
      0x00,
      seq,
      ...payload,
    ]);
  }

  /// Set news pane data with headlines.
  ///
  /// [items] - List of news items to display
  Future<void> setNewsPaneData(List<G1NewsItem> items) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    if (items.isEmpty) return;

    final itemBytes = <int>[];
    for (final item in items) {
      final headlineBytes = utf8.encode(item.headline);
      final sourceBytes = utf8.encode(item.source);
      final timeBytes = utf8.encode(item.time);

      itemBytes.add(0x01);
      itemBytes.add(headlineBytes.length);
      itemBytes.addAll(headlineBytes);

      itemBytes.add(0x02);
      itemBytes.add(sourceBytes.length);
      itemBytes.addAll(sourceBytes);

      itemBytes.add(0x03);
      itemBytes.add(timeBytes.length);
      itemBytes.addAll(timeBytes);
    }

    // Pane News Set: 06 [len] 00 [seq] 05 ...
    final seq = _nextSeq();
    final payload = <int>[
      0x05, // subcommand: Pane News Set
      0x01, // total chunks
      0x00,
      0x01, // chunk index
      0x00,
      ...itemBytes,
    ];

    final length = payload.length + 3;
    await _manager.sendCommand([
      G1Commands.dashboardShow,
      length,
      0x00,
      seq,
      ...payload,
    ]);
  }

  /// Set stock/graph pane data.
  ///
  /// [title] - Graph title (e.g., "AAPL")
  /// [currentValue] - Current value string (e.g., "$150.25")
  /// [change] - Change string (e.g., "+2.5%")
  /// [dataPoints] - List of data points for the graph
  Future<void> setStockPaneData({
    required String title,
    required String currentValue,
    required String change,
    List<G1StockDataPoint> dataPoints = const [],
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final titleBytes = utf8.encode(title);
    final valueBytes = utf8.encode(currentValue);
    final changeBytes = utf8.encode(change);

    // Pane Stock Set: 06 [len] 00 [seq] 04 ...
    final seq = _nextSeq();
    final payload = <int>[
      0x04, // subcommand: Pane Stock Set
      0x01, // total chunks
      0x00,
      0x01, // chunk index
      0x00,
      0x01, titleBytes.length, ...titleBytes,
      0x02, valueBytes.length, ...valueBytes,
      0x03, changeBytes.length, ...changeBytes,
    ];

    // Add data points if provided
    if (dataPoints.isNotEmpty) {
      payload.add(0x04); // data points field
      payload.add(dataPoints.length);
      for (final point in dataPoints) {
        // Encode value as fixed-point (value * 100)
        final intVal = (point.value * 100).round();
        payload.add((intVal >> 8) & 0xFF);
        payload.add(intVal & 0xFF);
      }
    }

    final length = payload.length + 3;
    await _manager.sendCommand([
      G1Commands.dashboardShow,
      length,
      0x00,
      seq,
      ...payload,
    ]);
  }
}
