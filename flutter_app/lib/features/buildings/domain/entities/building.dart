import 'package:equatable/equatable.dart';

class Building extends Equatable {
  final String id;
  final String name;
  final String? description;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final List<Map<String, double>>? boundaryPoints;

  const Building({
    required this.id,
    required this.name,
    this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.boundaryPoints,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    address,
    latitude,
    longitude,
    createdAt,
    boundaryPoints,
  ];
}