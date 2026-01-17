// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RoomAdapter extends TypeAdapter<Room> {
  @override
  final int typeId = 2;

  @override
  Room read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Room(
      id: fields[0] as String,
      floorId: fields[1] as String,
      buildingId: fields[2] as String,
      name: fields[3] as String,
      type: fields[4] as String,
      x: fields[5] as double,
      y: fields[6] as double,
      width: fields[7] as double,
      height: fields[8] as double,
      entranceNodeId: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Room obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.floorId)
      ..writeByte(2)
      ..write(obj.buildingId)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.x)
      ..writeByte(6)
      ..write(obj.y)
      ..writeByte(7)
      ..write(obj.width)
      ..writeByte(8)
      ..write(obj.height)
      ..writeByte(9)
      ..write(obj.entranceNodeId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
