import 'package:equatable/equatable.dart';

class ArNode extends Equatable {
  final String id;
  final String? label;
  final String? cloudAnchorId;
  final double x;
  final double y;
  final double z;
  final bool isAnchor;
  final String? anchorId;
  final List<String> neighbors;

  const ArNode({
    required this.id,
    this.label,
    this.cloudAnchorId,
    required this.x,
    required this.y,
    required this.z,
    this.isAnchor = false,
    this.anchorId,
    this.neighbors = const [],
  });

  @override
  List<Object?> get props => [id, label, cloudAnchorId, x, y, z, isAnchor, anchorId, neighbors];
}
