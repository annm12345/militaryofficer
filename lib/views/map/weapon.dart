class Weapon {
  final String name;
  final double range; // in meters
  final double mil; // in mils
  final double flightTime; // in seconds
  final int gunPower; // arbitrary unit
  final int id; // ID for each weapon

  Weapon({
    required this.name,
    required this.range,
    required this.mil,
    required this.flightTime,
    required this.gunPower,
    required this.id,
  });
}

List<Weapon> generateWeapons() {
  List<Weapon> weapons = [];
  int? id = 1;

  // Add MA7 data
  const List<Map<String, dynamic>> ma7Data = [
    {
      "gunPower": 0,
      "minRange": 250,
      "maxRange": 750,
      "minMil": 1427,
      "maxMil": 800,
      "minTime": 18.3,
      "maxTime": 13.1
    },
    {
      "gunPower": 1,
      "minRange": 500,
      "maxRange": 1550,
      "minMil": 1437,
      "maxMil": 800,
      "minTime": 25.3,
      "maxTime": 18.2
    },
    {
      "gunPower": 2,
      "minRange": 800,
      "maxRange": 2150,
      "minMil": 1408,
      "maxMil": 952,
      "minTime": 25.9,
      "maxTime": 18.6
    },
    {
      "gunPower": 3,
      "minRange": 1000,
      "maxRange": 2900,
      "minMil": 1421,
      "maxMil": 800,
      "minTime": 40.2,
      "maxTime": 28.8
    },
    {
      "gunPower": 4,
      "minRange": 1300,
      "maxRange": 3480,
      "minMil": 1405,
      "maxMil": 800,
      "minTime": 46.1,
      "maxTime": 33.1
    },
    {
      "gunPower": 5,
      "minRange": 1600,
      "maxRange": 4050,
      "minMil": 1394,
      "maxMil": 800,
      "minTime": 51.5,
      "maxTime": 37.2
    },
    {
      "gunPower": 6,
      "minRange": 1800,
      "maxRange": 4600,
      "minMil": 1395,
      "maxMil": 800,
      "minTime": 57.0,
      "maxTime": 41.0
    },
  ];
  weapons.addAll(generateIntervalData("MA7", ma7Data, id));
  id += ((ma7Data.length *
      ((ma7Data[0]["maxRange"] - ma7Data[0]["minRange"]) ~/ 50)) as int?)!;

  List<Map<String, dynamic>> ma8Data = [
    {
      "gunPower": 0,
      "minRange": 200,
      "maxRange": 550,
      "minMil": 1410.0,
      "maxMil": 800.0,
      "minTime": 14.0,
      "maxTime": 10.0
    },
    {
      "gunPower": 1,
      "minRange": 400,
      "maxRange": 1125,
      "minMil": 1414.0,
      "maxMil": 800.0,
      "minTime": 21.0,
      "maxTime": 15.1
    },
    {
      "gunPower": 2,
      "minRange": 600,
      "maxRange": 1650,
      "minMil": 1410.0,
      "maxMil": 800.0,
      "minTime": 27.2,
      "maxTime": 17.6
    },
    {
      "gunPower": 3,
      "minRange": 900,
      "maxRange": 2700,
      "minMil": 1427.0,
      "maxMil": 800.0,
      "minTime": 36.4,
      "maxTime": 26.1
    },
    {
      "gunPower": 4,
      "minRange": 1300,
      "maxRange": 3550,
      "minMil": 1409.0,
      "maxMil": 800.0,
      "minTime": 44.2,
      "maxTime": 45.0
    },
    {
      "gunPower": 5,
      "minRange": 1600,
      "maxRange": 4400,
      "minMil": 1412.0,
      "maxMil": 868.0,
      "minTime": 51.1,
      "maxTime": 39.1
    },
    {
      "gunPower": 6,
      "minRange": 2100,
      "maxRange": 5150,
      "minMil": 1387.0,
      "maxMil": 800.0,
      "minTime": 57.8,
      "maxTime": 41.8
    },
    {
      "gunPower": 7,
      "minRange": 2400,
      "maxRange": 5800,
      "minMil": 1382.0,
      "maxMil": 800.0,
      "minTime": 62.9,
      "maxTime": 45.5
    },
    {
      "gunPower": 8,
      "minRange": 2400,
      "maxRange": 6350,
      "minMil": 1402.0,
      "maxMil": 800.0,
      "minTime": 68.6,
      "maxTime": 49.4
    },
  ];

  weapons.addAll(generateIntervalData("MA8", ma8Data, id!));
  id += ((ma8Data.length *
      ((ma8Data[0]["maxRange"] - ma8Data[0]["minRange"]) ~/ 50)) as int?)!;

  // Add 120MM data
  const List<Map<String, dynamic>> mm120Data = [
    {
      "gunPower": 1,
      "minRange": 600,
      "maxRange": 1850,
      "minMil": 1432,
      "maxMil": 800,
      "minTime": 27.0,
      "maxTime": 19.0
    },
    {
      "gunPower": 2,
      "minRange": 1000,
      "maxRange": 3000,
      "minMil": 1427,
      "maxMil": 800,
      "minTime": 36.0,
      "maxTime": 26.0
    },
    {
      "gunPower": 3,
      "minRange": 1400,
      "maxRange": 4100,
      "minMil": 1423,
      "maxMil": 800,
      "minTime": 43.0,
      "maxTime": 29.0
    },
    {
      "gunPower": 4,
      "minRange": 1900,
      "maxRange": 5250,
      "minMil": 1411,
      "maxMil": 800,
      "minTime": 51.0,
      "maxTime": 37.0
    },
    {
      "gunPower": 5,
      "minRange": 2300,
      "maxRange": 6100,
      "minMil": 1403,
      "maxMil": 808,
      "minTime": 56.2,
      "maxTime": 41.0
    },
    {
      "gunPower": 6,
      "minRange": 2600,
      "maxRange": 7000,
      "minMil": 1398,
      "maxMil": 800,
      "minTime": 61.0,
      "maxTime": 45.0
    },
    {
      "gunPower": 7,
      "minRange": 2900,
      "maxRange": 7650,
      "minMil": 1219,
      "maxMil": 800,
      "minTime": 69.0,
      "maxTime": 49.0
    },
    {
      "gunPower": 8,
      "minRange": 3200,
      "maxRange": 8150,
      "minMil": 1395,
      "maxMil": 800,
      "minTime": 74.0,
      "maxTime": 53.0
    },
    {
      "gunPower": 9,
      "minRange": 3200,
      "maxRange": 8500,
      "minMil": 1403,
      "maxMil": 800,
      "minTime": 80.0,
      "maxTime": 57.0
    },
  ];
  weapons.addAll(generateIntervalData("120MM", mm120Data, id));

  return weapons;
}

