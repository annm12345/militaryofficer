import 'package:latlong2/latlong.dart';

import 'dart:math';

LatLng mgrsToLatLng(String mgrs) {
  // Parse the input MGRS string
  final zoneNumber = int.parse(mgrs.substring(0, 2)); // Zone number
  final zoneLetter = mgrs[2]; // Grid letter
  final e100kLetter = mgrs[4]; // 100k easting square identifier
  final n100kLetter = mgrs[5]; // 100k northing square identifier
  final easting = int.parse(mgrs.substring(7, 12)); // Easting
  final northing = int.parse(mgrs.substring(13, 18)); // Northing

  // Convert 100k easting and northing square identifiers to meters
  double e100k = _e100kToMeters(zoneNumber, e100kLetter);
  double n100k = _n100kToMeters(zoneNumber, n100kLetter, zoneLetter);

  // Apply offsets to easting and northing
  double adjustedEasting = easting + e100k + 99645.0; // Offset by 8.59 km
  double adjustedNorthing = northing + n100k - 3800; // Offset by 6363.39 mills

  // Convert UTM to LatLng
  LatLng latLng =
      _utmToLatLng(zoneNumber, zoneLetter, adjustedEasting, adjustedNorthing);

  return latLng;
}

double _e100kToMeters(int zoneNumber, String e100k) {
  // Convert 100k easting square identifier to meters
  const e100kLetters = "ABCDEFGHJKLMNPQRSTUVWXYZ";
  int index = e100kLetters.indexOf(e100k);
  if (index == -1) {
    throw FormatException("Invalid e100k identifier");
  }
  return (index % 8) * 100000.0;
}

double _n100kToMeters(int zoneNumber, String n100k, String zoneLetter) {
  // Convert 100k northing square identifier to meters
  const n100kLetters = "ABCDEFGHJKLMNPQRSTUV";
  int index = n100kLetters.indexOf(n100k);
  if (index == -1) {
    throw FormatException("Invalid n100k identifier");
  }
  int rowIndex = _rowIndex(zoneLetter);
  double northing = index * 100000.0;

  // Correct for zone rows
  if (index < rowIndex) {
    northing += 2000000.0;
  }

  // Adjust for southern hemisphere
  if (zoneLetter.compareTo('N') < 0) {
    northing -= 10000000.0;
  }
  return northing;
}

int _rowIndex(String letter) {
  // Determine the MGRS row index from the letter
  const letters = "CDEFGHJKLMNPQRSTUVWX";
  int index = letters.indexOf(letter);
  if (index == -1) {
    throw FormatException("Invalid letter for row index");
  }
  return index % 2 == 0 ? index : index - 1;
}

LatLng _utmToLatLng(int zone, String letter, double easting, double northing) {
  // Constants for WGS84
  const double k0 = 0.9996;
  const double a = 6378137.0;
  const double f = 1 / 298.257223563;
  final double e = sqrt(f * (2 - f));
  final double e1sq = e * e / (1 - e * e);
  final double n = f / (2 - f);
  final double a1 = a / (1 + n) * (1 + n * n / 4 + n * n * n * n / 64);
  final double pi = 3.14159265358979;

  double x = easting - 500000.0;
  double y = northing;
  if (letter.compareTo('N') < 0) {
    y -= 10000000.0;
  }
  double m = y / k0;
  double mu = m /
      (a1 *
          (1 -
              e * e / 4 -
              3 * e * e * e * e / 64 -
              5 * e * e * e * e * e * e / 256));

  double e1 = (1 - sqrt(1 - e * e)) / (1 + sqrt(1 - e * e));
  double j1 = 3 * e1 / 2 - 27 * e1 * e1 * e1 / 32;
  double j2 = 21 * e1 * e1 / 16 - 55 * e1 * e1 * e1 * e1 / 32;
  double j3 = 151 * e1 * e1 * e1 / 96;
  double j4 = 1097 * e1 * e1 * e1 * e1 / 512;

  double fp = mu +
      j1 * sin(2 * mu) +
      j2 * sin(4 * mu) +
      j3 * sin(6 * mu) +
      j4 * sin(8 * mu);

  double e2 = e * e / (1 - e * e);
  double c1 = e2 * pow(cos(fp), 2);
  num t1 = pow(tan(fp), 2);
  double r1 = a * (1 - e * e) / pow(1 - e * e * pow(sin(fp), 2), 1.5);
  double n1 = a / sqrt(1 - e * e * pow(sin(fp), 2));
  double d = x / (n1 * k0);

  double q1 = n1 * tan(fp) / r1;
  double q2 = d * d / 2;
  double q3 = (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * e2) * pow(d, 4) / 24;
  double q4 =
      (61 + 90 * t1 + 298 * c1 + 45 * t1 * t1 - 252 * e2 - 3 * c1 * c1) *
          pow(d, 6) /
          720;

  double lat = fp - q1 * (q2 - q3 + q4);

  double q5 = d;
  double q6 = (1 + 2 * t1 + c1) * pow(d, 3) / 6;
  double q7 = (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * e2 + 24 * t1 * t1) *
      pow(d, 5) /
      120;
  double lon = (zone * 6 - 183) * pi / 180 + (q5 - q6 + q7) / cos(fp);

  // Convert radians to degrees
  lat = lat * 180 / pi;
  lon = lon * 180 / pi;

  return LatLng(lat, lon);
}
