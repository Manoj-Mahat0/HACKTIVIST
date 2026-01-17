// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncLogAdapter extends TypeAdapter<SyncLog> {
  @override
  final int typeId = 6;

  @override
  SyncLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncLog(
      id: fields[0] as String,
      syncTypeIndex: fields[1] as int,
      itemId: fields[2] as String,
      itemName: fields[3] as String,
      statusIndex: fields[4] as int,
      timestamp: fields[5] as DateTime,
      errorMessage: fields[6] as String?,
      metadata: (fields[7] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, SyncLog obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.syncTypeIndex)
      ..writeByte(2)
      ..write(obj.itemId)
      ..writeByte(3)
      ..write(obj.itemName)
      ..writeByte(4)
      ..write(obj.statusIndex)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.errorMessage)
      ..writeByte(7)
      ..write(obj.metadata);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
