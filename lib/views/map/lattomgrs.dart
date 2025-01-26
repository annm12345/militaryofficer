import 'package:latlong2/latlong.dart';

import 'dart:math';

class MGRS {
  static final List<String> zoneLetters = [
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'J',
    'K',
    'L',
    'M',
    'N',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X'
  ];

  static final List<String> e100kLetters = ['ABCDEFGH', 'JKLMNPQR', 'STUVWXYZ'];

  static final List<String> n100kLetters = [
    'ABCDEFGHJKLMNPQRSTUV',
    'FGHJKLMNPQRSTUVABCDE'
  ];

  static String latLonToMGRS(double lat, double lon) {
    if (lat < -80) return 'Too far South';
    if (lat > 84) return 'Too far North';

    int zoneNumber = ((lon + 180) / 6).floor() + 1;
    double e = zoneNumber * 6 - 183;
    double latRad = lat * (pi / 180);
    double lonRad = lon * (pi / 180);
    double centralMeridianRad = e * (pi / 180);
    double cosLat = cos(latRad);
    double sinLat = sin(latRad);
    double tanLat = tan(latRad);
    double tanLat2 = tanLat * tanLat;
    double tanLat4 = tanLat2 * tanLat2;
    double tanLat6 = tanLat2 * tanLat4;

    double o = 0.006739496819936062 * cosLat * cosLat;
    double p = 40680631590769 / (6356752.314 * sqrt(1 + o));
    double t = lonRad - centralMeridianRad;

    double N = 6378137.0 / sqrt(1 - 0.00669438 * sinLat * sinLat);
    double T = tanLat2;
    double C = 0.006739496819936062 * cosLat * cosLat;
    double A = cosLat * (lonRad - centralMeridianRad);
    double M = 6367449.14570093 *
        (latRad -
            (0.00251882794504 * sin(2 * latRad)) +
            (0.00000264354112 * sin(4 * latRad)) -
            (0.00000000345262 * sin(6 * latRad)) +
            (0.000000000004892 * sin(8 * latRad)));

    double x = (A +
            (1 - T + C) * A * A * A / 6 +
            (5 - 18 * T + T * T + 72 * C - 58 * 0.006739496819936062) *
                A *
                A *
                A *
                A *
                A /
                120) *
        N;
    double y = (M +
            N *
                tanLat *
                (A * A / 2 +
                    (5 - T + 9 * C + 4 * C * C) * A * A * A * A / 24 +
                    (61 -
                            58 * T +
                            T * T +
                            600 * C -
                            330 * 0.006739496819936062) *
                        A *
                        A *
                        A *
                        A *
                        A *
                        A /
                        720)) *
        0.9996;

    x = x * 0.9996 + 500000.0;
    y = y * 0.9996;
    if (y < 0.0) {
      y += 10000000.0;
    }

    double aa = p * cosLat * t +
        (p / 6.0 * pow(cosLat, 3) * (1.0 - tanLat2 + o) * pow(t, 3)) +
        (p /
            120.0 *
            pow(cosLat, 5) *
            (5.0 - 18.0 * tanLat2 + tanLat4 + 14.0 * o - 58.0 * tanLat2 * o) *
            pow(t, 5)) +
        (p /
            5040.0 *
            pow(cosLat, 7) *
            (61.0 - 479.0 * tanLat2 + 179.0 * tanLat4 - tanLat6) *
            pow(t, 7));
    double ab = 6367449.14570093 *
            (latRad -
                (0.00251882794504 * sin(2 * latRad)) +
                (0.00000264354112 * sin(4 * latRad)) -
                (0.00000000345262 * sin(6 * latRad)) +
                (0.000000000004892 * sin(8 * latRad))) +
        (tanLat / 2.0 * p * cosLat * cosLat * t * t) +
        (tanLat /
            24.0 *
            p *
            pow(cosLat, 4) *
            (5.0 - tanLat2 + 9.0 * o + 4.0 * o * o) *
            pow(t, 4)) +
        (tanLat /
            720.0 *
            p *
            pow(cosLat, 6) *
            (61.0 -
                58.0 * tanLat2 +
                tanLat4 +
                270.0 * o -
                330.0 * tanLat2 * o) *
            pow(t, 6)) +
        (tanLat /
            40320.0 *
            p *
            pow(cosLat, 8) *
            (1385.0 - 3111.0 * tanLat2 + 543.0 * tanLat4 - tanLat6) *
            pow(t, 8));
    aa = aa * 0.9996 + 500000.0;
    ab = ab * 0.9996;
    if (ab < 0.0) ab += 10000000.0;

    String zoneLetter = 'CDEFGHJKLMNPQRSTUVWXX'
        .substring((lat / 8 + 10).floor(), (lat / 8 + 10).floor() + 1);
    int e100kIndex = (aa ~/ 100000);
    String e100kLetter = [
      'ABCDEFGH',
      'JKLMNPQR',
      'STUVWXYZ'
    ][(zoneNumber - 1) % 3][e100kIndex - 1];
    int n100kIndex = (ab ~/ 100000) % 20;
    String n100kLetter = [
      'ABCDEFGHJKLMNPQRSTUV',
      'FGHJKLMNPQRSTUVABCDE'
    ][(zoneNumber - 1) % 2][n100kIndex];

    String easting = x.round().toString().padLeft(6, '0');
    easting = easting.substring(
        1, 6); // Remove the first character, keep the next 5 characters

    // Convert easting back to an integer, sum with 300, and convert back to a string
    easting = (int.parse(easting) + 350).toString().padLeft(5, '0');

    // Convert y to a string, pad it to at least 7 characters, and remove the first 2 characters
    String northing = y.round().toString().padLeft(7, '0');
    northing = northing.substring(
        2, 7); // Remove the first 2 characters, keep the next 5 characters

    // Convert northing back to an integer, sum with 300, and convert back to a string
    northing = (int.parse(northing) + 700).toString().padLeft(5, '0');

    return '$zoneNumber$zoneLetter $e100kLetter$n100kLetter $easting $northing';
  }

