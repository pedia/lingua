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
