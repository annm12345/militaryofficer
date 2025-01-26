import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:military_officer/views/map/weapon_details.dart';

// Define the Weapon class to store in Hive
class MyWeapon {
  final String type;
  final int amount;
  final int ammoAmount;

  MyWeapon({
    required this.type,
    required this.amount,
    required this.ammoAmount,
  });
}

class MyWeaponAdapter extends TypeAdapter<MyWeapon> {
  @override
  final typeId = 1;

  @override
  MyWeapon read(BinaryReader reader) {
    return MyWeapon(
      type: reader.readString(),
      amount: reader.readInt(),
      ammoAmount: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, MyWeapon obj) {
    writer.writeString(obj.type);
    writer.writeInt(obj.amount);
    writer.writeInt(obj.ammoAmount);
  }
}

// Define SystemWeapon class to store in Hive
class SystemWeapon {
  final String name;
  final double range;
  final double mil;
  final double flightTime;
  final int gunPower;
  final int id;

  SystemWeapon({
    required this.name,
    required this.range,
    required this.mil,
    required this.flightTime,
    required this.gunPower,
    required this.id,
  });
}

class SystemWeaponAdapter extends TypeAdapter<SystemWeapon> {
  @override
  final typeId = 2;

  @override
  SystemWeapon read(BinaryReader reader) {
    return SystemWeapon(
      name: reader.readString(),
      range: reader.readDouble(),
      mil: reader.readDouble(),
      flightTime: reader.readDouble(),
      gunPower: reader.readInt(),
      id: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, SystemWeapon obj) {
    writer.writeString(obj.name);
    writer.writeDouble(obj.range);
    writer.writeDouble(obj.mil);
    writer.writeDouble(obj.flightTime);
    writer.writeInt(obj.gunPower);
    writer.writeInt(obj.id);
  }
}

class Answer {
  final String questiontext;

  final String answer;

  Answer({
    required this.questiontext,
    required this.answer,
  });
}

class AnswerAdapter extends TypeAdapter<Answer> {
  @override
  final typeId = 3;

