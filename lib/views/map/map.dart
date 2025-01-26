import 'dart:async';
import 'dart:convert';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:connectivity/connectivity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:file_picker/file_picker.dart';
import 'package:military_officer/views/authscreen/login.dart';
import 'package:military_officer/views/map/lattomgrs.dart';
import 'package:military_officer/views/map/mgrstolatlang.dart';
import 'package:military_officer/views/map/sqlite.dart';
import 'package:military_officer/views/map/weapon_details.dart';
import 'package:military_officer/views/profile/usercontroller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

typedef DecoderCallback = Future<ui.Codec> Function(ImmutableBuffer buffer,
    {int? cacheWidth, int? cacheHeight, bool? allowUpscaling});

class CachedTileProvider extends TileProvider {
  final cacheManager = DefaultCacheManager();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return CustomCachedNetworkImageProvider(url, cacheManager: cacheManager);
  }

  @override
  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    final tileUrl = options.urlTemplate!
        .replaceAll(
            '{s}',
            options.subdomains[(coordinates.x.toInt() + coordinates.y.toInt()) %
                options.subdomains.length])
        .replaceAll('{z}', '${coordinates.z.toInt()}')
        .replaceAll('{x}', '${coordinates.x.toInt()}')
        .replaceAll('{y}', '${coordinates.y.toInt()}');
    return tileUrl;
  }
}

class Coords<T> {
  final T x;
  final T y;
  final T z;

  Coords(this.x, this.y, this.z);
}

enum ObstacleType {
  building,
  pool,
  bridge,
  river,
  stream,
  lake,
  mountain,
  hill,
}

class Obstacle {
  final int id; // ✅ Add this line
  final LatLng location;
  final ObstacleType type;

  Obstacle({
    required this.id, // ✅ Include 'id' in the constructor
    required this.location,
    required this.type,
  });

  // Factory method to create Obstacle from JSON
  factory Obstacle.fromJson(Map<String, dynamic> json) {
    return Obstacle(
      id: int.parse(json['id']), // ✅ Parse 'id' from JSON
      location: LatLng(
        double.parse(json['latitude']),
        double.parse(json['longitude']),
      ),
      type: ObstacleType.values.firstWhere(
        (e) => e.toString() == 'ObstacleType.' + json['type'],
      ),
    );
  }

  // Convert Obstacle to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(), // ✅ Include 'id' in JSON
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'type': type.toString().split('.').last,
    };
  }
}

class CustomCachedNetworkImageProvider
    extends ImageProvider<CustomCachedNetworkImageProvider> {
  final String url;
  final BaseCacheManager cacheManager;

  CustomCachedNetworkImageProvider(this.url, {required this.cacheManager});

  @override
  Future<CustomCachedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return SynchronousFuture<CustomCachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      CustomCachedNetworkImageProvider key,
      Future<ui.Codec> Function(ImmutableBuffer,
              {TargetImageSize Function(int, int)? getTargetSize})
          decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<String>('URL', url),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
      CustomCachedNetworkImageProvider key,
      Future<ui.Codec> Function(ImmutableBuffer,
              {TargetImageSize Function(int, int)? getTargetSize})
          decode) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        // Online: Load and cache the image
        final FileInfo? fileInfo = await cacheManager.getFileFromCache(url);
        if (fileInfo == null || fileInfo.file == null) {
          // Download and cache the file if not present
          final Uint8List? imageData = await cacheManager
              .getSingleFile(url)
              .then((file) => file.readAsBytes());
          if (imageData != null) {
            return decode(await ImmutableBuffer.fromUint8List(imageData));
          } else {
            throw Exception('Failed to load image data.');
          }
        } else {
          // Load from cache
          final bytes = await fileInfo.file.readAsBytes();
          return decode(
              await ImmutableBuffer.fromUint8List(Uint8List.fromList(bytes)));
        }
      } else {
        // Offline: Load from cache
        final file = await cacheManager.getFileFromCache(url);
        if (file?.file != null) {
          final bytes = await file!.file.readAsBytes();
          return decode(
              await ImmutableBuffer.fromUint8List(Uint8List.fromList(bytes)));
        } else {
          throw Exception('Offline and image not found in cache.');
        }
      }
    } catch (e) {
      throw Exception('Failed to load image: $e');
    }
  }
}

class FlutterMapMbTilesPage extends StatefulWidget {
  const FlutterMapMbTilesPage({super.key});

  @override
  State<FlutterMapMbTilesPage> createState() => _FlutterMapMbTilesPageState();
}

late Future<List<Weapon>> allWeapons;

class _FlutterMapMbTilesPageState extends State<FlutterMapMbTilesPage> {
  MbTiles? _mbtiles;
  MbTilesMetadata? _metadata;
  bool _showGoogleHybrid = true; // Default to Google Hybrid map
  String? _mbtilesLayerUrl;
  late MapController _mapController;
  LatLng _currentLocation = LatLng(22.0355, 96.4560); // Default Pyin Oo Lwin
  LatLng _centerlocation = LatLng(22.0355, 96.4560); // Default Pyin Oo Lwin
  bool _isLocationReady = false;
  final TextEditingController _searchController = TextEditingController();
  List<Marker> _searchMarkers = []; // To hold markers for searched locations
  LatLng? _firstPoint;
  LatLng? _secondPoint;
  bool _isSettingTarget = false; // Track selection state

  List<LatLng> _polylinePoints = [];
  LatLng? _savedLocation; // For storing the saved location
  String _savedLocationLabel =
      ''; // For storing the label of the saved location
  double _firingRangeRadius = 0.0; // Firing range radius in meters
  bool _drawFiringRange = false; // Whether to draw the firing range circle
  List<Map<String, dynamic>> _circles = [];
  List<Map<String, dynamic>> _locations = [];
  double _zoomLevel = 14.0; // Default zoom level
  String _selectedColor = 'blue';

  List<Polyline> _routepolylines = []; // Declare and initialize _routepolylines
  List<Obstacle> obstacles = [];

  List<LatLng> firstRoute = [];
  List<LatLng> secondRoute = [];
  List<LatLng> highlightBestRoute = [];
  List<Marker> _allMarkers = [];
  List<Polyline> _allRoutes = [];
  late DatabaseHelper databaseHelper; // Declare an instance of DatabaseHelper

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _mapController = MapController();
    databaseHelper = DatabaseHelper(); // Initialize DatabaseHelper instance
    _loadSavedLocations(); // Load saved locations when the screen loads
    _loadSavedobstacle(); // Load saved locations when the screen loads
    _getCurrentLocation(); // Get current location
    fetchLocations();
    _fetchObstacles();
    _loadLastPickedFile(); // Load previously picked file
    _loadMarkersOnMap();
    _fetchWeapons();
    generateWeapons();
    _checkLastAccess();
    _startMidnightCheck(); // Start the timer to check for the next day
  }

  Timer? _midnightTimer;

  final UserController userController = Get.find();
// Check the last access date
  Future<void> _checkLastAccess() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get the last access date
    String? lastAccessDate = prefs.getString('lastAccessDate');
    final now = DateTime.now();

    if (lastAccessDate != null) {
      DateTime lastDate = DateTime.parse(lastAccessDate);

      // If the last use was before today, navigate to AuthPage
      if (now.day != lastDate.day ||
          now.month != lastDate.month ||
          now.year != lastDate.year) {
        _navigateToAuthPage();
      }
    }

    // Update the last access date to today
    prefs.setString('lastAccessDate', now.toIso8601String());
  }

// Continuously checks if the day has changed
  void _startMidnightCheck() {
    _midnightTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? lastAccessDate = prefs.getString('lastAccessDate');
      final now = DateTime.now();

      if (lastAccessDate != null) {
        DateTime lastDate = DateTime.parse(lastAccessDate);

        // Check if the date has changed
        if (now.day != lastDate.day ||
            now.month != lastDate.month ||
            now.year != lastDate.year) {
          _navigateToAuthPage();
        }
      }
    });
  }

