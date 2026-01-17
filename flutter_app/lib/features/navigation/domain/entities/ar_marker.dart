import 'package:equatable/equatable.dart';

class ArMarker extends Equatable {
  final String id;
  final double latitude;
  final double longitude;
  final int floorNumber;
  final String type;
  final String data;
  final String description;

  const ArMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.floorNumber,
    required this.type,
    required this.data,
    required this.description,
  });

  @override
  List<Object?> get props => [
    id,
    latitude,
    longitude,
    floorNumber,
    type,
    data,
    description,
  ];
}