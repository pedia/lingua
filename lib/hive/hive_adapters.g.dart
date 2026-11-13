// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class ProgressAdapter extends TypeAdapter<Progress> {
  @override
  final typeId = 1;

  @override
  Progress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Progress(
      ci: fields[0] == null ? 0 : (fields[0] as num).toInt(),
      li: fields[1] == null ? 0 : (fields[1] as num).toInt(),
      offset: (fields[2] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, Progress obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.ci)
      ..writeByte(1)
      ..write(obj.li)
      ..writeByte(2)
      ..write(obj.offset);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final typeId = 2;

  @override
  Item read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Item(
      id: (fields[0] as num).toInt(),
      type: fields[2] as ItemType,
      path: fields[3] as String,
      ctime: fields[1] as DateTime,
      name: fields[4] as String?,
      author: fields[5] as String?,
      description: fields[6] as String?,
      review: fields[8] as String?,
      percent: fields[7] == null ? 0 : (fields[7] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.ctime)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.path)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.author)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.percent)
      ..writeByte(8)
      ..write(obj.review);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ShopAdapter extends TypeAdapter<Shop> {
  @override
  final typeId = 3;

  @override
  Shop read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Shop(
      shelves: (fields[0] as List).cast<Shelf>(),
      current: fields[1] == null ? 0 : (fields[1] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Shop obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.shelves)
      ..writeByte(1)
      ..write(obj.current);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShopAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ShelfAdapter extends TypeAdapter<Shelf> {
  @override
  final typeId = 4;

  @override
  Shelf read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Shelf(
      id: (fields[0] as num).toInt(),
      name: fields[1] as String,
      iids: (fields[3] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, Shelf obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.iids);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShelfAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ItemStateAdapter extends TypeAdapter<ItemState> {
  @override
  final typeId = 5;

  @override
  ItemState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ItemState(
      id: (fields[0] as num).toInt(),
      read: fields[1] == null ? const Progress() : fields[1] as Progress,
      speak: fields[2] == null ? const Progress() : fields[2] as Progress,
      readChapterIndex: fields[3] == null ? 0 : (fields[3] as num).toInt(),
      offset: fields[4] == null ? 0 : (fields[4] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, ItemState obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.read)
      ..writeByte(2)
      ..write(obj.speak)
      ..writeByte(3)
      ..write(obj.readChapterIndex)
      ..writeByte(4)
      ..write(obj.offset);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ItemTypeAdapter extends TypeAdapter<ItemType> {
  @override
  final typeId = 6;

  @override
  ItemType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ItemType.assets;
      case 1:
        return ItemType.file;
      case 2:
        return ItemType.demo;
      case 3:
        return ItemType.net;
      case 4:
        return ItemType.debug;
      default:
        return ItemType.assets;
    }
  }

  @override
  void write(BinaryWriter writer, ItemType obj) {
    switch (obj) {
      case ItemType.assets:
        writer.writeByte(0);
      case ItemType.file:
        writer.writeByte(1);
      case ItemType.demo:
        writer.writeByte(2);
      case ItemType.net:
        writer.writeByte(3);
      case ItemType.debug:
        writer.writeByte(4);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NoteAdapter extends TypeAdapter<Note> {
  @override
  final typeId = 7;

  @override
  Note read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Note(ci: (fields[0] as num).toInt(), note: fields[1] as String);
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.ci)
      ..writeByte(1)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
