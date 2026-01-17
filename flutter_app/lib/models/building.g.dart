// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'building.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BuildingAdapter extends TypeAdapter<Building> {
  @override
  final int typeId = 0;

  @override
  Building read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Building(
      id: fields[0] as String,
      name: fields[1] as String,
      address: fields[2] as String,
      downloadedAt: fields[3] as DateTime,
      version: fields[4] as int,
      boundaryPoints: (fields[5] as List)
          .map((dynamic e) => (e as Map).cast<String, double>())
          .toList(),
    );
  }

  @override
  void write(BinaryWriter writer, Building obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.downloadedAt)
      ..writeByte(4)
      ..write(obj.version)
      ..writeByte(5)
      ..write(obj.boundaryPoints);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuildingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
