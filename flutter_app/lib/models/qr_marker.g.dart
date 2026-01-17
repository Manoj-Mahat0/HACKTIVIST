// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_marker.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QRMarkerAdapter extends TypeAdapter<QRMarker> {
  @override
  final int typeId = 4;

  @override
  QRMarker read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QRMarker(
      id: fields[0] as String,
      buildingId: fields[1] as String,
      floorId: fields[2] as String,
      x: fields[3] as double,
      y: fields[4] as double,
      orientationDegrees: fields[5] as double,
      qrData: fields[6] as String,
      description: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, QRMarker obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.orientationDegrees)
      ..writeByte(6)
      ..write(obj.qrData)
      ..writeByte(7)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QRMarkerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
