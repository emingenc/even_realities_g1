import '../bluetooth/g1_manager.dart';
import '../models/weather_model.dart';

/// G1 Time & Weather feature for syncing time and weather display.
class G1TimeWeather {
  final G1Manager _manager;

  int _seqId = 0;

  G1TimeWeather(this._manager);

  /// Sync time and weather to the glasses.
  Future<void> sync({
    required int temperatureInCelsius,
    required G1WeatherIcon weatherIcon,
    TemperatureUnit temperatureUnit = TemperatureUnit.celsius,
    TimeFormat timeFormat = TimeFormat.twentyFourHour,
  }) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    final weather = G1WeatherModel(
      temperatureUnit: temperatureUnit,
      timeFormat: timeFormat,
      temperatureInCelsius: temperatureInCelsius,
      weatherIcon: weatherIcon,
    );

    await _manager.sendCommand(weather.buildCommand(_seqId));
    _seqId = (_seqId + 1) % 256;
  }

  /// Sync time and weather using a model.
  Future<void> syncModel(G1WeatherModel weather) async {
    if (!_manager.isConnected) {
      throw StateError('Not connected to glasses');
    }

    await _manager.sendCommand(weather.buildCommand(_seqId));
    _seqId = (_seqId + 1) % 256;
  }

  /// Sync weather from OpenWeatherMap condition code.
  Future<void> syncFromOpenWeatherMap({
    required int temperatureInCelsius,
    required int owpConditionCode,
    TemperatureUnit temperatureUnit = TemperatureUnit.celsius,
    TimeFormat timeFormat = TimeFormat.twentyFourHour,
  }) async {
    final weatherIcon = G1WeatherIcon.fromOpenWeatherMap(owpConditionCode);

    await sync(
      temperatureInCelsius: temperatureInCelsius,
      weatherIcon: weatherIcon,
      temperatureUnit: temperatureUnit,
      timeFormat: timeFormat,
    );
  }
}
