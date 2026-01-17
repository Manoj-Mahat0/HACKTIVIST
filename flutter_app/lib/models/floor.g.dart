// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'floor.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FloorAdapter extends TypeAdapter<Floor> {
  @override
  final int typeId = 1;

  @override
  Floor read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Floor(
      id: fields[0] as String,
      buildingId: fields[1] as String,
      floorNumber: fields[2] as int,
      name: fields[3] as String,
      floorPlanImagePath: fields[4] as String?,
      width: fields[5] as double,
      height: fields[6] as double,
      originX: fields[7] as double,
      originY: fields[8] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Floor obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.buildingId)
      ..writeByte(2)
      ..write(obj.floorNumber)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.floorPlanImagePath)
      ..writeByte(5)
      ..write(obj.width)
      ..writeByte(6)
      ..write(obj.height)
      ..writeByte(7)
      ..write(obj.originX)
      ..writeByte(8)
      ..write(obj.originY);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