List<Weapon> generateIntervalData(
    String name, List<Map<String, dynamic>> data, int startId) {
  List<Weapon> intervalWeapons = [];
  int id = startId;

  for (var entry in data) {
    for (double range = entry["minRange"].toDouble();
        range <= entry["maxRange"].toDouble();
        range += 50.0) {
      double progress = (range - entry["minRange"].toDouble()) /
          (entry["maxRange"].toDouble() - entry["minRange"].toDouble());
      double mil = entry["minMil"].toDouble() +
          (entry["maxMil"].toDouble() - entry["minMil"].toDouble()) * progress;
      double flightTime = entry["minTime"].toDouble() +
          (entry["maxTime"].toDouble() - entry["minTime"].toDouble()) *
              progress;

      // Round values to two decimal places
      double roundedRange = double.parse(range.toStringAsFixed(2));
      double roundedMil = double.parse(mil.toStringAsFixed(2));
      double roundedFlightTime = double.parse(flightTime.toStringAsFixed(2));

      // Assign gunPower from the current data entry
      int gunPower = entry["gunPower"];

      intervalWeapons.add(Weapon(
        name: name,
        range: roundedRange,
        mil: roundedMil,
        flightTime: roundedFlightTime,
        gunPower: gunPower,
        id: id++,
      ));
    }
  }
  return intervalWeapons;
}