// Prevent multiple navigations
  bool _hasNavigated = false;

  void _navigateToAuthPage() {
    if (!_hasNavigated) {
      _hasNavigated = true;
      _midnightTimer?.cancel(); // Stop the timer when navigating
      userController.setUser(null); // Clearing user data
      Get.offAll(() => AuthPage()); // Navigate to AuthPage
    }
  }

  // Fetch weapons from the Local hive
  Future<void> _fetchWeapons() async {
    try {
      // Fetch weapons from local Hive storage
      final List<SystemWeapon> systemWeapons =
          await databaseHelper.fetchSystemWeapons();

      if (systemWeapons.isEmpty) {
        // If no local data, fetch from server and save
        final List<Weapon> remoteWeapons = await generateWeapons();
        setState(() {
          allWeapons = Future.value(remoteWeapons);
        });
      } else {
        // If data exists, load from local
        setState(() {
          allWeapons =
              Future.value(databaseHelper.convertToWeapons(systemWeapons));
        });
      }
    } catch (e) {
      print("Error fetching weapons: $e");
    }
  }

  Future<List<Weapon>> generateWeapons() async {
    try {
      final response = await http.get(
        Uri.parse('http://militarycommand.atwebpages.com/fetch_weapon.php'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Weapon> weapons =
            data.map((weaponData) => Weapon.fromJson(weaponData)).toList();

        // Save the fetched weapons to Hive
        await databaseHelper.saveWeapons(weapons);

        return weapons;
      } else {
        throw Exception('Failed to load weapons');
      }
    } catch (e) {
      throw Exception('Error fetching weapons: $e');
    }
  }

  void _calculateBattleLanchester(String operationName) async {
    final units = await DatabaseHelper().fetchUnits(operationName);
    final enemies = await DatabaseHelper().fetchEnemies(operationName);
    final weapons = await DatabaseHelper().fetchWeapons(operationName);
    final enemyWeapons =
        await DatabaseHelper().fetchEnemyWeapons(operationName);

    double totalUnitManpower =
        units.fold(0, (sum, unit) => sum + int.parse(unit['manpower']));
    double totalEnemyManpower =
        enemies.fold(0, (sum, enemy) => sum + int.parse(enemy['manpower']));

    double totalWeaponPower = weapons.fold(0, (sum, weapon) {
      double blastRadius = blastRadiusMap[weapon['weaponType']] ?? 1.0;
      int rateOfFire = rateOfFireMap[weapon['weaponType']] ?? 1;
      return sum + (int.parse(weapon['ammoAmount']) * blastRadius * rateOfFire);
    });

    double totalEnemyWeaponPower = enemyWeapons.fold(0, (sum, weapon) {
      double blastRadius = blastRadiusMap[weapon['weaponType']] ?? 1.0;
      int rateOfFire = rateOfFireMap[weapon['weaponType']] ?? 1;
      return sum + (int.parse(weapon['ammoAmount']) * blastRadius * rateOfFire);
    });

    double result = 0;
    double duration = 0;
    int remainingForces = 0;

    // Balanced Lanchester's Law: Manpower and Weapon Power
    double effectiveUnitStrength =
        (totalUnitManpower > 0 ? pow(totalUnitManpower, 1.5) : 0) *
            (totalWeaponPower > 0 ? sqrt(totalWeaponPower) : 1);

    double effectiveEnemyStrength =
        (totalEnemyManpower > 0 ? pow(totalEnemyManpower, 1.5) : 0) *
            (totalEnemyWeaponPower > 0 ? sqrt(totalEnemyWeaponPower) : 1);

    result = effectiveUnitStrength - effectiveEnemyStrength;

    // Balanced battle duration
    duration = (effectiveUnitStrength + effectiveEnemyStrength) /
        (2 * ((totalWeaponPower + totalEnemyWeaponPower) / 2 + 1));

    remainingForces = result > 0
        ? (sqrt(result) / (totalWeaponPower > 0 ? sqrt(totalWeaponPower) : 1))
            .round()
        : 0;

    String battleResult;
    if (result > 0) {
      battleResult = "✅ Victory! Remaining Forces: $remainingForces";
    } else {
      battleResult = "❌ Defeat. All forces lost.";
    }

    // 🔥 Identify the Most Dangerous Enemy
    String targetEnemy = _identifyHighestThreat(enemies, enemyWeapons);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("⚠️ Battle Outcome",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              LinearProgressIndicator(
                  value: duration / (duration + 1),
                  color: Colors.blue,
                  minHeight: 10),
              SizedBox(height: 10),
              Text(battleResult),
              Text("⌚ Battle Duration: ${duration.toStringAsFixed(2)} minutes"),
              Text("🚹 Remaining Forces: $remainingForces"),
              SizedBox(height: 10),
              Text("🎯 Recommended Target: $targetEnemy"),
              SizedBox(height: 10),
              ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Close")),
            ],
          ),
        );
      },
    );
  }

