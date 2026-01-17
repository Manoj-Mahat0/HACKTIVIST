import '../../domain/entities/ar_node.dart';

class ArNodeModel extends ArNode {
  const ArNodeModel({
    required super.id,
    super.label,
    super.cloudAnchorId,
    required super.x,
    required super.y,
    required super.z,
    super.isAnchor,
    super.anchorId,
    super.neighbors,
  });

  factory ArNodeModel.fromJson(Map<String, dynamic> json) {
    return ArNodeModel(
      id: json['id'],
      label: json['label'],
      cloudAnchorId: json['cloud_anchor_id'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      isAnchor: json['is_anchor'] ?? false,
      anchorId: json['anchor_id'],
      neighbors: List<String>.from(json['neighbors'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'cloud_anchor_id': cloudAnchorId,
      'x': x,
      'y': y,
      'z': z,
      'is_anchor': isAnchor,
      'anchor_id': anchorId,
      'neighbors': neighbors,
    };
  }

  factory ArNodeModel.fromEntity(ArNode node) {
    return ArNodeModel(
      id: node.id,
      label: node.label,
      cloudAnchorId: node.cloudAnchorId,
      x: node.x,
      y: node.y,
      z: node.z,
      isAnchor: node.isAnchor,
      anchorId: node.anchorId,
      neighbors: node.neighbors,
    );
  }
}
