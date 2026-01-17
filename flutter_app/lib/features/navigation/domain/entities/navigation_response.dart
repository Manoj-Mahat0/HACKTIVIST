import 'package:equatable/equatable.dart';

class PathPoint extends Equatable {
  final double latitude;
  final double longitude;
  final int floorNumber;

  const PathPoint({
    required this.latitude,
    required this.longitude,
    required this.floorNumber,
  });

  @override
  List<Object?> get props => [latitude, longitude, floorNumber];
}

class NavigationResponse extends Equatable {
  final List<PathPoint> path;
  final double distance;
  final int estimatedTime;
  final List<String> instructions;

  const NavigationResponse({
    required this.path,
    required this.distance,
    required this.estimatedTime,
    required this.instructions,
  });

  @override
  List<Object?> get props => [path, distance, estimatedTime, instructions];
}