// 📊 Threat Analysis Function
  String _identifyHighestThreat(
      List<dynamic> enemies, List<dynamic> enemyWeapons) {
    String mostDangerousEnemy = "";
    double highestThreatScore = 0;

    for (var enemy in enemies) {
      String enemyName = enemy['enemyName'];
      double manpower = double.parse(enemy['manpower']);

      // Find associated weapon (if any)
      var enemyWeapon = enemyWeapons.firstWhere(
        (weapon) => weapon['operationName'] == enemy['operationName'],
        orElse: () => <String, dynamic>{}, // ✅ Correct: Return an empty map
      );

      double weaponPower = 0;
      if (enemyWeapon.isNotEmpty) {
        double blastRadius = blastRadiusMap[enemyWeapon['weaponType']] ?? 1.0;
        int rateOfFire = rateOfFireMap[enemyWeapon['weaponType']] ?? 1;
        weaponPower =
            int.parse(enemyWeapon['ammoAmount']) * blastRadius * rateOfFire;
      }

      // 🔥 Calculate Threat Score (70% Weapon, 30% Manpower)
      double threatScore = (manpower * 0.3) + (weaponPower * 0.7);

      if (threatScore > highestThreatScore) {
        highestThreatScore = threatScore;
        mostDangerousEnemy = enemyName;
      }
    }

    return mostDangerousEnemy.isNotEmpty
        ? "Attack $mostDangerousEnemy first!"
        : "No high-threat enemy identified.";
  }

  void _calculateRoutesForOperation(String operationName) async {
    // Fetch all units and enemies related to the given operation
    final units = await DatabaseHelper().fetchUnits(operationName);
    final enemies = await DatabaseHelper().fetchEnemies(operationName);

    // List to store all the calculated routes as polylines
    List<Polyline> allRoutes = [];

    for (var unit in units) {
      for (var enemy in enemies) {
        // Calculate route from unit to enemy
        final route = await calculateRoute(
            LatLng(unit['latitude'], unit['longitude']),
            LatLng(enemy['latitude'], enemy['longitude']));

        if (route != null && route.isNotEmpty) {
          // Add the route to the list as a Polyline
          allRoutes.add(Polyline(
            points: route, // List<LatLng>
            strokeWidth: 3.0,
            color: Colors
                .blue, // You can change the color or add logic for different colors
          ));
        }
      }
    }

    // Store the calculated routes in your state
    setState(() {
      _allRoutes = allRoutes; // Update the list of all routes
    });

    // Optionally, show a snackbar or another confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Routes calculated for $operationName')),
    );
  }

  Future<List<LatLng>?> calculateRoute(LatLng start, LatLng end) async {
    final gridSize = 50;

    final bounds = LatLngBounds.fromPoints([start, end]);
    final margin = 0.001;
    final expandedBounds = LatLngBounds(
      LatLng(bounds.south - margin, bounds.west - margin),
      LatLng(bounds.north + margin, bounds.east + margin),
    );

    final expandedObstacles = expandObstacles(obstacles, 0.001);
    final grid = generateGrid(gridSize, expandedBounds, expandedObstacles);

    final startNode = latLngToGridPoint(start, expandedBounds, gridSize);
    final endNode = latLngToGridPoint(end, expandedBounds, gridSize);

    // Validate start and end nodes
    if (!isWithinGrid(startNode, gridSize) ||
        !isWithinGrid(endNode, gridSize)) {
      print('Start or End node is out of grid bounds.');
      return null;
    }

    final path = aStar(grid, startNode, endNode);
    if (path.isNotEmpty) {
      return path
          .map((node) => gridPointToLatLng(node, expandedBounds, gridSize))
          .toList();
    }

    return null;
  }

  List<Obstacle> expandObstacles(List<Obstacle> obstacles, double radius) {
    final expandedObstacles = <Obstacle>[];
    for (var obs in obstacles) {
      if (obs.type == ObstacleType.river || obs.type == ObstacleType.stream) {
        if (obs.type == ObstacleType.bridge) {
          expandedObstacles.add(obs);
        } else {
          for (var angle = 0; angle < 360; angle += 10) {
            final radians = angle * (pi / 180);
            expandedObstacles.add(Obstacle(
              id: obs.id,
              location: LatLng(
                obs.location.latitude + radius * cos(radians),
                obs.location.longitude + radius * sin(radians),
              ),
              type: obs.type,
            ));
          }
        }
      } else {
        for (var angle = 0; angle < 360; angle += 10) {
          final radians = angle * (pi / 180);
          expandedObstacles.add(Obstacle(
            id: obs.id,
            location: LatLng(
              obs.location.latitude + radius * cos(radians),
              obs.location.longitude + radius * sin(radians),
            ),
            type: obs.type,
          ));
        }
      }
    }
    return expandedObstacles;
  }

  void blockRouteInGrid(List<List<int>> grid, List<Point<int>> route) {
    // Iterate through each point in the route.
    for (var point in route) {
      // Ensure the point is within valid grid bounds.
      if (_isPointWithinBounds(point, grid)) {
        // Mark the cell as an obstacle.
        grid[point.y][point.x] = 1;
      } else {
        // Log or handle out-of-bounds points if necessary.
        print("Warning: Skipping out-of-bounds point: $point");
      }
    }
  }

  /// Helper method to check if a point is within the bounds of the grid.
  /// Ensures that the x and y coordinates of the point are valid for the given grid.
  bool _isPointWithinBounds(Point<int> point, List<List<int>> grid) {
    return point.x >= 0 &&
        point.x < grid[0].length &&
        point.y >= 0 &&
        point.y < grid.length;
  }

  /// Generate the grid with realistic obstacle logic.
  List<List<int>> generateGrid(
      int size, LatLngBounds bounds, List<Obstacle> obstacles) {
    final grid = List.generate(size, (_) => List.filled(size, 0));

    for (var obs in obstacles) {
      final point = latLngToGridPoint(obs.location, bounds, size);

      // Impassable obstacles
      if (obs.type == ObstacleType.lake ||
          obs.type == ObstacleType.building ||
          obs.type == ObstacleType.mountain ||
          obs.type == ObstacleType.hill) {
        grid[point.y][point.x] = 1; // Mark as impassable

        // Rivers/streams are impassable except at bridges
      } else if (obs.type == ObstacleType.river ||
          obs.type == ObstacleType.stream) {
        grid[point.y][point.x] = 1; // Default to blocked
      } else if (obs.type == ObstacleType.bridge) {
        grid[point.y][point.x] = 0; // Allow passage at bridges
      }
    }

    return grid;
  }

  /// Convert LatLng to grid coordinates.
  Point<int> latLngToGridPoint(
      LatLng latLng, LatLngBounds bounds, int gridSize) {
    final normalizedLat =
        (latLng.latitude - bounds.south) / (bounds.north - bounds.south);
    final normalizedLng =
        (latLng.longitude - bounds.west) / (bounds.east - bounds.west);

    // Scale to grid size
    var x = (normalizedLng * gridSize).floor();
    var y = (normalizedLat * gridSize).floor();

    // Clamp values to grid bounds
    x = x.clamp(0, gridSize - 1);
    y = y.clamp(0, gridSize - 1);

    return Point(x, y);
  }

  LatLng gridPointToLatLng(
      Point<int> point, LatLngBounds bounds, int gridSize) {
    final normalizedLat = point.y / gridSize;
    final normalizedLng = point.x / gridSize;

    final lat = bounds.south + normalizedLat * (bounds.north - bounds.south);
    final lng = bounds.west + normalizedLng * (bounds.east - bounds.west);

    return LatLng(lat, lng);
  }

  bool isWithinGrid(Point<int> point, int gridSize) {
    return point.x >= 0 &&
        point.x < gridSize &&
        point.y >= 0 &&
        point.y < gridSize;
  }

  /// Enhanced A* algorithm with realistic military logic.
  List<Point<int>> aStar(
      List<List<int>> grid, Point<int> start, Point<int> end) {
    final openSet = <Point<int>>{start};
    final cameFrom = <Point<int>, Point<int>>{};
    final gScore = <Point<int>, double>{start: 0};
    final fScore = <Point<int>, double>{start: heuristic(start, end)};

    while (openSet.isNotEmpty) {
      final current = openSet.reduce((a, b) =>
          (fScore[a] ?? double.infinity) < (fScore[b] ?? double.infinity)
              ? a
              : b);

      if (current == end) {
        final path = <Point<int>>[];
        var temp = current;
        while (cameFrom.containsKey(temp)) {
          path.add(temp);
          temp = cameFrom[temp]!;
        }
        return path.reversed.toList();
      }

      openSet.remove(current);

      for (final neighbor in getNeighbors(current, grid)) {
        // Skip rivers/streams unless it's a bridge
        if (_isWaterObstacle(current, neighbor, grid)) {
          continue;
        }

        final tentativeGScore = (gScore[current] ?? double.infinity) + 1;

        if (tentativeGScore < (gScore[neighbor] ?? double.infinity)) {
          cameFrom[neighbor] = current;
          gScore[neighbor] = tentativeGScore;
          fScore[neighbor] = tentativeGScore + heuristic(neighbor, end);
          openSet.add(neighbor);
        }
      }
    }

    return [];
  }

  /// Checks if a move crosses a river or stream without a bridge.
  bool _isWaterObstacle(
      Point<int> current, Point<int> neighbor, List<List<int>> grid) {
    final currentValue = grid[current.y][current.x];
    final neighborValue = grid[neighbor.y][neighbor.x];

    // Block movement into river/stream unless it's a bridge (0)
    return (neighborValue == 1 && currentValue != 0);
  }

  /// Get neighboring points with diagonal movement for realism.
  List<Point<int>> getNeighbors(Point<int> point, List<List<int>> grid) {
    final neighbors = <Point<int>>[];
    final directions = [
      Point(-1, 0), // Left
      Point(1, 0), // Right
      Point(0, -1), // Up
      Point(0, 1), // Down
      Point(-1, -1), // Diagonal Top-Left
      Point(-1, 1), // Diagonal Bottom-Left
      Point(1, -1), // Diagonal Top-Right
      Point(1, 1), // Diagonal Bottom-Right
    ];

    for (var dir in directions) {
      final neighbor = Point(point.x + dir.x, point.y + dir.y);

      if (isWithinGrid(neighbor, grid.length) &&
          grid[neighbor.y][neighbor.x] == 0) {
        neighbors.add(neighbor);
      }
    }

    return neighbors;
  }

  /// Heuristic with diagonal movement considered.
  double heuristic(Point<int> a, Point<int> b) {
    final dx = (a.x - b.x).abs();
    final dy = (a.y - b.y).abs();
    return dx + dy - (0.5 * min(dx, dy));
  }

  Future<void> _loadMarkersOnMap() async {
    final markers = await _loadAllMarkers();
    setState(() {
      _allMarkers = markers;
    });
  }

  /// Build Unit Markers for all operations with tap and long press
  Future<List<Marker>> _buildAllUnitMarkers() async {
    final units = await DatabaseHelper().fetchAllUnits();
    return units.map((unit) {
      return Marker(
        point: LatLng(unit['latitude'], unit['longitude']),
        width: 30.0,
        height: 30.0,
        child: GestureDetector(
          onTap: () {
            _showMarkerDetails(context, unit, 'Unit');
          },
          onLongPress: () {
            _confirmDeleteMarker(context, unit, 'Unit');
          },
          child: Icon(
            Icons.military_tech,
            color: const Color.fromARGB(255, 31, 85, 185),
            size: 30,
          ),
        ),
      );
    }).toList();
  }

  /// Build Enemy Markers for all operations with tap and long press
  Future<List<Marker>> _buildAllEnemyMarkers() async {
    final enemies = await DatabaseHelper().fetchAllEnemies();
    return enemies.map((enemy) {
      return Marker(
        point: LatLng(enemy['latitude'], enemy['longitude']),
        width: 30.0,
        height: 30.0,
        child: GestureDetector(
          onTap: () {
            _showMarkerDetails(context, enemy, 'Enemy');
          },
          onLongPress: () {
            _confirmDeleteMarker(context, enemy, 'Enemy');
          },
          child: Icon(
            Icons.dangerous,
            color: Colors.red,
            size: 30,
          ),
        ),
      );
    }).toList();
  }

  /// Build Weapon Markers for all operations with tap and long press
  Future<List<Marker>> _buildAllWeaponMarkers() async {
    final weapons = await DatabaseHelper().fetchAllWeapons();
    return weapons.map((weapon) {
      return Marker(
        point: LatLng(weapon['latitude'], weapon['longitude']),
        width: 30.0,
        height: 30.0,
        child: GestureDetector(
          onTap: () {
            _showMarkerDetails(context, weapon, 'Weapon');
          },
          onLongPress: () {
            _confirmDeleteMarker(context, weapon, 'Weapon');
          },
          child: Icon(
            Icons.call_merge,
            color: Colors.blue,
            size: 30,
          ),
        ),
      );
    }).toList();
  }

  /// Build Weapon Markers for all operations with tap and long press
  Future<List<Marker>> _buildAllEnemyWeaponMarkers() async {
    final enemyweapons = await DatabaseHelper().fetchAllEnemyWeapons();
    return enemyweapons.map((enemyweapons) {
      return Marker(
        point: LatLng(enemyweapons['latitude'], enemyweapons['longitude']),
        width: 30.0,
        height: 30.0,
        child: GestureDetector(
          onTap: () {
            _showMarkerDetails(context, enemyweapons, 'EnemyWeapon');
          },
          onLongPress: () {
            _confirmDeleteMarker(context, enemyweapons, 'EnemyWeapon');
          },
          child: Icon(
            Icons.call_merge,
            color: Colors.red,
            size: 30,
          ),
        ),
      );
    }).toList();
  }

  void _showMarkerDetails(
      BuildContext context, Map<String, dynamic> data, String type) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$type Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              ...data.entries
                  .map((entry) => Text('${entry.key}: ${entry.value}'))
                  .toList(),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteMarker(
      BuildContext context, Map<String, dynamic> data, String type) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete $type'),
          content: Text('Are you sure you want to delete this $type marker?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _deleteMarker(data, type);
                Navigator.of(context).pop();
                _refreshMap(); // Refresh markers after deletion
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// Delete the marker and refresh the map
  Future<void> _deleteMarker(Map<String, dynamic> data, String type) async {
    switch (type) {
      case 'Unit':
        await DatabaseHelper().deleteUnit(data);
        break;
      case 'Enemy':
        await DatabaseHelper().deleteEnemy(data);
        break;
      case 'Weapon':
        await DatabaseHelper().deleteWeapon(data);
        break;
      case 'EnemyWeapon':
        await DatabaseHelper().deleteEnemyWeapon(data);
        break;
    }
  }

  /// Refresh the map markers after deletion
  void _refreshMap() async {
    final updatedMarkers = await _loadAllMarkers();
    setState(() {
      _allMarkers = updatedMarkers; // Ensure _allMarkers is used in MarkerLayer
    });
  }

// 2. Load and Combine All Markers
  Future<List<Marker>> _loadAllMarkers() async {
    final unitMarkers = await _buildAllUnitMarkers();
    final enemyMarkers = await _buildAllEnemyMarkers();
    final weaponMarkers = await _buildAllWeaponMarkers();
    final enemyweaponMarkers = await _buildAllEnemyWeaponMarkers();

    return [
      ...unitMarkers,
      ...enemyMarkers,
      ...weaponMarkers,
      ...enemyweaponMarkers
    ];
  }

  Future<List<Map<String, dynamic>>> fetchNaturalFeatures(
      double south, double west, double north, double east) async {
    final query = '''
    [out:json];
    (
      node["natural"="water"](bbox:$south, $west, $north, $east);
      way["natural"="water"](bbox:$south, $west, $north, $east);
      relation["natural"="water"](bbox:$south, $west, $north, $east);
    );
    out body geom;
  ''';

    final url =
        'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['elements'] as List<Map<String, dynamic>>;
    } else {
      throw Exception('Failed to fetch natural features');
    }
  }

  List<Polyline> _buildNaturalFeaturePolylines(
      List<Map<String, dynamic>> features) {
    return features.where((feature) => feature['type'] == 'way').map((feature) {
      final geometry = feature['geometry'] as List<dynamic>;
      final points =
          geometry.map((point) => LatLng(point['lat'], point['lon'])).toList();

      return Polyline(
        points: points,
        strokeWidth: 3.0,
        color: Colors.blue, // Set color based on feature type
      );
    }).toList();
  }

  Marker _buildObstacleMarker(Obstacle obstacle) {
    IconData iconData;
    Color color;

    switch (obstacle.type) {
      case ObstacleType.building:
        iconData = Icons.location_city;
        color = const Color.fromARGB(255, 215, 14, 255);
        break;
      case ObstacleType.pool:
        iconData = Icons.pool;
        color = Colors.blueAccent;
        break;
      case ObstacleType.bridge:
        iconData = Icons.swap_horiz;
        color = const Color.fromARGB(255, 240, 6, 123);
        break;
      case ObstacleType.river:
        iconData = Icons.kayaking;
        color = const Color.fromARGB(255, 5, 8, 214);
        break;
      case ObstacleType.stream:
        iconData = Icons.waves;
        color = Colors.cyan;
        break;
      case ObstacleType.lake:
        iconData = Icons.kitesurfing;
        color = const Color.fromARGB(255, 144, 221, 108);
        break;
      case ObstacleType.mountain:
        iconData = Icons.terrain;
        color = Colors.green;
        break;
      case ObstacleType.hill:
        iconData = Icons.park;
        color = Colors.lightGreen;
        break;
    }

    return Marker(
      width: 50,
      height: 50,
      point: obstacle.location,
      child: GestureDetector(
        // onLongPress: () => _confirmDeleteObstacle(obstacle),
        child: Icon(
          iconData,
          color: color,
        ),
      ),
    );
  }

  void _confirmDeleteObstacle(Obstacle obstacle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Obstacle"),
          content: const Text("Are you sure you want to delete this obstacle?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            TextButton(
              child: const Text("Delete"),
              onPressed: () {
                _deleteObstacle(obstacle);
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteObstacle(Obstacle obstacle) async {
    String url = 'http://militarycommand.atwebpages.com/delete_obstacle.php';

    try {
      final response = await http.post(
        Uri.parse(url),
        body: {'id': obstacle.id.toString()}, // ✅ Use obstacle.id
      );

      if (response.statusCode == 200) {
        var result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          print('Obstacle deleted successfully');
          _fetchObstacles(); // Refresh after deletion
        } else {
          print('Failed to delete obstacle: ${result['message']}');
        }
      } else {
        print('Failed to delete obstacle. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting obstacle: $e');
    }
  }

  Future<void> fetchLocations() async {
    String uri = "http://militarycommand.atwebpages.com/all_location.php";

    try {
      var response = await http.get(Uri.parse(uri));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _locations = List<Map<String, dynamic>>.from(data);
        });
        await _saveLocations(); // Save locations after fetching
      } else {
        throw Exception('Failed to load locations');
      }
    } catch (error) {
      print('Error fetching locations: $error');
    }
  }

  Future<void> _loadSavedLocations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedLocations = prefs.getString('locations');
    if (savedLocations != null && savedLocations.isNotEmpty) {
      setState(() {
        _locations =
            List<Map<String, dynamic>>.from(json.decode(savedLocations));
      });
      print('Loaded saved locations: $_locations');
    } else {
      print('No saved locations found');
    }
  }

  Future<void> _saveLocations() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('locations', json.encode(_locations));
    print('Locations saved');
  }

  Future<void> _fetchObstacles() async {
    final url =
        Uri.parse('http://militarycommand.atwebpages.com/fetch_obstacles.php');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      List<dynamic> obstacleData = jsonDecode(response.body);

      setState(() {
        obstacles =
            obstacleData.map((data) => Obstacle.fromJson(data)).toList();
      });

      await _saveobstacle(); // Save locations after fetching
      print('Success to fetch obstacles');
    } else {
      print('Failed to fetch obstacles');
    }
  }

  Future<void> _loadSavedobstacle() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedObstacle = prefs.getString('obstacle');

    if (savedObstacle != null && savedObstacle.isNotEmpty) {
      List<dynamic> obstacleData = json.decode(savedObstacle);

      setState(() {
        obstacles =
            obstacleData.map((data) => Obstacle.fromJson(data)).toList();
      });

      print('Loaded saved obstacles');
    } else {
      print('No saved obstacles found');
    }
  }

  Future<void> _saveobstacle() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> obstacleData =
        obstacles.map((obstacle) => obstacle.toJson()).toList();

    await prefs.setString('obstacle', json.encode(obstacleData));
    print('Obstacles saved');
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.none) {
        // Handle offline mode
        print('No internet connection');
        _loadSavedLocations(); // Load saved locations when offline
        _loadSavedobstacle(); // Load saved locations when offline
      } else {
        // Handle online mode
        print('Connected to internet');
        fetchLocations(); // Re-fetch locations when online
      }
    });
  }

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  Future<void> _requestPermissions() async {
    // Request storage permission
    PermissionStatus status = await Permission.storage.request();
    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission is required!')),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    // Request location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is denied.')),
        );
        return;
      }
    }

    // Get the current position
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _isLocationReady = true;
      _mapController.move(
          _currentLocation, 14); // Center the map on the user's location
    });
  }

  Future<void> _pickMbTilesFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Allow all file types
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path;
        if (filePath != null) {
          final mbtiles = MbTiles(mbtilesPath: filePath);
          await mbtiles.open(); // Open the MBTiles file asynchronously
          final metadata = await mbtiles.getMetadata();
          setState(() {
            _mbtiles = mbtiles;
            _metadata = metadata;
            _showGoogleHybrid = false; // Switch to MBTiles layer
            _mbtilesLayerUrl = filePath; // Set MBTiles URL to display
          });
          await _saveLastPickedFile(filePath); // Save the picked file path
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _saveLastPickedFile(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_mbtiles_file', filePath);
  }

  Future<void> _loadLastPickedFile() async {
    final prefs = await SharedPreferences.getInstance();
    final filePath = prefs.getString('last_mbtiles_file');
    if (filePath != null) {
      try {
        final mbtiles = MbTiles(mbtilesPath: filePath);
        await mbtiles.open();
        final metadata = await mbtiles.getMetadata();
        setState(() {
          _mbtiles = mbtiles;
          _metadata = metadata;
          _showGoogleHybrid = false;
          _mbtilesLayerUrl = filePath;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading previous file: $e')),
        );
      }
    }
  }

  void _searchLocation(String trim) {
    String mgrs = _searchController.text.trim();
    if (mgrs.isNotEmpty) {
      LatLng? latLng = mgrsToLatLng(mgrs);
      if (latLng != null) {
        setState(() {
          // Only move the map to the new location, without changing the currentLocation
          _mapController.move(latLng, 15.0);

          // Add a new marker for the searched location
          _searchMarkers.add(Marker(
            point: latLng,
            width: 40.0,
            height: 40.0,
            child: const Icon(
              Icons.flag,
              size: 40,
              color: Colors.blue,
            ),
          ));
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Invalid MGRS input'),
        ));
      }
    }
  }

  void _toggleLayer() {
    setState(() {
      _showGoogleHybrid = !_showGoogleHybrid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              minZoom: 11,
              maxZoom: 20,
              initialZoom: 14,
              initialCenter:
                  _currentLocation, // Set initial center to current location
              onTap: (tapPosition, point) {
                if (_isSettingTarget) {
                  _handleMapTap(point);
                }
              },
              onPositionChanged: (position, hasGesture) {
                setState(() {
                  _centerlocation = position.center ?? _centerlocation;
                  _zoomLevel = position.zoom ?? 14.0; // Store the zoom level
                });
              },
            ),
            children: [
              _showGoogleHybrid
                  ? TileLayer(
                      urlTemplate:
                          'https://mt0.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                      subdomains: ['mt0', 'mt1', 'mt2', 'mt3'],
                      tileProvider: CachedTileProvider(),
                    )
                  : TileLayer(
                      tileProvider: MbTilesTileProvider(
                        mbtiles: _mbtiles!,
                        silenceTileNotFound: false,
                      ),
                    ),
              // Center Dot Marker
              if (_drawFiringRange)
                CircleLayer(
                    circles: _buildCircles()), // Ensure CircleLayer is included
              MarkerLayer(
                markers: [
                  ..._searchMarkers,
                  ..._buildCircleCenters(),
                  ..._buildMarkers(),
                  ..._allMarkers,
                  ...obstacles.map((obs) => _buildObstacleMarker(obs)),
                  Marker(
                    point: _currentLocation,
                    width: 40.0,
                    height: 40.0,
                    child: const Icon(
                      Icons.location_on,
                      size: 40,
                      color: Colors.red,
                    ),
                  ),
                  if (_firstPoint != null)
                    Marker(
                      point: _firstPoint!,
                      width: 20.0,
                      height: 20.0,
                      child: const Icon(
                        Icons.flag,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                  if (_secondPoint != null)
                    Marker(
                      point: _secondPoint!,
                      width: 20.0,
                      height: 20.0,
                      child: const Icon(
                        Icons.flag,
                        size: 20,
                        color: Colors.green,
                      ),
                    ),
                ],
              ),
              if (_polylinePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _polylinePoints,
                    strokeWidth: 4.0,
                    color: Colors.blue, // Adjust the color as needed
                  ),
                ]),
              PolylineLayer(
                polylines: [
                  // Add existing polylines
                  ..._routepolylines.map((polyline) => Polyline(
                        points: polyline.points, // List<LatLng> expected
                        strokeWidth: polyline.strokeWidth,
                        color: polyline.color.withOpacity(0.8),
                      )),

                  // Add calculated routes
                  ..._allRoutes.map((polyline) => Polyline(
                        points: polyline.points, // List<LatLng> expected
                        strokeWidth: polyline.strokeWidth,
                        color: polyline.color
                            .withOpacity(0.8), // Ensure opacity for visibility
                      )),
                ],
              )
            ],
          ),
          // Center Dot
          GestureDetector(
            onTap:
                _handleCenterDotTap, // This calls _handleTap when the center icon is tapped
            child: Center(
              child: Icon(
                Icons.fiber_manual_record,
                size: 24,
                color: Color.fromARGB(255, 48, 226, 4),
              ),
            ),
          ),
          // Display Center Location at Top-Right
          Positioned(
            top: 20,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 5.0,
                  ),
                ],
              ),
              child: Text(
                '${MGRS.latLonToMGRS(_centerlocation.latitude, _centerlocation.longitude)}',
                style: const TextStyle(fontSize: 14.0),
              ),
            ),
          ),

          // Bottom Buttons
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
              onPressed: _toggleLayer,
              tooltip: _showGoogleHybrid
                  ? 'Show MBTiles Layer'
                  : 'Show Google Hybrid Layer',
              child: Icon(
                _showGoogleHybrid ? Icons.layers : Icons.map,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 90,
            child: FloatingActionButton(
              onPressed: () {
                // Show a dialog to input MGRS
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Search MGRS Location'),
                    content: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                          hintText:
                              'Enter MGRS format (e.g., 47Q KE 48599 41152)'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _searchLocation(_searchController.text.trim());
                        },
                        child: Text('Search'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
              child: Icon(Icons.travel_explore),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 160,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isSettingTarget = true;
                  _firstPoint = null;
                  _secondPoint = null;
                });
              }, // Method to show options
              tooltip: 'set target',
              child: const Icon(Icons.timeline_rounded),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 230,
            child: FloatingActionButton(
              onPressed: _toggleFiringRange,
              tooltip: 'Draw Weapon Firing Range',
              child: const Icon(Icons.add_circle_outline),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: FloatingActionButton(
              onPressed: () {
                // Move map to the user's current location
                _mapController.move(_currentLocation, 14);
              },
              tooltip: 'Go to Current Location',
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _pickMbTilesFile,
              tooltip: 'Pick .mbtiles File',
              child: const Icon(Icons.folder_open),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFiringRange() async {
    String? selectedRange = await _showFiringRangeDialog();
    if (selectedRange != null) {
      setState(() {
        _drawFiringRange = true;
      });
    }
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    Color getColorFromName(String colorName) {
      switch (colorName.toLowerCase()) {
        case 'blue':
          return Colors.blue;
        case 'red':
          return Colors.red;
        case 'green':
          return Colors.green;
        default:
          return Color.fromARGB(255, 13, 214, 147); // Fallback color
      }
    }

    for (var location in _locations) {
      final latitude = double.tryParse(location['latitude']) ?? 0.0;
      final longitude = double.tryParse(location['longitude']) ?? 0.0;
      final point = LatLng(latitude, longitude);
      final label = location['label'] ?? 'Unknown';
      final colorName = location['color'] ?? 'blue';

      markers.add(
        Marker(
          width: 120.0,
          height: 90.0,
          point: point,
          child: GestureDetector(
            onTap: () {
              // Handle marker tap if needed
            },
            onLongPress: () async {
              // Trigger deletion on long press
              // await _deleteLocationDetails(label);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flag,
                  color: getColorFromName(colorName),
                  size: 36.0,
                ),
                const SizedBox(height: 4.0),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8.0,
                        spreadRadius: 2.0,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 6.0),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 10.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Future<void> _deleteLocationDetails(String locationName) async {
    // Define the URL of the PHP script
    String url =
        'http://militarycommand.atwebpages.com/delete_location_data.php';

    // Create the POST request
    final response = await http.post(
      Uri.parse(url),
      body: {'locationName': locationName},
    );

    if (response.statusCode == 200) {
      // Handle successful response
      print('Response: ${response.body}');
      fetchLocations(); // Refresh locations after deletion
    } else {
      // Handle error response
      print('Failed to delete location. Status code: ${response.statusCode}');
    }
  }

  List<CircleMarker> _buildCircles() {
    List<CircleMarker> circleMarkers = [];

    for (var circle in _circles) {
      final latitude = circle['latitude'] ?? 0.0;
      final longitude = circle['longitude'] ?? 0.0;
      final radius = circle['radius'] ?? 100.0;

      final radiusInPixels = _metersToPixels(radius, _zoomLevel, latitude);

      final circleMarker = CircleMarker(
        point: LatLng(latitude, longitude),
        radius: radiusInPixels > 1 ? radiusInPixels : 50.0,
        color: Colors.transparent,
        borderStrokeWidth: 2,
        borderColor: Colors.blue,
      );

      circleMarkers.add(circleMarker);
    }

    return circleMarkers;
  }

  void _addCircle(LatLng location, double radius) {
    setState(() {
      _circles.add({
        'latitude': location.latitude,
        'longitude': location.longitude,
        'radius': radius,
      });
    });
    print('Circle added at: $location with radius: $radius');
  }

  double _metersToPixels(double meters, double? zoom, double latitude) {
    if (zoom == null) return 0.0;
    double scale = (1 << zoom.toInt()).toDouble();
    double metersPerPixel =
        (156543.03392 * math.cos(latitude * math.pi / 180)) / scale;
    return meters / metersPerPixel;
  }

  List<Marker> _buildCircleCenters() {
    List<Marker> markers = [];
    for (var circle in _circles) {
      final latitude = circle['latitude'] ?? 0.0;
      final longitude = circle['longitude'] ?? 0.0;
      final point = LatLng(latitude, longitude);

      markers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: point,
          // Replace builder with child
          child: GestureDetector(
            onTap: () => _showRemoveCircleDialog(point),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 40.0,
                  height: 40.0,
                  child: Icon(
                    Icons.circle,
                    color: const Color.fromARGB(0, 33, 149, 243),
                    size: 16.0,
                  ),
                ),
                Positioned(
                  child: Icon(
                    Icons.flag_circle_outlined,
                    color: const Color.fromARGB(255, 241, 221, 4),
                    size: 34.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return markers;
  }

  void _removeCircle(LatLng location) {
    setState(() {
      _circles.removeWhere((circle) =>
          circle['latitude'] == location.latitude &&
          circle['longitude'] == location.longitude);
    });
  }

  void _showRemoveCircleDialog(LatLng point) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Remove Circle"),
        content: Text("Do you want to remove this circle?"),
        actions: <Widget>[
          TextButton(
            child: Text("Cancel"),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
          TextButton(
            child: Text("Remove"),
            onPressed: () {
              _removeCircle(point);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<String?> _showFiringRangeDialog() {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Firing Range'),
          content: const Text('Choose MA7 or MA8 for firing range.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                _addCircle(_centerlocation, 4600); // Add MA7 range
                Navigator.of(context).pop('MA7');
              },
              child: const Text('MA7'),
            ),
            TextButton(
              onPressed: () {
                _addCircle(_centerlocation, 6350); // Add MA8 range
                Navigator.of(context).pop('MA8');
              },
              child: const Text('MA8'),
            ),
            TextButton(
              onPressed: () {
                _addCircle(_centerlocation, 8500); // Add MA6 range
                Navigator.of(context).pop('MA6(120MM)');
              },
              child: const Text('MA6(120MM)'),
            ),
          ],
        );
      },
    );
  }

  void _handleCenterDotTap() {
    final centerPoint = _centerlocation;

    _showSaveLocationDialog(centerPoint);
  }

  Future<void> _handleMapTap(LatLng point) async {
    if (_firstPoint == null) {
      setState(() {
        _firstPoint = point;
      });
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('First point selected. Tap the second point.'),
      //     duration: Duration(seconds: 1),
      //   ),
      // );
    } else if (_secondPoint == null) {
      setState(() {
        _secondPoint = point;
        _isSettingTarget = false; // Exit "Set Target" mode

        // Add points to polyline
        _polylinePoints = [_firstPoint!, _secondPoint!];
      });

      if (_firstPoint != null && _secondPoint != null) {
        final distance = haversineDistance(_firstPoint!, _secondPoint!);
        final bearing = calculateBearing(_firstPoint!, _secondPoint!);
        final bearingInMils = (bearing * 17.7777777778).toStringAsFixed(2);
        // Find the suitable weapon
        final List<Weapon> weapons = await allWeapons; // Await the weapons list
        final suitableWeapons = findWeaponsWithinRange(
            distance * 1000, weapons); // Convert km to meters

        if (suitableWeapons.isNotEmpty) {
          // Find the most suitable weapon based on gunPower, flightTime, and mil
          List<MyWeapon> myWeapons = DatabaseHelper().fetchmyWeapons();

          // Find the most suitable weapon
          Weapon mostSuitableWeapon = suitableWeapons.reduce((current, next) {
            double currentScore = calculateWeaponScore(current, myWeapons);
            double nextScore = calculateWeaponScore(next, myWeapons);
            return currentScore < nextScore
                ? current
                : next; // Lower score is better
          });

          // Show popup modal with the weapon details in table style
          showDialog(
            context: context,
            builder: (BuildContext context) {
              // Get blast radius and rate of fire for the most suitable weapon
              double blastRadius =
                  blastRadiusMap[mostSuitableWeapon.name] ?? 1.0;
              int rateOfFire = rateOfFireMap[mostSuitableWeapon.name] ?? 1;

              // Find matching weapon data
              MyWeapon? matchingWeapon = myWeapons.firstWhere(
                (myWeapon) => mostSuitableWeapon.name == myWeapon.type,
                orElse: () => MyWeapon(
                    type: mostSuitableWeapon.name, amount: 0, ammoAmount: 0),
              );
              List<Weapon> uniqueSuitableWeapons =
                  suitableWeapons.toSet().toList();
              return AlertDialog(
                title: Text('Distance & Weapon Table'),
                content: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text('Distance: ${distance.toStringAsFixed(2)} km'),
                      Text('Bearing in Mils: $bearingInMils'),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: 400),
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('အမျိုးအစား')),
                              DataColumn(label: Text('တာဝေး (မီတာ)')),
                              DataColumn(label: Text('ယမ်းအား')),
                              DataColumn(
                                  label: Text('ကျည်ပျံသန်းချိန် (စက္ကန့်)')),
                              DataColumn(label: Text('တာဝေးမေးလ်')),
                            ],
                            rows: uniqueSuitableWeapons.map((weapon) {
                              bool isMostSuitable =
                                  weapon == mostSuitableWeapon;
                              return DataRow(
                                color:
                                    MaterialStateProperty.resolveWith<Color?>(
                                  (Set<MaterialState> states) => isMostSuitable
                                      ? Colors.blue.withOpacity(0.2)
                                      : null,
                                ),
                                cells: [
                                  DataCell(
                                    Text(
                                      weapon.name,
                                      style: TextStyle(
                                        fontWeight: isMostSuitable
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    onTap: isMostSuitable
                                        ? () {
                                            // Show comment why the weapon was selected
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  backgroundColor:
                                                      Colors.grey[900],
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20)),
                                                  title: SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.feedback,
                                                            color: Colors
                                                                .amberAccent),
                                                        SizedBox(width: 10),
                                                        Text(
                                                          'သင့်လျော်သောလက်နက်ရွေးချယ်မှု',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  content:
                                                      SingleChildScrollView(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Divider(
                                                            color: Colors
                                                                .amberAccent),
                                                        Text(
                                                          'ဤလက်နက်ကိုရွေးချယ်ခြင်းမှာ အောက်ပါ အကြောင်းအရင်းများကြောင့်ဖြစ်ပါသည်-',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 16),
                                                        ),
                                                        SizedBox(height: 10),
                                                        Text(
                                                            '1️⃣ ယမ်းအား (${weapon.gunPower}) သည် တိုက်ခိုက်မှုအတွက်ထိရောက်စွာအကျိုးရှိစေသည်။',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                        Text(
                                                            '2️⃣ ကျည်ပျံသန်းချိန် (${weapon.flightTime}) စက္ကန့် သည် လျင်မြန်စွာ ပစ်ခတ်နိုင်စေသည်။',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                        Text(
                                                            '3️⃣ တာဝေးမေးလ် (${weapon.mil}) သည် ပစ်မှတ်ပေါ် အတိအကျ ပစ်ခတ်နိုင်စေသည်။',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                        Text(
                                                            '4️⃣ ထိခိုက်မှုအချင်းဝက် (${blastRadius} မီတာ) ဖြစ်၍ ပစ်မှတ်ပတ်ဝန်းကျင်တွင် ထိခိုက်မှုကျယ်ပြန့်စေသည်။',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                        Text(
                                                            '5️⃣ လက်နက်အရေအတွက် (${matchingWeapon.amount}) နှင့် ကျည်အရေအတွက် (${matchingWeapon.ammoAmount}) သည် ပစ်မှတ်အားပစ်ခတ်နိုင်ရန်လုံလောက်မှုရှိစေသည်။',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                        Text(
                                                            '6️⃣ တစ်မိနစ်ပစ်ခတ်မှုနှုန်း (Rate of Fire) သည် (${rateOfFire}) တောင့် ဖြစ်၍ ပစ်ခတ်နိုင်စွမ်းမြင့်မားသည်။',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                      ],
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                      child: Text('Close',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .amberAccent)),
                                                      style:
                                                          TextButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.grey[800],
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          }
                                        : null, // No action for other rows
                                  ),
                                  DataCell(Text(weapon.range.toString())),
                                  DataCell(Text(weapon.gunPower.toString())),
                                  DataCell(Text(weapon.flightTime.toString())),
                                  DataCell(Text(weapon.mil.toString())),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                    },
                    child: Text('Close'),
                  ),
                ],
              );
            },
          );
        } else {
          // Show popup modal when no suitable weapon is found
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Weapon Information'),
                content: SingleChildScrollView(
                  child: ListBody(
                    children: [
                      Text(
                          'အကွာအဝေး : ${distance.toStringAsFixed(2)} ကီလိုမီတာ'),
                      Text('ညွှန်းရပ်မေးလ်: $bearingInMils မေးလ်'),
                      Text('No suitable weapons found for this distance.'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the dialog
                    },
                    child: Text('Close'),
                  ),
                ],
              );
            },
          );
        }
      }
    }
  }

  double haversineDistance(LatLng point1, LatLng point2) {
    const earthRadiusKm = 6371.0; // Radius of the Earth in kilometers
    final dLat = radians(point2.latitude - point1.latitude);
    final dLon = radians(point2.longitude - point1.longitude);

    final a = pow(sin(dLat / 2), 2) +
        cos(radians(point1.latitude)) *
            cos(radians(point2.latitude)) *
            pow(sin(dLon / 2), 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double radians(double degrees) => degrees * (pi / 180);

  void _showSaveLocationDialog(LatLng location) {
    final TextEditingController labelController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save or Calculate Distance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            // TextButton(
            //   onPressed: () {
            //     _showSaveLocationForm(context); // Show save location form
            //   },
            //   child: const Text('Save Location'),
            // ),
            // TextButton(
            //   onPressed: () {
            //     _showSaveObstacleForm(
            //         context, _centerlocation); // Show save location form
            //   },
            //   child: const Text('Save Obstacles'),
            // ),
            TextButton(
              onPressed: () {
                _showSaveUnitEnemyWeapon(
                    context, _centerlocation); // Show save location form
              },
              child: const Text('Save Unit,Enemy,Weapons location'),
            ),

            // TextButton(
            //   onPressed: () {
            //     Navigator.pop(context); // Close the dialog
            //     _drawRoutes(location); // Call the method to draw routes
            //   },
            //   child: const Text('Draw Route'),
            // ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close the dialog
                final centerPoint = _centerlocation;

                // Calculate Euclidean distance and bearing
                final distance =
                    haversineDistance(_currentLocation, centerPoint);
                final bearing = calculateBearing(_currentLocation, centerPoint);
                final bearingInMils =
                    (bearing * 17.7777777778).toStringAsFixed(2);

                final List<Weapon> weapons =
                    await allWeapons; // Await the weapons list
                final suitableWeapons =
                    findWeaponsWithinRange(distance * 1000, weapons)
                        .toSet()
                        .toList();

                if (suitableWeapons.isNotEmpty) {
                  // Find the most suitable weapon based on gunPower, flightTime, and mil
                  List<MyWeapon> myWeapons = DatabaseHelper().fetchmyWeapons();

                  // Weapon mostSuitableWeapon =
                  //     suitableWeapons.reduce((current, next) {
                  //   double currentScore =
                  //       calculateWeaponScore(current, myWeapons);
                  //   double nextScore = calculateWeaponScore(next, myWeapons);
                  //   return currentScore < nextScore ? current : next;
                  // });

                  // Show popup modal with the weapon details in table style
                  // Adjust the showDialog to pass necessary data
                  // Correctly use suitableWeapons and avoid repetition
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      // Get the most suitable weapon for display

                      // Use Set<Weapon> to store unique weapons
                      Set<Weapon> displayedWeapons = {};

// Filter uitableWeapons to get unique weapons
                      suitableWeapons.where((weapon) {
                        String key =
                            '${weapon.name}_${weapon.range}_${weapon.gunPower}';
                        // Check for uniqueness using the key
                        bool isNewWeapon = !displayedWeapons.any(
                            (w) => '${w.name}_${w.range}_${w.gunPower}' == key);
                        if (isNewWeapon) {
                          displayedWeapons.add(weapon);
                        }
                        return isNewWeapon;
                      }).toList();

// Now find the most suitable weapon from displayedWeapons
                      Weapon mostSuitableWeapon =
                          displayedWeapons.reduce((current, next) {
                        double currentScore =
                            calculateWeaponScore(current, myWeapons);
                        double nextScore =
                            calculateWeaponScore(next, myWeapons);
                        return currentScore < nextScore ? current : next;
                      });

                      // Fetch the blast radius and rate of fire
                      double blastRadius =
                          blastRadiusMap[mostSuitableWeapon.name] ?? 1.0;
                      int rateOfFire =
                          rateOfFireMap[mostSuitableWeapon.name] ?? 1;

                      // Find matching weapon data
                      MyWeapon? matchingWeapon = myWeapons.firstWhere(
                        (myWeapon) => mostSuitableWeapon.name == myWeapon.type,
                        orElse: () => MyWeapon(
                            type: mostSuitableWeapon.name,
                            amount: 0,
                            ammoAmount: 0),
                      );
                      // Set<String> displayedWeapons = {};
                      return AlertDialog(
                        title: Text('Distance & Weapon Table'),
                        content: SingleChildScrollView(
                          child: Column(
                            children: [
                              Text(
                                  'Distance: ${distance.toStringAsFixed(2)} km'),
                              Text('Bearing in Mils: $bearingInMils'),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: 400),
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('အမျိုးအစား')),
                                      DataColumn(label: Text('တာဝေး (မီတာ)')),
                                      DataColumn(label: Text('ယမ်းအား')),
                                      DataColumn(
                                          label: Text(
                                              'ကျည်ပျံသန်းချိန် (စက္ကန့်)')),
                                      DataColumn(label: Text('တာဝေးမေးလ်')),
                                    ],
                                    rows:
                                        displayedWeapons.toSet().map((weapon) {
                                      bool isMostSuitable =
                                          weapon == mostSuitableWeapon;
                                      return DataRow(
                                        color: MaterialStateProperty
                                            .resolveWith<Color?>(
                                          (Set<MaterialState> states) =>
                                              isMostSuitable
                                                  ? Colors.blue.withOpacity(0.2)
                                                  : null,
                                        ),
                                        cells: [
                                          DataCell(
                                            Text(
                                              weapon.name,
                                              style: TextStyle(
                                                fontWeight: isMostSuitable
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            onTap: isMostSuitable
                                                ? () {
                                                    // Show comment why the weapon was selected
                                                    showDialog(
                                                      context: context,
                                                      builder: (BuildContext
                                                          context) {
                                                        return AlertDialog(
                                                          backgroundColor:
                                                              Colors.grey[900],
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20)),
                                                          title:
                                                              SingleChildScrollView(
                                                            scrollDirection:
                                                                Axis.horizontal,
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .feedback,
                                                                    color: Colors
                                                                        .amberAccent),
                                                                SizedBox(
                                                                    width: 10),
                                                                Text(
                                                                  'သင့်လျော်သောလက်နက်ရွေးချယ်မှု',
                                                                  style:
                                                                      TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          content:
                                                              SingleChildScrollView(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Divider(
                                                                    color: Colors
                                                                        .amberAccent),
                                                                Text(
                                                                  'ဤလက်နက်ကိုရွေးချယ်ခြင်းမှာ အောက်ပါ အကြောင်းအရင်းများကြောင့်ဖြစ်ပါသည်-',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white70,
                                                                      fontSize:
                                                                          16),
                                                                ),
                                                                SizedBox(
                                                                    height: 10),
                                                                Text(
                                                                  '1️⃣ ယမ်းအား (${weapon.gunPower}) သည် တိုက်ခိုက်မှုအတွက်ထိရောက်စွာအကျိုးရှိစေသည်။',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                                Text(
                                                                  '2️⃣ ကျည်ပျံသန်းချိန် (${weapon.flightTime}) စက္ကန့် သည် လျင်မြန်စွာ ပစ်ခတ်နိုင်စေသည်။',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                                Text(
                                                                  '3️⃣ တာဝေးမေးလ် (${weapon.mil}) သည် ပစ်မှတ်ပေါ် အတိအကျ ပစ်ခတ်နိုင်စေသည်။',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                                Text(
                                                                  '4️⃣ ထိခိုက်မှုအချင်းဝက် (${blastRadius} မီတာ) ဖြစ်၍ ပစ်မှတ်ပတ်ဝန်းကျင်တွင် ထိခိုက်မှုကျယ်ပြန့်စေသည်။',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                                Text(
                                                                  '5️⃣ လက်နက်အရေအတွက် (${matchingWeapon.amount}) နှင့် ကျည်အရေအတွက် (${matchingWeapon.ammoAmount}) သည် ပစ်မှတ်အားပစ်ခတ်နိုင်ရန်လုံလောက်မှုရှိစေသည်။',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                                Text(
                                                                  '6️⃣ တစ်မိနစ်ပစ်ခတ်မှုနှုန်း (Rate of Fire) သည် (${rateOfFire}) တောင့် ဖြစ်၍ ပစ်ခတ်နိုင်စွမ်းမြင့်မားသည်။',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () {
                                                                Navigator.of(
                                                                        context)
                                                                    .pop();
                                                              },
                                                              child: Text(
                                                                  'Close',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .amberAccent)),
                                                              style: TextButton
                                                                  .styleFrom(
                                                                backgroundColor:
                                                                    Colors.grey[
                                                                        800],
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              10),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    );
                                                  }
                                                : null, // No action for other rows
                                          ),
                                          DataCell(
                                              Text(weapon.range.toString())),
                                          DataCell(
                                              Text(weapon.gunPower.toString())),
                                          DataCell(Text(
                                              weapon.flightTime.toString())),
                                          DataCell(Text(weapon.mil.toString())),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close the dialog
                            },
                            child: Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                } else {
                  // Show popup modal when no suitable weapon is found
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Weapon Information'),
                        content: SingleChildScrollView(
                          child: ListBody(
                            children: [
                              Text(
                                  'အကွာအဝေး : ${distance.toStringAsFixed(2)} ကီလိုမီတာ'),
                              Text('ညွှန်းရပ်မေးလ်: $bearingInMils မေးလ်'),
                              Text(
                                  'No suitable weapons found for this distance.'),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close the dialog
                            },
                            child: Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
              child: const Text('Distance & Find Weapons'),
            ),
          ],
        );
      },
    );
  }

  void _showSaveUnitEnemyWeapon(BuildContext context, LatLng location) {
    final TextEditingController operationNameController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unit, Enemy, Weapons, Enemy Weapon'),
          content: const Text('Choose an option below:'),
          actions: [
            // Create New Operation Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showCreateOperationDialog(context, operationNameController);
              },
              icon: const Icon(Icons.create),
              label: const Text('Create New Operation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            SizedBox(
              height: 20,
            ),
            // Select Existing Operation Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _showSelectOperationDialog(context);
              },
              icon: const Icon(Icons.list),
              label: const Text('Select Operation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),

            // Cancel Button
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateOperationDialog(
      BuildContext context, TextEditingController controller) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Operation'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Operation Name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String operationName = controller.text.trim();
                if (operationName.isNotEmpty) {
                  await DatabaseHelper().insertOperation(operationName);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Operation "$operationName" created!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid name.')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showSelectOperationDialog(BuildContext context) async {
    List<Map<String, dynamic>> operations =
        await DatabaseHelper().fetchOperations();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Operation'),
          content: operations.isNotEmpty
              ? SizedBox(
                  height: 200,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: operations.length,
                    itemBuilder: (context, index) {
                      final operation = operations[index];
                      return ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(operation['name']),
                        subtitle: Text('Created at: ${operation['createdAt']}'),
                        onTap: () {
                          // Show action sheet when the operation is tapped
                          _showOperationActions(context, operation['name']);
                        },
                      );
                    },
                  ),
                )
              : const Text('No operations found.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showOperationActions(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Operation Actions'),
          content: Text('Choose an action for "$name":'),
          actions: [
            // Select button to show save options
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSaveOptionsDialog(
                    context, name); // New dialog for Unit, Enemy, Weapon
              },
              child: const Text('Select'),
            ),
            // Delete button to remove the operation
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteOperation(context, name); // Delete operation
              },
              child: const Text('Delete'),
            ),
            // TDSS button to calculate routes
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _calculateRoutesForOperation(name);
                _calculateBattleLanchester(
                    name); // Calculate routes for the operation
              },
              child: const Text('TDSS'),
            ),
            // Cancel button
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected: $name')),
                );
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Shows options to save Unit, Enemy, or Weapon
  void _showSaveOptionsDialog(BuildContext context, String operationName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Data'),
          content: const Text('Select what you want to save:'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showUnitForm(context, operationName, _centerlocation);
              },
              child: const Text('Unit'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEnemyForm(context, operationName, _centerlocation);
              },
              child: const Text('Enemy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showWeaponForm(context, operationName, _centerlocation);
              },
              child: const Text('Weapon'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEnemyWeaponForm(context, operationName, _centerlocation);
              },
              child: const Text('Enemy Weapon'),
            ),
          ],
        );
      },
    );
  }

  // Updated Unit Save Form
  void _showUnitForm(
      BuildContext context, String operationName, LatLng location) {
    final TextEditingController unitNameController = TextEditingController();
    final TextEditingController unitManpowerController =
        TextEditingController();
    String selectedIcon = 'Infantry'; // Default icon

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Unit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: unitNameController,
                decoration: const InputDecoration(
                  labelText: 'Unit Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: unitManpowerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Unit Manpower',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedIcon,
                items: ['Infantry', 'Navy', 'Artillery']
                    .map((icon) => DropdownMenuItem(
                          value: icon,
                          child: Text(icon),
                        ))
                    .toList(),
                onChanged: (value) {
                  selectedIcon = value!;
                },
                decoration: const InputDecoration(
                  labelText: 'Unit Icon',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                String name = unitNameController.text.trim();
                String manpower = unitManpowerController.text.trim();

                if (name.isNotEmpty && manpower.isNotEmpty) {
                  // Save unit with location
                  await DatabaseHelper().insertUnit(
                      operationName, name, manpower, selectedIcon, location);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Unit "$name" saved under "$operationName"!')),
                  );
                  _loadMarkersOnMap();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

// Updated Enemy Save Form
  void _showEnemyForm(
      BuildContext context, String operationName, LatLng location) {
    final TextEditingController enemyNameController = TextEditingController();
    final TextEditingController enemyManpowerController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Enemy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: enemyNameController,
                decoration: const InputDecoration(
                  labelText: 'Enemy Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: enemyManpowerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Enemy Manpower',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                String name = enemyNameController.text.trim();
                String manpower = enemyManpowerController.text.trim();

                if (name.isNotEmpty && manpower.isNotEmpty) {
                  // Save enemy with location
                  await DatabaseHelper()
                      .insertEnemy(operationName, name, manpower, location);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Enemy "$name" saved under "$operationName"!')),
                  );
                  _loadMarkersOnMap();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

// Updated Weapon Save Form
  void _showWeaponForm(
      BuildContext context, String operationName, LatLng location) {
    String selectedWeaponType = '60mm Mortar';
    final TextEditingController ammoAmountController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Weapon'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedWeaponType,
                items: ['60mm Mortar', '81mm Mortar', '120mm Mortar']
                    .map((weapon) => DropdownMenuItem(
                          value: weapon,
                          child: Text(weapon),
                        ))
                    .toList(),
                onChanged: (value) {
                  selectedWeaponType = value!;
                },
                decoration: const InputDecoration(
                  labelText: 'Weapon Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ammoAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ammo Amount',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                String ammo = ammoAmountController.text.trim();

                if (ammo.isNotEmpty) {
                  // Save weapon with location
                  await DatabaseHelper().insertWeapon(
                      operationName, selectedWeaponType, ammo, location);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Weapon "$selectedWeaponType" saved with $ammo ammo!')),
                  );
                  _loadMarkersOnMap();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEnemyWeaponForm(
      BuildContext context, String operationName, LatLng location) {
    String selectedWeaponType = '60mm Mortar';
    final TextEditingController ammoAmountController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Weapon'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedWeaponType,
                items: ['60mm Mortar', '81mm Mortar', '120mm Mortar']
                    .map((weapon) => DropdownMenuItem(
                          value: weapon,
                          child: Text(weapon),
                        ))
                    .toList(),
                onChanged: (value) {
                  selectedWeaponType = value!;
                },
                decoration: const InputDecoration(
                  labelText: 'Weapon Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ammoAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ammo Amount',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                String ammo = ammoAmountController.text.trim();

                if (ammo.isNotEmpty) {
                  // Save weapon with location
                  await DatabaseHelper().insertEnemyWeapon(
                      operationName, selectedWeaponType, ammo, location);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Weapon "$selectedWeaponType" saved with $ammo ammo!')),
                  );
                  _loadMarkersOnMap();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteOperation(BuildContext context, String name) async {
    bool result = await DatabaseHelper().deleteOperation(name);
    if (result) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operation "$name" deleted successfully')),
      );
      Navigator.of(context).pop(); // Close the dialog
      _showSelectOperationDialog(context); // Refresh the list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete operation')),
      );
    }
  }

  void _showSaveObstacleForm(BuildContext context, LatLng location) {
    final TextEditingController labelController = TextEditingController();
    ObstacleType? selectedType;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Obstacle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              DropdownButtonFormField<ObstacleType>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Select Obstacle Type',
                ),
                items: ObstacleType.values.map((ObstacleType type) {
                  return DropdownMenuItem<ObstacleType>(
                    value: type,
                    child: Text(type.toString().split('.').last),
                  );
                }).toList(),
                onChanged: (ObstacleType? value) {
                  selectedType = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedType != null) {
                  await _saveObstacleToDatabase(location, selectedType!);
                  Navigator.pop(context);
                  _fetchObstacles();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveObstacleToDatabase(
      LatLng location, ObstacleType type) async {
    final url =
        Uri.parse('http://militarycommand.atwebpages.com/save_obstacles.php');

    final response = await http.post(
      url,
      body: {
        'latitude': _centerlocation.latitude.toString(),
        'longitude': _centerlocation.longitude.toString(),
        'type': type.toString().split('.').last,
      },
    );

    if (response.statusCode == 200) {
      print('Obstacle saved successfully');
      _fetchObstacles();
    } else {
      print('Failed to save obstacle');
    }
  }

  void _drawRoutes(LatLng centerPoint) {
    setState(() {
      // Generate three custom routes
      List<List<LatLng>> routes = [
        _generateCustomRoute(_currentLocation, centerPoint, offset: 0.01),
        _generateCustomRoute(_currentLocation, centerPoint, offset: -0.01),
        _generateCustomRoute(_currentLocation, centerPoint, offset: 0.005),
      ];

      // Determine the best route (shortest)
      List<LatLng> bestRoute = routes.reduce((current, next) {
        double currentDistance = calculateRouteDistance(current);
        double nextDistance = calculateRouteDistance(next);
        return currentDistance < nextDistance ? current : next;
      });

      // Update the polylines with the routes and highlight the best one
      _updatePolylines(routes, bestRoute);
    });
  }

// Generate a custom route with an offset for variety
  List<LatLng> _generateCustomRoute(LatLng start, LatLng end,
      {double offset = 0.0}) {
    return [
      start,
      LatLng(
        (start.latitude + end.latitude) / 2 + offset,
        (start.longitude + end.longitude) / 2 + offset,
      ),
      end,
    ];
  }

// Update the polylines on the map
  void _updatePolylines(List<List<LatLng>> routes, List<LatLng> bestRoute) {
    setState(() {
      _routepolylines = [
        ...routes.map((route) => Polyline(
              points: route,
              strokeWidth: 3.0,
              color: const Color.fromARGB(255, 206, 35, 35),
            )),
        Polyline(
          points: bestRoute,
          strokeWidth: 5.0,
          color: Colors.blue, // Highlighted color for the best route
        ),
      ];
    });
  }

// Calculate the total distance of a route
  double calculateRouteDistance(List<LatLng> route) {
    double totalDistance = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      totalDistance += haversineDistance(route[i], route[i + 1]);
    }
    return totalDistance;
  }

  double calculateEuclideanDistance(Weapon weapon, double targetDistance) {
    return (weapon.range - targetDistance).abs();
  }

  Map<String, double> blastRadiusMap = {
    'MA7': 15.0,
    'MA8': 35.0,
    '120MM': 100.0,
  };

  Map<String, int> rateOfFireMap = {
    'MA7': 18,
    'MA8': 20,
    '120MM': 10,
  };

  Map<String, dynamic> getWeaponDetails(
      Weapon weapon, List<MyWeapon> myWeapons) {
    final myWeapon = myWeapons.firstWhere(
      (mw) => mw.type == weapon.name,
      orElse: () => MyWeapon(type: weapon.name, amount: 0, ammoAmount: 0),
    );

    double blastRadius = blastRadiusMap[myWeapon.type] ?? 0.0;
    int rateOfFire = rateOfFireMap[myWeapon.type] ?? 1;

    return {
      'blastRadius': blastRadius,
      'rateOfFire': rateOfFire,
      'amount': myWeapon.amount,
      'ammoAmount': myWeapon.ammoAmount,
    };
  }

  void printMyWeapons(List<MyWeapon> myWeapons) {
    for (var weapon in myWeapons) {
      print(
          'Weapon Type: ${weapon.type}, Amount: ${weapon.amount}, Ammo Amount: ${weapon.ammoAmount}');
    }
  }

  double calculateWeaponScore(Weapon weapon, List<MyWeapon> myWeapons) {
    var details = getWeaponDetails(weapon, myWeapons);

    int amount = details['amount'];
    int ammoAmount = details['ammoAmount'];

    // If all weapons are zero, apply the alternative scoring mechanism
    if (amount == 0 || ammoAmount == 0) {
      print(
          'Weapon Type: ${weapon.name} not found or amount/ammo is zero. Applying alternative scoring.');

      // Apply the alternative scoring mechanism: Score = GunPower + FlightTime + Mils
      double score = weapon.gunPower + weapon.flightTime + weapon.mil;
      return score;
    }

    // Extract details for standard scoring mechanism
    double blastRadius = details['blastRadius'];
    int rateOfFire = details['rateOfFire'];

    // Weighted importance factors (adjustable)
    double blastRadiusWeight = 0.2;
    double amountWeight = 0.1;
    double ammoAmountWeight = 0.6;
    double rateOfFireWeight = 0.1;

    // Standard score calculation
    double score = ((weapon.gunPower + weapon.flightTime + weapon.mil)) /
        ((rateOfFire * rateOfFireWeight) *
            ((blastRadius * blastRadiusWeight) +
                (amount * amountWeight) +
                (ammoAmount * ammoAmountWeight)));

    return score;
  }

  void calculateAllWeaponScores(
      List<Weapon> weapons, List<MyWeapon> myWeapons) {
    for (var weapon in weapons) {
      double score = calculateWeaponScore(weapon, myWeapons);
      if (score != double.infinity) {
        print('Weapon: ${weapon.name}, Score: $score');
      }
    }
  }

  List<Weapon> findWeaponsWithinRange(
      double distance, List<Weapon> allWeapons) {
    return allWeapons
        .where((weapon) =>
            weapon.range >= distance - 25 && weapon.range <= distance + 25)
        .toSet()
        .toList();
  }

  void _showSaveLocationForm(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedColor =
            _selectedColor; // Local variable to manage color selection
        return AlertDialog(
          title: Text('Save Location'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller:
                        _searchController, // Use your TextEditingController
                    decoration: InputDecoration(labelText: 'Location Name'),
                  ),
                  SizedBox(height: 16.0),
                  DropdownButtonFormField<String>(
                    value: selectedColor,
                    decoration: InputDecoration(labelText: 'Select Color'),
                    items: <String>['blue', 'red', 'green'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedColor = newValue!;
                      });
                    },
                  ),
                  SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: () {
                      _saveLocationDetails(selectedColor, _centerlocation!);
                      Navigator.pop(context); // Close dialog
                    },
                    child: Text('Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _saveLocationDetails(
      String? selectedColor, LatLng locationsave) async {
    String locationName = _searchController.text;

    // Define the URL of the PHP script
    String url = 'http://militarycommand.atwebpages.com/save_location_data.php';

    // Create the POST request
    final response = await http.post(
      Uri.parse(url),
      body: {
        'locationName': locationName,
        'color': selectedColor,
        'lat': locationsave.latitude.toString(),
        'lng': locationsave.longitude.toString(),
      },
    );

    if (response.statusCode == 200) {
      // Handle successful response
      print('Response: ${response.body}');
      fetchLocations();
    } else {
      // Handle error response
      print(
          'Failed to save location details. Status code: ${response.statusCode}');
    }
  }

  /// Calculate the bearing between two points in degrees
  double calculateBearing(LatLng start, LatLng end) {
    final lat1 = degreesToRadians(start.latitude);
    final lon1 = degreesToRadians(start.longitude);
    final lat2 = degreesToRadians(end.latitude);
    final lon2 = degreesToRadians(end.longitude);

    final dLon = lon2 - lon1;

    final x = math.sin(dLon) * math.cos(lat2);
    final y = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final initialBearing = radiansToDegrees(math.atan2(x, y));
    return (initialBearing + 360) % 360; // Normalize to 0-360 degrees
  }

  /// Convert degrees to radians
  double degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Convert radians to degrees
  double radiansToDegrees(double radians) {
    return radians * (180.0 / math.pi);
  }

  Weapon? findSuitableWeapon(double distance, List<Weapon> allWeapons) {
    // Filter for weapons with a range that can handle the distance
    final suitableWeapons =
        allWeapons.where((weapon) => weapon.range >= distance).toList();

    if (suitableWeapons.isEmpty) {
      return null; // No suitable weapon found
    }

    // Find the weapon with the minimum range above the distance
    suitableWeapons.sort((a, b) => a.range.compareTo(b.range));

    return suitableWeapons.first; // Return the most suitable weapon
  }

  @override
  void dispose() {
    _mbtiles?.dispose();
    _midnightTimer?.cancel(); // Clean up the timer
    super.dispose();
  }
}

// extension on MapController {
//   double? get zoom => null;
// }

extension on MbTiles {
  open() {}
}
