import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/task.dart';

class MapScreen extends StatelessWidget {
  final List<Task> tasks;

  const MapScreen({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final markers = tasks
        .where((t) => t.hasLocation)
        .map((t) => Marker(
              markerId: MarkerId(t.id.toString()),
              position: LatLng(t.latitude!, t.longitude!),
              infoWindow: InfoWindow(title: t.title),
            ))
        .toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de Tarefas')),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(-19.9, -43.9), // centro padrão MG
          zoom: 6,
        ),
        markers: markers,
      ),
    );
  }
}
