import 'package:flutter/material.dart';
import 'package:even_realities_g1/even_realities_g1.dart';

void main() {
  runApp(const G1ExampleApp());
}

class G1ExampleApp extends StatelessWidget {
  const G1ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'G1 Glasses Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const G1ExampleHome(),
    );
  }
}

class G1ExampleHome extends StatefulWidget {
  const G1ExampleHome({super.key});

  @override
  State<G1ExampleHome> createState() => _G1ExampleHomeState();
}

class _G1ExampleHomeState extends State<G1ExampleHome> {
  final G1Manager _manager = G1Manager();
  G1ConnectionState _connectionState = G1ConnectionState.disconnected;
  String _status = 'Not connected';
  int _messageId = 0;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _manager.onConnectionChanged = (state, side) {
      setState(() {
        _connectionState = state;
        _status = _getStatusText(state);
      });
    };
  }

  String _getStatusText(G1ConnectionState state) {
    switch (state) {
      case G1ConnectionState.disconnected:
        return 'Disconnected';
      case G1ConnectionState.scanning:
        return 'Scanning for glasses...';
      case G1ConnectionState.connecting:
        return 'Connecting...';
      case G1ConnectionState.connected:
        return _manager.isBothConnected
            ? 'Both glasses connected'
            : 'One glass connected';
      case G1ConnectionState.error:
        return 'Connection error';
    }
  }

  Future<void> _scan() async {
    await _manager.startScan();
  }

  Future<void> _disconnect() async {
    await _manager.disconnect();
  }

  Future<void> _sendNotification() async {
    if (!_manager.isConnected) return;

    await _manager.notifications.send(
      G1NotificationModel(
        messageId: _messageId++,
        appIdentifier: 'dev.example.g1demo',
        displayName: 'G1 Example',
        title: 'Hello G1!',
        message: 'This is a test notification from the example app.',
      ),
    );
  }

  Future<void> _showText() async {
    if (!_manager.isConnected) return;

    await _manager.display.showText(
      'Welcome to Even Realities G1!\n\n'
      'This library provides full control over your smart glasses.',
    );
  }

  Future<void> _syncTimeWeather() async {
    if (!_manager.isConnected) return;

    // Sync with OpenWeatherMap (requires API key)
    // await _manager.timeWeather.syncFromOpenWeatherMap(
    //   latitude: 52.52,
    //   longitude: 13.405,
    //   apiKey: 'YOUR_API_KEY',
    // );

    // Or sync manually
    await _manager.timeWeather.sync(G1WeatherModel(
      weatherIcon: G1WeatherIcon.sunny,
      temperatureInCelsius: 22,
    ));
  }

  Future<void> _showDashboard() async {
    if (!_manager.isConnected) return;

    await _manager.dashboard.showCalendar(
      G1CalendarModel(
        name: 'Team Meeting',
        time: '14:00',
        location: 'Room 101',
      ),
    );
  }

  Future<void> _addQuickNote() async {
    if (!_manager.isConnected) return;

    await _manager.notes.add(G1NoteModel(
      noteNumber: 1,
      name: 'Reminder',
      text: 'Remember to buy groceries',
    ));
  }

  Future<void> _startNavigation() async {
    if (!_manager.isConnected) return;

    // First initialize navigation
    await _manager.navigation.start();

    // Then show directions
    await _manager.navigation.showDirections(G1NavigationModel(
      turn: G1NavigationTurn.left,
      direction: 'Turn left',
      distance: '500m',
      speed: '30 km/h',
      totalDuration: '15 min',
      totalDistance: '5.2 km',
    ));
  }

  Future<void> _stopNavigation() async {
    if (!_manager.isConnected) return;

    await _manager.navigation.stop();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectionState == G1ConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('G1 Glasses Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                      size: 48,
                      color: isConnected ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _connectionState == G1ConnectionState.scanning
                              ? null
                              : _scan,
                          icon: const Icon(Icons.search),
                          label: const Text('Scan'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: isConnected ? _disconnect : null,
                          icon: const Icon(Icons.bluetooth_disabled),
                          label: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Features
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _FeatureButton(
                    icon: Icons.notifications,
                    label: 'Notification',
                    onPressed: isConnected ? _sendNotification : null,
                  ),
                  _FeatureButton(
                    icon: Icons.text_fields,
                    label: 'Show Text',
                    onPressed: isConnected ? _showText : null,
                  ),
                  _FeatureButton(
                    icon: Icons.cloud,
                    label: 'Time & Weather',
                    onPressed: isConnected ? _syncTimeWeather : null,
                  ),
                  _FeatureButton(
                    icon: Icons.dashboard,
                    label: 'Dashboard',
                    onPressed: isConnected ? _showDashboard : null,
                  ),
                  _FeatureButton(
                    icon: Icons.note_add,
                    label: 'Quick Note',
                    onPressed: isConnected ? _addQuickNote : null,
                  ),
                  _FeatureButton(
                    icon: Icons.navigation,
                    label: 'Start Nav',
                    onPressed: isConnected ? _startNavigation : null,
                  ),
                  _FeatureButton(
                    icon: Icons.navigation_outlined,
                    label: 'Stop Nav',
                    onPressed: isConnected ? _stopNavigation : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }
}

class _FeatureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _FeatureButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: onPressed != null ? 1.0 : 0.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
