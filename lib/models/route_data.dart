import 'package:latlong2/latlong.dart';

class RouteData {
  final List<LatLng> coordinates;
  final String duration;
  final String distance;
  final List<dynamic> instructions;

  RouteData({
    required this.coordinates,
    required this.duration,
    required this.distance,
    required this.instructions,
  });
}
