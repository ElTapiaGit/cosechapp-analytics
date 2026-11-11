// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'harvest_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HarvestModelAdapter extends TypeAdapter<HarvestModel> {
  @override
  final int typeId = 0;

  @override
  HarvestModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HarvestModel(
      id: fields[0] as int,
      producerId: fields[1] as int,
      producerName: fields[2] as String,
      zoneName: fields[3] as String,
      dctoCode: fields[4] as String,
      cutDate: fields[5] as DateTime,
      nextEstimatedDate: fields[6] as DateTime,
      status: fields[7] as String,
      observation: fields[8] as String?,
      cycleMonths: fields[9] as int,
      programmer: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, HarvestModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.producerId)
      ..writeByte(2)
      ..write(obj.producerName)
      ..writeByte(3)
      ..write(obj.zoneName)
      ..writeByte(4)
      ..write(obj.dctoCode)
      ..writeByte(5)
      ..write(obj.cutDate)
      ..writeByte(6)
      ..write(obj.nextEstimatedDate)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.observation)
      ..writeByte(9)
      ..write(obj.cycleMonths)
      ..writeByte(10)
      ..write(obj.programmer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HarvestModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
