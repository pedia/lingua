// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Progress _$ProgressFromJson(Map<String, dynamic> json) => _Progress(
  chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
  lineIndex: (json['lineIndex'] as num?)?.toInt() ?? 0,
  offset: (json['offset'] as num?)?.toDouble() ?? 0.0,
);

Map<String, dynamic> _$ProgressToJson(_Progress instance) => <String, dynamic>{
  'chapterIndex': instance.chapterIndex,
  'lineIndex': instance.lineIndex,
  'offset': instance.offset,
};

_Item _$ItemFromJson(Map<String, dynamic> json) => _Item(
  id: (json['id'] as num).toInt(),
  type: $enumDecode(_$ItemTypeEnumMap, json['type']),
  path: json['path'] as String,
  name: json['name'] as String?,
  author: json['author'] as String?,
  progress: json['progress'] == null
      ? null
      : Progress.fromJson((json['progress'] as Map).cast<String, dynamic>()),
);

Map<String, dynamic> _$ItemToJson(_Item instance) => <String, dynamic>{
  'id': instance.id,
  'type': _$ItemTypeEnumMap[instance.type]!,
  'path': instance.path,
  'name': instance.name,
  'author': instance.author,
  'progress': instance.progress?.toJson(),
};

const _$ItemTypeEnumMap = {
  ItemType.assets: 'assets',
  ItemType.file: 'file',
  ItemType.demo: 'demo',
  ItemType.debug: 'debug',
};

_ItemList _$ItemListFromJson(Map<String, dynamic> json) => _ItemList(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => Item.fromJson((e as Map).cast<String, dynamic>()))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ItemListToJson(_ItemList instance) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
};
