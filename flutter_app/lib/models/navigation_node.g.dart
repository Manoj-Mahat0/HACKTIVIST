// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_node.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NavigationNodeAdapter extends TypeAdapter<NavigationNode> {
  @override
  final int typeId = 3;

  @override
  NavigationNode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NavigationNode(
      id: fields[0] as String,
      buildingId: fields[1] as String,
      floorId: fields[2] as String,
      x: fields[3] as double,
      y: fields[4] as double,
      typeIndex: fields[5] as int,
      connectedNodeIds: (fields[6] as List).cast<String>(),
      distances: (fields[7] as Map).cast<String, double>(),
      name: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NavigationNode obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.buildingId)
      ..writeByte(2)
      ..write(obj.floorId)
      ..writeByte(3)
      ..write(obj.x)
      ..writeByte(4)
      ..write(obj.y)
      ..writeByte(5)
      ..write(obj.typeIndex)
      ..writeByte(6)
      ..write(obj.connectedNodeIds)
      ..writeByte(7)
      ..write(obj.distances)
      ..writeByte(8)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationNodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
