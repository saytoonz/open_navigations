import 'package:geolocator/geolocator.dart';

class PositionService {
  Future<Position?> getCurrentPosition() async {
    if (!await checkLocationPermission()) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
  }

  Future<Stream<Position>> getPositionStream() async {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    );
  }

  Future<bool> checkLocationPermission() async {
    if (!(await Geolocator.isLocationServiceEnabled())) return false;

    LocationPermission permission;
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }
}
