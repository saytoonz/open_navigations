import 'package:dio/dio.dart';
import '../models/route_data.dart';
import 'package:latlong2/latlong.dart';

class RouteService {
  final Dio _dio = Dio();
  static const String _apiKey = "e73070db-21c9-46aa-9b0c-efb5c564706d";

  Future<List<RouteData>> getRoutes(LatLng start, LatLng end) async {
    try {
      final response = await _dio.get(
        "https://graphhopper.com/api/1/route",
        queryParameters: {
          "point": [
            "${start.latitude},${start.longitude}",
            "${end.latitude},${end.longitude}"
          ],
          "vehicle": "car",
          "locale": "en",
          "points_encoded": "false",
          "instructions": "true",
          "algorithm": "alternative_route",
          "alternative_route.max_paths": "3",
          "key": _apiKey,
        },
      );

      return _parseResponse(response);
    } catch (e) {
      throw Exception("Failed to fetch routes: ${e.toString()}");
    }
  }

  List<RouteData> _parseResponse(Response response) {
    return (response.data["paths"] as List)
        .take(3)
        .map((path) => RouteData(
              coordinates: (path["points"]["coordinates"] as List)
                  .map((p) => LatLng(p[1] as double, p[0] as double))
                  .toList(),
              duration: (path["time"] / 60000).toStringAsFixed(1),
              distance: (path["distance"] / 1000).toStringAsFixed(1),
              instructions: path["instructions"] ?? [],
            ))
        .toList();
  }
}
