import 'package:indoor_navigation/features/navigation/domain/entities/navigation_response.dart';
import 'package:indoor_navigation/features/navigation/domain/entities/ar_marker.dart';

class PathPointModel extends PathPoint {
  const PathPointModel({
    required super.latitude,
    required super.longitude,
    required super.floorNumber,
  });

  factory PathPointModel.fromJson(Map<String, dynamic> json) {
    return PathPointModel(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      floorNumber: json['floor_number'],
    );
  }
}

class NavigationResponseModel extends NavigationResponse {
  const NavigationResponseModel({
    required super.path,
    required super.distance,
    required super.estimatedTime,
    required super.instructions,
  });

  factory NavigationResponseModel.fromJson(Map<String, dynamic> json) {
    return NavigationResponseModel(
      path: (json['path'] as List)
          .map((pathJson) => PathPointModel.fromJson(pathJson))
          .toList(),
      distance: json['distance'].toDouble(),
      estimatedTime: json['estimated_time'],
      instructions: List<String>.from(json['instructions']),
    );
  }
}

class ArMarkerModel extends ArMarker {
  const ArMarkerModel({
    required super.id,
    required super.latitude,
    required super.longitude,
    required super.floorNumber,
    required super.type,
    required super.data,
    required super.description,
  });

  factory ArMarkerModel.fromJson(Map<String, dynamic> json) {
    return ArMarkerModel(
      id: json['id'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      floorNumber: json['floor_number'],
      type: json['type'],
      data: json['data'],
      description: json['description'],
    );
  }
}