import 'package:equatable/equatable.dart';
import 'package:indoor_navigation/features/buildings/domain/entities/building.dart';

class Analytics extends Equatable {
  final int totalBuildings;
  final int totalFloors;
  final int totalRooms;
  final int totalWaypoints;
  final List<Building> buildings;

  const Analytics({
    required this.totalBuildings,
    required this.totalFloors,
    required this.totalRooms,
    required this.totalWaypoints,
    required this.buildings,
  });

  @override
  List<Object?> get props => [
    totalBuildings,
    totalFloors,
    totalRooms,
    totalWaypoints,
    buildings,
  ];
}