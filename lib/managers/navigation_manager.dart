import 'dart:math';
import 'dart:async';
import '../models/route_data.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/route_service.dart';
import '../services/speech_service.dart';
import '../services/position_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';

class NavigationManager extends ChangeNotifier {
  final RouteService _routeService;
  final PositionService _positionService;
  final SpeechService _speechService;
  final MapController mapController = MapController();
  final Random _random = Random();

  List<RouteData> _routes = [];
  int _activeRouteIndex = 0;
  Position? _currentPosition;
  bool _isNavigating = false;
  bool _isSimulating = false;
  bool _isFetching = false;
  DateTime? _eta;
  double _remainingDistance = 0.0;
  String _nextInstruction = '';
  double _nextTurnDistance = 0.0;
  String _streetName = '';
  StreamSubscription<Position>? _positionSub;
  Timer? _simulationTimer;
  List<LatLng> _simulationPoints = [];
  double _simulationProgress = 0.0;
  int _lastSpokenInstructionIndex = -1;

  NavigationManager({
    required RouteService routeService,
    required PositionService positionService,
    required SpeechService speechService,
  })  : _routeService = routeService,
        _positionService = positionService,
        _speechService = speechService;

  // Getters
  List<RouteData> get routes => _routes;
  int get activeRouteIndex => _activeRouteIndex;
  Position? get currentPosition => _currentPosition;
  bool get isNavigating => _isNavigating;
  bool get isSimulating => _isSimulating;
  bool get isFetching => _isFetching;
  DateTime? get eta => _eta;
  double get remainingDistance => _remainingDistance;
  String get nextInstruction => _nextInstruction;
  double get nextTurnDistance => _nextTurnDistance;
  String get streetName => _streetName;

  set currentPosition(Position? value) {
    _currentPosition = value;
    notifyListeners();
  }

