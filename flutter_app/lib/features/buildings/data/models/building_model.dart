import 'package:indoor_navigation/features/buildings/domain/entities/building.dart';

class BuildingModel extends Building {
  const BuildingModel({
    required super.id,
    required super.name,
    super.description,
    required super.address,
    required super.latitude,
    required super.longitude,
    required super.createdAt,
    super.boundaryPoints,
  });

  factory BuildingModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, double>>? boundaryPoints;
    if (json['boundary_points'] != null) {
      boundaryPoints = (json['boundary_points'] as List)
          .map((point) => {
                'lat': (point['lat'] as num).toDouble(),
                'lng': (point['lng'] as num).toDouble(),
              })
          .toList();
    }

    return BuildingModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      address: json['address'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      boundaryPoints: boundaryPoints,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
      if (boundaryPoints != null) 'boundary_points': boundaryPoints,
    };
  }
}