import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../managers/navigation_manager.dart';
import 'package:flutter_map/flutter_map.dart';

class NavigationMap extends StatelessWidget {
  const NavigationMap({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<NavigationManager>();

    return FlutterMap(
      mapController: manager.mapController,
      options: MapOptions(
        initialCenter: manager.currentPosition != null
            ? LatLng(manager.currentPosition!.latitude,
                manager.currentPosition!.longitude)
            : const LatLng(0, 0),
        onLongPress: (tapPosition, latLng) {
          context.read<NavigationManager>().setDestination(latLng);
        },
        initialZoom: 16,
        onTap: (_, latLng) => _handleMapTap(context, latLng),
      ),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: const ['a', 'b', 'c'],
        ),
        _buildRoutesLayer(context),
        _buildCurrentPositionMarker(context),
        _buildStreetNameMarker(context),
        _buildDurationMarkers(context),
        _buildDestinationMarker(context),
      ],
    );
  }

  Widget _buildDestinationMarker(BuildContext context) {
    final manager = context.watch<NavigationManager>();

    return MarkerLayer(
      markers: [
        if (manager.destination != null)
          Marker(
            point: manager.destination!,
            width: 40,
            height: 40,
            child: const Icon(
              Icons.location_on,
              color: Colors.purple,
              size: 40,
            ),
          ),
      ],
    );
  }

  Widget _buildRoutesLayer(BuildContext context) {
    final manager = context.watch<NavigationManager>();

    return Stack(
      children: [
        // Inactive routes
        ...manager.routes
            .where((r) => manager.routes.indexOf(r) != manager.activeRouteIndex)
            .map(
              (route) => GestureDetector(
                onTap: () =>
                    manager.setActiveRoute(manager.routes.indexOf(route)),
                child: PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route.coordinates,
                      strokeWidth: 20,
                      color: Colors.transparent,
                    ),
                    Polyline(
                      points: route.coordinates,
                      strokeWidth: 4,
                      color: Colors.grey.withValues(alpha: .5),
                    ),
                  ],
                ),
              ),
            ),
        // Active route
        if (manager.routes.isNotEmpty)
          GestureDetector(
            onTap: () => manager.setActiveRoute(manager.activeRouteIndex),
            child: PolylineLayer(
              polylines: [
                Polyline(
                  points: manager.routes[manager.activeRouteIndex].coordinates,
                  strokeWidth: 20,
                  color: Colors.transparent,
                ),
                Polyline(
                  points: manager.routes[manager.activeRouteIndex].coordinates,
                  strokeWidth: 6,
                  color: Colors.blue,
                  strokeCap: StrokeCap.round,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentPositionMarker(BuildContext context) {
    final manager = context.watch<NavigationManager>();

    return MarkerLayer(
      markers: [
        if (manager.currentPosition != null)
          Marker(
            point: LatLng(
              manager.currentPosition!.latitude,
              manager.currentPosition!.longitude,
            ),
            width: 40,
            height: 40,
            child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
          ),
      ],
    );
  }

  Widget _buildStreetNameMarker(BuildContext context) {
    final manager = context.watch<NavigationManager>();

    return MarkerLayer(
      markers: [
        if (manager.streetName.isNotEmpty && manager.currentPosition != null)
          Marker(
            point: LatLng(
              manager.currentPosition!.latitude,
              manager.currentPosition!.longitude,
            ),
            width: 150,
            height: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8)
                ],
              ),
              child: Text(
                manager.streetName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDurationMarkers(BuildContext context) {
    final manager = context.watch<NavigationManager>();

    return MarkerLayer(
      markers: manager.routes.map((route) {
        final index = manager.routes.indexOf(route);
        return Marker(
          point: _getLabelPosition(route.coordinates),
          width: 80,
          height: 32,
          child: GestureDetector(
            onTap: () => manager.setActiveRoute(index),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: index == manager.activeRouteIndex
                    ? Colors.blue.shade900
                    : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                "${route.duration} min",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  LatLng _getLabelPosition(List<LatLng> route) {
    return route.length > 1 ? route[route.length ~/ 3] : route.first;
  }

  void _handleMapTap(BuildContext context, LatLng tappedPoint) {
    final manager = context.read<NavigationManager>();

    double minDistance = double.infinity;
    int closestIndex = -1;

    for (int i = 0; i < manager.routes.length; i++) {
      final routePoints = manager.routes[i].coordinates;
      double routeDistance = _calculateMinDistance(tappedPoint, routePoints);

      if (routeDistance < minDistance) {
        minDistance = routeDistance;
        closestIndex = i;
      }
    }

    if (closestIndex != -1 && minDistance < 50) {
      manager.setActiveRoute(closestIndex);
    }
  }

  double _calculateMinDistance(LatLng point, List<LatLng> route) {
    double minDistance = double.infinity;
    for (int i = 0; i < route.length - 1; i++) {
      final distance = _distanceToSegment(point, route[i], route[i + 1]);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    final lat1 = a.latitude;
    final lon1 = a.longitude;
    final lat2 = b.latitude;
    final lon2 = b.longitude;
    final lat3 = p.latitude;
    final lon3 = p.longitude;

    final denominator = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    if (denominator == 0) {
      return Geolocator.distanceBetween(lat3, lon3, lat1, lon1);
    }

    final t = ((lat3 - lat1) * (lat2 - lat1) + (lon3 - lon1) * (lon2 - lon1)) /
        (pow(lat2 - lat1, 2) + pow(lon2 - lon1, 2));

    final clampedT = t.clamp(0.0, 1.0);
    final nearestLat = lat1 + clampedT * (lat2 - lat1);
    final nearestLon = lon1 + clampedT * (lon2 - lon1);

    return Geolocator.distanceBetween(lat3, lon3, nearestLat, nearestLon);
  }
}
