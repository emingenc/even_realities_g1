import '../bluetooth/g1_manager.dart';
import '../models/calendar_model.dart';

/// Dashboard layout options
enum G1DashboardLayout {
  full([0x08, 0x06, 0x00, 0x00]),
  dual([0x1E, 0x06, 0x01, 0x00]),
  minimal([0x31, 0x06, 0x02, 0x00]);

  final List<int> command;
  const G1DashboardLayout(this.command);
}

/// G1 Dashboard feature for managing the dashboard display.
class G1Dashboard {
  final G1Manager _manager;

  static const List<int> _dashboardChangeCommand = [0x06, 0x07, 0x00];

  G1Dashboard(this._manager);

  /// Set the dashboard layout.
  Future<void> setLayout(G1DashboardLayout layout) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final command = [..._dashboardChangeCommand, ...layout.command];
    await _manager.sendCommand(command);
  }

  /// Show the dashboard.
  Future<void> show() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Dashboard show command
    await _manager.sendCommand([0x06, 0x01]);
  }

  /// Hide the dashboard.
  Future<void> hide() async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    // Dashboard hide command
    await _manager.sendCommand([0x06, 0x00]);
  }

  /// Show a calendar event on the dashboard.
  Future<void> showCalendar(G1CalendarModel calendar) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand(calendar.buildDashboardCommand());
  }
}
