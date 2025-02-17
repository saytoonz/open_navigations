import 'views/navigation_map.dart';
import 'services/route_service.dart';
import 'services/speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'services/position_service.dart';
import 'views/navigation_controls.dart';
import 'managers/navigation_manager.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => RouteService()),
        Provider(create: (_) => PositionService()),
        Provider(create: (_) => SpeechService()),
        ChangeNotifierProxyProvider3<RouteService, PositionService,
            SpeechService, NavigationManager>(
          create: (context) => NavigationManager(
            routeService: context.read<RouteService>(),
            positionService: context.read<PositionService>(),
            speechService: context.read<SpeechService>(),
          ),
          update: (context, routeService, positionService, speechService,
                  manager) =>
              manager ??
              NavigationManager(
                routeService: routeService,
                positionService: positionService,
                speechService: speechService,
              ),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late NavigationManager manager;
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      Position? position = await PositionService().getCurrentPosition();
      manager.currentPosition = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    manager = context.watch<NavigationManager>();

    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            NavigationMap(),
            NavigationControls(),
            if (context.watch<NavigationManager>().isFetching)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
