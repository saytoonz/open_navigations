import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../managers/navigation_manager.dart';

class NavigationControls extends StatelessWidget {
  final LatLng defaultDestination =
      const LatLng(5.6756723715960495, -0.19368805900030137);

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<NavigationManager>();

    return Positioned(
      right: 20,
      bottom: 200,
      child: Column(
        children: [
          // Fetch Routes Button
          FloatingActionButton(
            heroTag: 'fetch_routes',
            onPressed: () => _fetchRoutes(context),
            backgroundColor: Colors.blue,
            child: const Icon(Icons.route),
          ),
          const SizedBox(height: 10),

          // Recenter Button
          FloatingActionButton(
            heroTag: 'recenter',
            onPressed: () => manager.mapController.move(
              LatLng(manager.currentPosition!.latitude,
                  manager.currentPosition!.longitude),
              manager.mapController.camera.zoom,
            ),
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 10),

          // Start/Stop Navigation Button
          FloatingActionButton(
            heroTag: 'navigation',
            onPressed: () => manager.isNavigating
                ? manager.stopNavigation()
                : manager.startNavigation(),
            backgroundColor: manager.isNavigating ? Colors.red : Colors.green,
            child: Icon(manager.isNavigating ? Icons.stop : Icons.navigation),
          ),
          const SizedBox(height: 10),

          // Simulation Toggle Button
          FloatingActionButton(
            heroTag: 'simulation',
            onPressed:
                manager.isNavigating ? () => manager.toggleSimulation() : null,
            backgroundColor:
                manager.isSimulating ? Colors.orange : Colors.purple,
            child:
                Icon(manager.isSimulating ? Icons.stop : Icons.directions_car),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchRoutes(BuildContext context) async {
    final manager = context.read<NavigationManager>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await manager.fetchRoutes(defaultDestination);
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to fetch routes: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