  static LatLng mgrsToLatLon(String mgrs) {
    // Step 1: Parse MGRS string
    mgrs = mgrs.replaceAll(" ", "").toUpperCase();

    // Extract zone number and letter
    int zoneNumber = int.parse(mgrs.substring(0, 2));
    String zoneLetter = mgrs[2];

    // Check validity of the zone letter
    if ("ABCDEFGHJKLMNPQRSTUVWX".indexOf(zoneLetter) == -1) {
      throw ArgumentError("Invalid zone letter in MGRS string.");
    }

    // Extract 100k grid letters
    String e100kLetter = mgrs[3];
    String n100kLetter = mgrs[4];

    // Extract easting and northing
    String eastingString = mgrs.substring(5, 10);
    String northingString = mgrs.substring(10);

    // Convert easting and northing to meters
    num easting = int.parse(eastingString) * pow(10, 5 - eastingString.length);
    num northing =
        int.parse(northingString) * pow(10, 5 - northingString.length);

    // Step 2: Calculate the base values for the 100k grid
    int setNumber = (zoneNumber - 1) % 6;
    int e100kIndex = "ABCDEFGH".indexOf(e100kLetter);
    int n100kIndex = "ABCDEFGHJKLMNPQRSTUV".indexOf(n100kLetter);

    if (e100kIndex == -1 || n100kIndex == -1) {
      throw ArgumentError("Invalid 100k grid letters.");
    }

    // Determine the base easting and northing
    double baseEasting = (e100kIndex + 1) * 100000;
    double baseNorthing = n100kIndex * 100000;

    // Ensure the northing is within the correct hemisphere
    if ("NPQRSTUVWX".contains(zoneLetter)) {
      // Northern hemisphere
      while (baseNorthing < northing) {
        baseNorthing += 2000000;
      }
    } else {
      // Southern hemisphere
      baseNorthing += 10000000;
    }

    // Add offsets to easting and northing
    easting += baseEasting;
    northing += baseNorthing;

    // Step 3: Convert UTM to Lat/Lon
    double k0 = 0.9996;
    double a = 6378137.0; // Semi-major axis of the Earth
    double f = 1 / 298.257223563; // Flattening
    double e = sqrt(f * (2 - f)); // Eccentricity

    // Central meridian of the zone
    double lonOrigin = (zoneNumber - 1) * 6 - 180 + 3;

    // UTM to Lat/Lon conversion
    double x = (easting - 500000.0) / k0;
    double y = northing / k0;

    double eccPrimeSquared = (e * e) / (1 - e * e);

    double m = y / 0.9996;
    double mu = m /
        (a * (1 - pow(e, 2) / 4 - 3 * pow(e, 4) / 64 - 5 * pow(e, 6) / 256));

    double phi1Rad = mu +
        (3 * e / 2 - 27 * pow(e, 3) / 32) * sin(2 * mu) +
        (21 * pow(e, 2) / 16 - 55 * pow(e, 4) / 32) * sin(4 * mu) +
        (151 * pow(e, 3) / 96) * sin(6 * mu) +
        (1097 * pow(e, 4) / 512) * sin(8 * mu);

    double n = a / sqrt(1 - pow(e * sin(phi1Rad), 2));
    num t = pow(tan(phi1Rad), 2);
    double c = eccPrimeSquared * pow(cos(phi1Rad), 2);
    double r = a * (1 - pow(e, 2)) / pow(1 - pow(e * sin(phi1Rad), 2), 1.5);
    double d = x / n;

    double lat = phi1Rad -
        (n * tan(phi1Rad) / r) *
            (pow(d, 2) / 2 -
                (5 + 3 * t + 10 * c - 4 * pow(c, 2) - 9 * eccPrimeSquared) *
                    pow(d, 4) /
                    24 +
                (61 +
                        90 * t +
                        298 * c +
                        45 * pow(t, 2) -
                        252 * eccPrimeSquared -
                        3 * pow(c, 2)) *
                    pow(d, 6) /
                    720);
    lat = lat * (180 / pi);

    double lon = (d -
            (1 + 2 * t + c) * pow(d, 3) / 6 +
            (5 -
                    2 * c +
                    28 * t -
                    3 * pow(c, 2) +
                    8 * eccPrimeSquared +
                    24 * pow(t, 2)) *
                pow(d, 5) /
                120) /
        cos(phi1Rad);
    lon = lonOrigin + lon * (180 / pi);

    // Return the final LatLng
    return LatLng(lat, lon);
  }
}
