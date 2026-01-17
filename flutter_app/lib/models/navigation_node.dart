import 'package:hive/hive.dart';

part 'navigation_node.g.dart';

enum NodeType {
  corridor,
  junction,
  entrance,
  stairs,
  elevator,
  exit,
}

@HiveType(typeId: 3)
class NavigationNode extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String buildingId;

  @HiveField(2)
  final String floorId;

  @HiveField(3)
  final double x;

  @HiveField(4)
  final double y;

  @HiveField(5)
  final int typeIndex; // NodeType enum index

  @HiveField(6)
  final List<String> connectedNodeIds;

  @HiveField(7)
  final Map<String, double> distances; // nodeId -> distance

  @HiveField(8)
  final String? name;

  NavigationNode({
    required this.id,
    required this.buildingId,
    required this.floorId,
    required this.x,
    required this.y,
    required this.typeIndex,
    required this.connectedNodeIds,
    required this.distances,
    this.name,
  });

  NavigationNode.withType({
    required this.id,
    required this.buildingId,
    required this.floorId,
    required this.x,
    required this.y,
    required NodeType type,
    required this.connectedNodeIds,
    required this.distances,
    this.name,
  }) : typeIndex = type.index;

  factory NavigationNode.fromJson({
    required String id,
    required String buildingId,
    required String floorId,
    required double x,
    required double y,
    required int typeIndex,
    required List<String> connectedNodeIds,
    required Map<String, double> distances,
    String? name,
  }) {
    return NavigationNode(
      id: id,
      buildingId: buildingId,
      floorId: floorId,
      x: x,
      y: y,
      typeIndex: typeIndex,
      connectedNodeIds: connectedNodeIds,
      distances: distances,
      name: name,
    );
  }

  NodeType get type => NodeType.values[typeIndex];

  NavigationNode copyWith({
    String? id,
    String? buildingId,
    String? floorId,
    double? x,
    double? y,
    NodeType? type,
    List<String>? connectedNodeIds,
    Map<String, double>? distances,
    String? name,
  }) {
    return NavigationNode(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      floorId: floorId ?? this.floorId,
      x: x ?? this.x,
      y: y ?? this.y,
      typeIndex: type?.index ?? typeIndex,
      connectedNodeIds: connectedNodeIds ?? this.connectedNodeIds,
      distances: distances ?? this.distances,
      name: name ?? this.name,
    );
  }
}
