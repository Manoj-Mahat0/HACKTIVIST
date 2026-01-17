// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_building.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OfflineBuildingAdapter extends TypeAdapter<OfflineBuilding> {
  @override
  final int typeId = 5;

  @override
  OfflineBuilding read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OfflineBuilding(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      address: fields[3] as String,
      latitude: fields[4] as double,
      longitude: fields[5] as double,
      boundaryPoints: (fields[6] as List)
          .map((dynamic e) => (e as Map).cast<String, double>())
          .toList(),
      createdAt: fields[7] as DateTime,
      isSynced: fields[8] as bool,
      syncedAt: fields[9] as DateTime?,
      syncError: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, OfflineBuilding obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.latitude)
      ..writeByte(5)
      ..write(obj.longitude)
      ..writeByte(6)
      ..write(obj.boundaryPoints)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.isSynced)
      ..writeByte(9)
      ..write(obj.syncedAt)
      ..writeByte(10)
      ..write(obj.syncError);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineBuildingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