  Future<void> fetchRoutes(LatLng destination) async {
    try {
      _isFetching = true;
      notifyListeners();

      if (_currentPosition == null) return;

      final routes = await _routeService.getRoutes(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        destination,
      );

      _routes = routes;
      _activeRouteIndex = 0;
      _fitBounds();
    } catch (e) {
      _speechService.speak("Failed to fetch routes. Using cached data.");
      rethrow;
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  void setActiveRoute(int index) {
    if (index < 0 || index >= _routes.length) return;

    _activeRouteIndex = index;
    if (_isNavigating) {
      final durationMinutes = _parseRouteValue(_routes[index].duration).round();
      _remainingDistance = num.parse(_routes[index].distance) * 1000;
      _eta = DateTime.now().add(Duration(minutes: durationMinutes));
    }
    _fitBounds();
    notifyListeners();
  }

  void startNavigation() async {
    if (_routes.isEmpty) return;

    _isNavigating = true;

    final durationMinutes =
        _parseRouteValue(_routes[_activeRouteIndex].duration).round();
    _remainingDistance = num.parse(_routes[_activeRouteIndex].distance) * 1000;
    _eta = DateTime.now().add(Duration(minutes: durationMinutes));

    _positionSub?.cancel();
    _positionSub =
        (await _positionService.getPositionStream()).listen(_updatePosition);
    notifyListeners();
  }

  double _parseRouteValue(String value) {
    try {
      return num.parse(value).toDouble();
    } catch (e) {
      _speechService.speak("Invalid number format");
      throw FormatException("Invalid number format in route data");
    }
  }

  void stopNavigation() {
    _positionSub?.cancel();
    _stopSimulation();
    _isNavigating = false;
    _eta = null;
    notifyListeners();
  }

  void toggleSimulation() {
    _isSimulating = !_isSimulating;
    _isSimulating ? _startSimulation() : _stopSimulation();
    notifyListeners();
  }

  void _startSimulation() {
    _simulationPoints = _routes[_activeRouteIndex].coordinates;
    _simulationProgress = 0.0;
    _positionSub?.cancel();

    final totalPoints = _simulationPoints.length;
    _simulationTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_simulationProgress >= totalPoints - 1) {
        _stopSimulation();
        return;
      }

      _simulationProgress += 0.1;
      final index = _simulationProgress.floor();
      final fraction = _simulationProgress - index;

      if (index < _simulationPoints.length - 1) {
        final p1 = _simulationPoints[index];
        final p2 = _simulationPoints[index + 1];
        final lat = p1.latitude + (p2.latitude - p1.latitude) * fraction;
        final lng = p1.longitude + (p2.longitude - p1.longitude) * fraction;

        _updateSimulatedPosition(LatLng(lat, lng));
      }
    });
  }

  void _stopSimulation() async {
    _simulationTimer?.cancel();
    _isSimulating = false;
    if (_isNavigating) {
      _positionSub =
          (await _positionService.getPositionStream()).listen(_updatePosition);
    }
    notifyListeners();
  }

  void _updatePosition(Position position) {
    if (!_isNavigating || _isSimulating) return;
    _currentPosition = position;
    _updateNavigationData(position);
    notifyListeners();
  }

  void _updateSimulatedPosition(LatLng point) {
    final pos = Position(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      heading: _random.nextDouble() * 360,
      speed: 10.0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );

    _currentPosition = pos;
    _updateNavigationData(pos);
    notifyListeners();
  }

  void _updateNavigationData(Position position) {
    final route = _routes[_activeRouteIndex];
    final currentPoint = LatLng(position.latitude, position.longitude);

    final closestIndex =
        _findClosestPointIndex(currentPoint, route.coordinates);
    final remainingPoints = route.coordinates.sublist(closestIndex);
    _remainingDistance = _calculateDistance(remainingPoints);

    final speed = position.speed > 0 ? position.speed : 10 / 3.6;
    _eta = DateTime.now()
        .add(Duration(seconds: (_remainingDistance / speed).round()));

    final nextTurn =
        _getNextTurn(currentPoint, route.instructions, route.coordinates);
    _nextInstruction = nextTurn?['text'] ?? '';
    _nextTurnDistance = nextTurn?['distance'] ?? 0.0;
    _streetName = nextTurn?['street'] ?? '';

    if (nextTurn != null) {
      final currentInstructionIndex =
          route.instructions.indexWhere((i) => i['text'] == nextTurn['text']);

      if (currentInstructionIndex != _lastSpokenInstructionIndex) {
        _lastSpokenInstructionIndex = currentInstructionIndex;
        _speechService.speak("In ${_nextTurnDistance.round()} meters, "
            "${_nextInstruction.toLowerCase()}");
      }
    }

    _checkArrival(currentPoint, route.coordinates.last);
    notifyListeners();
  }

  void _checkArrival(LatLng currentPoint, LatLng destination) {
    final distance = Geolocator.distanceBetween(
      currentPoint.latitude,
      currentPoint.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (distance < 50) {
      _speechService.speak("You have arrived at your destination");
      stopNavigation();
    }
  }

  void _fitBounds() {
    if (_routes.isEmpty) return;
    final bounds =
        LatLngBounds.fromPoints(_routes[_activeRouteIndex].coordinates);
    mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(100),
      ),
    );
  }

  int _findClosestPointIndex(LatLng target, List<LatLng> points) {
    int index = 0;
    double minDist = double.maxFinite;
    for (int i = 0; i < points.length; i++) {
      final dist = Geolocator.distanceBetween(
        target.latitude,
        target.longitude,
        points[i].latitude,
        points[i].longitude,
      );
      if (dist < minDist) {
        minDist = dist;
        index = i;
      }
    }
    return index;
  }

  double _calculateDistance(List<LatLng> route) {
    double dist = 0.0;
    for (int i = 1; i < route.length; i++) {
      dist += Geolocator.distanceBetween(
        route[i - 1].latitude,
        route[i - 1].longitude,
        route[i].latitude,
        route[i].longitude,
      );
    }
    return dist;
  }

  Map<String, dynamic>? _getNextTurn(
      LatLng current, List<dynamic> instructions, List<LatLng> route) {
    for (var instr in instructions) {
      final interval = List<int>.from(instr['interval']);
      final point = route[interval[0]];
      final distance = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < 1000) {
        return {
          'text': instr['text'],
          'distance': distance,
          'street': instr['street_name'] ?? instr['text'] ?? 'Road',
        };
      }
    }
    return null;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _simulationTimer?.cancel();
    mapController.dispose();
    _speechService.stop();
    super.dispose();
  }
}
