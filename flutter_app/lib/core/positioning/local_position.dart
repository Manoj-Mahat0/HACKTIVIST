import 'package:equatable/equatable.dart';

class LocalPosition extends Equatable {
  final double x; // meters from origin
  final double y; // meters from origin
  final int floor;
  final double heading; // degrees from North (0-360)
  final double accuracy; // meters
  final DateTime timestamp;

  const LocalPosition({
    required this.x,
    required this.y,
    required this.floor,
    required this.heading,
    required this.accuracy,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [x, y, floor, heading, accuracy, timestamp];

  LocalPosition copyWith({
    double? x,
    double? y,
    int? floor,
    double? heading,
    double? accuracy,
    DateTime? timestamp,
  }) {
    return LocalPosition(
      x: x ?? this.x,
      y: y ?? this.y,
      floor: floor ?? this.floor,
      heading: heading ?? this.heading,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
