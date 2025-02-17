import './route_data.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class NavigationState extends ChangeNotifier {
  List<RouteData> _routes = [];
  int _activeRouteIndex = 0;
  Position? _currentPosition;
  bool _isNavigating = false;
  bool _isSimulating = false;
  double _currentSpeed = 0.0;
  DateTime? _eta;
  double _remainingDistance = 0.0;
  String _nextInstruction = '';
  double _nextTurnDistance = 0.0;
  String _streetName = '';
  bool _isFetching = false;

  // Getters
  List<RouteData> get routes => _routes;
  int get activeRouteIndex => _activeRouteIndex;
  Position? get currentPosition => _currentPosition;
  bool get isNavigating => _isNavigating;
  bool get isSimulating => _isSimulating;
  bool get isFetching => _isFetching;
  double get currentSpeed => _currentSpeed;
  DateTime? get eta => _eta;
  double get remainingDistance => _remainingDistance;
  String get nextInstruction => _nextInstruction;
  double get nextTurnDistance => _nextTurnDistance;
  String get streetName => _streetName;

  // Setters with notification
  set routes(List<RouteData> value) {
    _routes = value;
    notifyListeners();
  }

  set activeRouteIndex(int value) {
    _activeRouteIndex = value;
    notifyListeners();
  }

  set currentPosition(Position? value) {
    _currentPosition = value;
    notifyListeners();
  }

  set isNavigating(bool value) {
    _isNavigating = value;
    notifyListeners();
  }

  set isSimulating(bool value) {
    _isSimulating = value;
    notifyListeners();
  }

  set isFetching(bool value) {
    _isFetching = value;
    notifyListeners();
  }

  set currentSpeed(double value) {
    _currentSpeed = value;
    notifyListeners();
  }

  set eta(DateTime? value) {
    _eta = value;
    notifyListeners();
  }

  set remainingDistance(double value) {
    _remainingDistance = value;
    notifyListeners();
  }

  set nextInstruction(String value) {
    _nextInstruction = value;
    notifyListeners();
  }

  set nextTurnDistance(double value) {
    _nextTurnDistance = value;
    notifyListeners();
  }

  set streetName(String value) {
    _streetName = value;
    notifyListeners();
  }
}