  @override
  Answer read(BinaryReader reader) {
    return Answer(
      questiontext: reader.readString(),
      answer: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, Answer obj) {
    writer.writeString(obj.questiontext);
    writer.writeString(obj.answer);
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Box? _operationsBox;
  Box? _unitsBox;
  Box? _enemiesBox;
  Box? _weaponsBox;
  Box? _enemyweaponsBox;
  Box<MyWeapon>? _myweaponsBox;
  Box<SystemWeapon>? _systemweaponsBox;
  Box? _answerBox; // Declare the box for answers

  // Initialize Hive and open boxes
  Future<void> initHive() async {
    await Hive.initFlutter();
    // Register both adapters
    Hive.registerAdapter(
        SystemWeaponAdapter()); // Register the SystemWeapon adapter
    Hive.registerAdapter(MyWeaponAdapter()); // Register the MyWeapon adapter
    Hive.registerAdapter(AnswerAdapter()); // Register the MyWeapon adapter
    _operationsBox = await Hive.openBox('operations');
    _unitsBox = await Hive.openBox('units');
    _enemiesBox = await Hive.openBox('enemies');
    _weaponsBox = await Hive.openBox('weapons');
    _enemyweaponsBox = await Hive.openBox('enemyweapons');
    _myweaponsBox = await Hive.openBox('myweapons');
    _systemweaponsBox = await Hive.openBox<SystemWeapon>('systemweaponsBox');
    _answerBox = await Hive.openBox('answerBox'); // Open the answer box
  }

// Method to save answers to the box
  Future<void> saveAnswers(List<Answer> answers) async {
    try {
      await _answerBox?.clear(); // Clear old data
      // Save all answers to the 'answerBox'
      for (var answer in answers) {
        await _answerBox?.add(answer);
      }
    } catch (e) {
      print('Error saving answers to Hive: $e');
    }
  }

  // Retrieve answers from Hive when needed
  Future<List<Answer>> getAnswers() async {
    var box = await Hive.openBox('answerBox');
    return box.values.toList().cast<Answer>();
  }

  // Save the weapon data as SystemWeapon in Hive
  Future<void> saveWeapons(List<Weapon> weapons) async {
    // Clear existing SystemWeapon data before saving new data
    await _systemweaponsBox?.clear();

    final List<SystemWeapon> systemWeapons = weapons.map((weapon) {
      return SystemWeapon(
        name: weapon.name,
        range: weapon.range,
        mil: weapon.mil,
        flightTime: weapon.flightTime,
        gunPower: weapon.gunPower,
        id: weapon.id,
      );
    }).toList();

    // Save new weapons
    await _systemweaponsBox?.addAll(systemWeapons);
  }

  // Fetch SystemWeapon data from Hive
  Future<List<SystemWeapon>> fetchSystemWeapons() async {
    return _systemweaponsBox?.values.toList() ?? [];
  }

  // Convert SystemWeapon to Weapon
  List<Weapon> convertToWeapons(List<SystemWeapon> systemWeapons) {
    return systemWeapons.map((systemWeapon) {
      return Weapon(
        name: systemWeapon.name,
        range: systemWeapon.range,
        mil: systemWeapon.mil,
        flightTime: systemWeapon.flightTime,
        gunPower: systemWeapon.gunPower,
        id: systemWeapon.id,
      );
    }).toList();
  }

// Fetch all weapons
  List<MyWeapon> fetchmyWeapons() {
    return _myweaponsBox?.values.toList() ?? [];
  }

  // Save a new weapon
  Future<void> addmyWeapon(MyWeapon weapon) async {
    await _myweaponsBox?.add(weapon);
  }

  // Delete a weapon
  Future<void> deletemyWeapon(int index) async {
    await _myweaponsBox?.deleteAt(index);
  }

  // Update a weapon
  Future<void> updatemyWeapon(int index, MyWeapon weapon) async {
    await _myweaponsBox?.putAt(index, weapon);
  }

  /// Insert a new operation
  Future<void> insertOperation(String name) async {
    final box = _operationsBox;
    if (box == null) {
      throw Exception("Hive is not initialized yet.");
    }

    await box.add({
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Fetch all operations
  Future<List<Map<String, dynamic>>> fetchOperations() async {
    final box = _operationsBox;
    if (box == null) {
      throw Exception("Hive is not initialized yet.");
    }

    final List<Map<String, dynamic>> operations = [];

    for (var i = 0; i < box.length; i++) {
      final operation = box.getAt(i);

      if (operation is Map<dynamic, dynamic>) {
        operations.add(Map<String, dynamic>.from(operation));
      } else {
        throw Exception("Invalid operation format in Hive.");
      }
    }

    operations.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
    return operations;
  }

  /// Delete operation by name
  Future<bool> deleteOperation(String name) async {
    final box = _operationsBox;
    if (box == null) {
      throw Exception("Hive is not initialized yet.");
    }

    final operationIndex = box.values
        .toList()
        .indexWhere((operation) => operation['name'] == name);

    if (operationIndex == -1) {
      return false;
    }

    await box.deleteAt(operationIndex);
    return true;
  }

  /// Insert Unit with unique key
  Future<void> insertUnit(String operationName, String unitName,
      String manpower, String icon, LatLng location) async {
    final box = _unitsBox;
    if (box == null) throw Exception("Hive is not initialized yet.");

    await box.add({
      'key': DateTime.now().millisecondsSinceEpoch.toString(), // Unique ID
      'operationName': operationName,
      'unitName': unitName,
      'manpower': manpower,
      'icon': icon,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Insert Enemy with unique key
  Future<void> insertEnemy(String operationName, String enemyName,
      String manpower, LatLng location) async {
    final box = _enemiesBox;
    if (box == null) throw Exception("Hive is not initialized yet.");

    await box.add({
      'key': DateTime.now().millisecondsSinceEpoch.toString(),
      'operationName': operationName,
      'enemyName': enemyName,
      'manpower': manpower,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Insert Weapon with unique key
  Future<void> insertWeapon(String operationName, String weaponType,
      String ammoAmount, LatLng location) async {
    final box = _weaponsBox;
    if (box == null) throw Exception("Hive is not initialized yet.");

    await box.add({
      'key': DateTime.now().millisecondsSinceEpoch.toString(),
      'operationName': operationName,
      'weaponType': weaponType,
      'ammoAmount': ammoAmount,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> insertEnemyWeapon(String operationName, String weaponType,
      String ammoAmount, LatLng location) async {
    final box = _enemyweaponsBox;
    if (box == null) throw Exception("Hive is not initialized yet.");

    await box.add({
      'key': DateTime.now().millisecondsSinceEpoch.toString(),
      'operationName': operationName,
      'weaponType': weaponType,
      'ammoAmount': ammoAmount,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> addMyWeapon(
      String type, String amount, String ammoAmount) async {
    final box = _enemyweaponsBox;
    if (box == null) throw Exception("Hive is not initialized yet.");

    await box.add({
      'key': DateTime.now().millisecondsSinceEpoch.toString(),
      'weaponType': type,
      'weaponamount': amount,
      'ammoAmount': ammoAmount,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Fetch Units by Operation
  Future<List<Map<String, dynamic>>> fetchUnits(String operationName) async {
    final box = _unitsBox;
    if (box == null) {
      throw Exception("Hive is not initialized yet.");
    }

    return box.values
        .where((unit) => unit['operationName'] == operationName)
        .map((unit) => Map<String, dynamic>.from(unit))
        .toList();
  }

  /// Fetch Enemies by Operation
  Future<List<Map<String, dynamic>>> fetchEnemies(String operationName) async {
    final box = _enemiesBox;
    if (box == null) {
      throw Exception("Hive is not initialized yet.");
    }

    return box.values
        .where((enemy) => enemy['operationName'] == operationName)
        .map((enemy) => Map<String, dynamic>.from(enemy))
        .toList();
  }

  /// Fetch Weapons by Operation
  Future<List<Map<String, dynamic>>> fetchWeapons(String operationName) async {
    final box = _weaponsBox;
    if (box == null) {
      throw Exception("Hive is not initialized yet.");
    }

    return box.values
        .where((weapon) => weapon['operationName'] == operationName)
        .map((weapon) => Map<String, dynamic>.from(weapon))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchEnemyWeapons(
      String operationName) async {
    final box = _enemyweaponsBox;
    if (box == null) {
      throw Exception("Hive is not initialized yet.");
    }

    return box.values
        .where((weapon) => weapon['operationName'] == operationName)
        .map((weapon) => Map<String, dynamic>.from(weapon))
        .toList();
  }

  /// Fetch all Units across all operations
  Future<List<Map<String, dynamic>>> fetchAllUnits() async {
    final box = _unitsBox;
    if (box == null) {
      throw Exception("Hive is not initialized yet.");
    }
    return box.values.map((unit) => Map<String, dynamic>.from(unit)).toList();
  }

  /// Fetch all Enemies across all operations
  Future<List<Map<String, dynamic>>> fetchAllEnemies() async {
    final box = _enemiesBox;
    if (box == null) {
      throw Exception("Hive is not initialized yet.");
    }
    return box.values.map((enemy) => Map<String, dynamic>.from(enemy)).toList();
  }

  /// Fetch all Weapons across all operations
  Future<List<Map<String, dynamic>>> fetchAllWeapons() async {
    final box = _weaponsBox;
    if (box == null) {
      throw Exception("Hive is not initialized yet.");
    }
    return box.values
        .map((weapon) => Map<String, dynamic>.from(weapon))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllEnemyWeapons() async {
    final box = _enemyweaponsBox;
    if (box == null) {
      throw Exception("Hive is not initialized yet.");
    }
    return box.values
        .map((weapon) => Map<String, dynamic>.from(weapon))
        .toList();
  }

  /// Delete Unit using the unique key
  Future<void> deleteUnit(Map<String, dynamic> unit) async {
    final box = _unitsBox;
    if (box == null) throw Exception("Hive is not initialized yet.");
    final keyToDelete = unit['key'];

    final index =
        box.values.toList().indexWhere((item) => item['key'] == keyToDelete);
    if (index != -1) {
      await box.deleteAt(index);
    }
  }

  /// Delete Enemy using the unique key
  Future<void> deleteEnemy(Map<String, dynamic> enemy) async {
    final box = _enemiesBox;
    if (box == null) throw Exception("Hive is not initialized yet.");
    final keyToDelete = enemy['key'];

    final index =
        box.values.toList().indexWhere((item) => item['key'] == keyToDelete);
    if (index != -1) {
      await box.deleteAt(index);
    }
  }

  /// Delete Weapon using the unique key
  Future<void> deleteWeapon(Map<String, dynamic> weapon) async {
    final box = _weaponsBox;
    if (box == null) throw Exception("Hive is not initialized yet.");
    final keyToDelete = weapon['key'];

    final index =
        box.values.toList().indexWhere((item) => item['key'] == keyToDelete);
    if (index != -1) {
      await box.deleteAt(index);
    }
  }

  Future<void> deleteEnemyWeapon(Map<String, dynamic> weapon) async {
    final box = _enemyweaponsBox;
    if (box == null) throw Exception("Hive is not initialized yet.");
    final keyToDelete = weapon['key'];

    final index =
        box.values.toList().indexWhere((item) => item['key'] == keyToDelete);
    if (index != -1) {
      await box.deleteAt(index);
    }
  }
}
