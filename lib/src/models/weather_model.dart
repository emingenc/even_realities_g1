import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Weather icon types for G1 display.
enum G1WeatherIcon {
  nothing(0x00),
  night(0x01),
  clouds(0x02),
  drizzle(0x03),
  heavyDrizzle(0x04),
  rain(0x05),
  heavyRain(0x06),
  thunder(0x07),
  thunderstorm(0x08),
  snow(0x09),
  mist(0x0A),
  fog(0x0B),
  sand(0x0C),
  squalls(0x0D),
  tornado(0x0E),
  freezingRain(0x0F),
  sunny(0x10);

  final int code;
  const G1WeatherIcon(this.code);

  /// Convert OpenWeatherMap condition code to G1 icon.
  static G1WeatherIcon fromOpenWeatherMap(int owpCode) {
    switch (owpCode) {
      case 200:
      case 201:
      case 202:
      case 210:
      case 211:
      case 212:
      case 221:
      case 230:
      case 231:
      case 232:
        return G1WeatherIcon.thunderstorm;
      case 300:
      case 301:
      case 310:
      case 311:
      case 313:
      case 321:
        return G1WeatherIcon.drizzle;
      case 302:
      case 312:
      case 314:
        return G1WeatherIcon.heavyDrizzle;
      case 500:
      case 501:
      case 531:
        return G1WeatherIcon.rain;
      case 502:
      case 503:
      case 504:
      case 521:
      case 522:
        return G1WeatherIcon.heavyRain;
      case 511:
      case 520:
        return G1WeatherIcon.freezingRain;
      case 600:
      case 601:
      case 602:
      case 611:
      case 612:
      case 613:
      case 615:
      case 616:
      case 620:
      case 621:
      case 622:
        return G1WeatherIcon.snow;
      case 701:
      case 711:
      case 721:
      case 731:
        return G1WeatherIcon.mist;
      case 741:
        return G1WeatherIcon.fog;
      case 751:
      case 761:
      case 762:
        return G1WeatherIcon.sand;
      case 771:
        return G1WeatherIcon.squalls;
      case 781:
        return G1WeatherIcon.tornado;
      case 800:
      case 801:
        return G1WeatherIcon.sunny;
      case 802:
      case 803:
      case 804:
        return G1WeatherIcon.clouds;
      default:
        return G1WeatherIcon.nothing;
    }
  }
}

/// Temperature unit
enum TemperatureUnit {
  celsius,
  fahrenheit,
}

/// Time format
enum TimeFormat {
  twelveHour,
  twentyFourHour,
}

/// Model for time and weather display on G1.
class G1WeatherModel {
  /// Temperature unit to display
  final TemperatureUnit temperatureUnit;

  /// Time format to display
  final TimeFormat timeFormat;

  /// Current temperature in Celsius
  final int temperatureInCelsius;

  /// Weather icon to display
  final G1WeatherIcon weatherIcon;

  G1WeatherModel({
    this.temperatureUnit = TemperatureUnit.celsius,
    this.timeFormat = TimeFormat.twentyFourHour,
    required this.temperatureInCelsius,
    required this.weatherIcon,
  });

  /// Build time/weather update command.
  Uint8List buildCommand(int seqId) {
    final convertToFahrenheit =
        temperatureUnit == TemperatureUnit.fahrenheit ? 0x01 : 0x00;
    final is12hFormat = timeFormat == TimeFormat.twelveHour ? 0x01 : 0x00;

    final now = DateTime.now();

    return Uint8List.fromList([
      0x06, // Dashboard command
      0x15, 0x00, // Total length
      seqId, // Sequence number
      0x01, // Subcommand: update time and weather
      ..._getTimestamp32(now),
      ..._getTimestamp64(now),
      weatherIcon.code,
      temperatureInCelsius,
      convertToFahrenheit,
      is12hFormat,
    ]);
  }

  int _getTimezoneOffsetInSeconds() {
    return DateTime.now().timeZoneOffset.inSeconds;
  }

  Uint8List _getTimestamp32(DateTime time) {
    final timestamp = time
            .add(Duration(seconds: _getTimezoneOffsetInSeconds()))
            .millisecondsSinceEpoch ~/
        1000;

    final bytes = Uint8List(4)
      ..buffer.asByteData().setUint32(0, timestamp, Endian.little);
    return bytes;
  }

  Uint8List _getTimestamp64(DateTime time) {
    final timestamp = time
        .add(Duration(seconds: _getTimezoneOffsetInSeconds()))
        .millisecondsSinceEpoch;

    final bytes = Uint8List(8)
      ..buffer.asByteData().setInt64(0, timestamp, Endian.little);
    return bytes;
  }
}
