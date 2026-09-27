// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Progress {
  int get chapterIndex;
  int get lineIndex;
  double get offset;

  /// Create a copy of Progress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProgressCopyWith<Progress> get copyWith =>
      _$ProgressCopyWithImpl<Progress>(this as Progress, _$identity);

  /// Serializes this Progress to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Progress &&
            (identical(other.chapterIndex, chapterIndex) ||
                other.chapterIndex == chapterIndex) &&
            (identical(other.lineIndex, lineIndex) ||
                other.lineIndex == lineIndex) &&
            (identical(other.offset, offset) || other.offset == offset));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, chapterIndex, lineIndex, offset);
}

/// @nodoc
abstract mixin class $ProgressCopyWith<$Res> {
  factory $ProgressCopyWith(Progress value, $Res Function(Progress) _then) =
      _$ProgressCopyWithImpl;
  @useResult
  $Res call({int chapterIndex, int lineIndex, double offset});
}

/// @nodoc
class _$ProgressCopyWithImpl<$Res> implements $ProgressCopyWith<$Res> {
  _$ProgressCopyWithImpl(this._self, this._then);

  final Progress _self;
  final $Res Function(Progress) _then;

  /// Create a copy of Progress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterIndex = null,
    Object? lineIndex = null,
    Object? offset = null,
  }) {
    return _then(
      _self.copyWith(
        chapterIndex: null == chapterIndex
            ? _self.chapterIndex
            : chapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        lineIndex: null == lineIndex
            ? _self.lineIndex
            : lineIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        offset: null == offset
            ? _self.offset
            : offset // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// Adds pattern-matching-related methods to [Progress].
extension ProgressPatterns on Progress {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_Progress value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Progress() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_Progress value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Progress():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_Progress value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Progress() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(int chapterIndex, int lineIndex, double offset)?
    $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Progress() when $default != null:
        return $default(_that.chapterIndex, _that.lineIndex, _that.offset);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(int chapterIndex, int lineIndex, double offset) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Progress():
        return $default(_that.chapterIndex, _that.lineIndex, _that.offset);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(int chapterIndex, int lineIndex, double offset)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _Progress() when $default != null:
        return $default(_that.chapterIndex, _that.lineIndex, _that.offset);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _Progress extends Progress {
  const _Progress({
    this.chapterIndex = 0,
    this.lineIndex = 0,
    this.offset = 0.0,
  }) : super._();
  factory _Progress.fromJson(Map<String, dynamic> json) =>
      _$ProgressFromJson(json);

  @override
  @JsonKey()
  final int chapterIndex;
  @override
  @JsonKey()
  final int lineIndex;
  @override
  @JsonKey()
  final double offset;

  /// Create a copy of Progress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProgressCopyWith<_Progress> get copyWith =>
      __$ProgressCopyWithImpl<_Progress>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProgressToJson(this);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Progress &&
            (identical(other.chapterIndex, chapterIndex) ||
                other.chapterIndex == chapterIndex) &&
            (identical(other.lineIndex, lineIndex) ||
                other.lineIndex == lineIndex) &&
            (identical(other.offset, offset) || other.offset == offset));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, chapterIndex, lineIndex, offset);
}

/// @nodoc
abstract mixin class _$ProgressCopyWith<$Res>
    implements $ProgressCopyWith<$Res> {
  factory _$ProgressCopyWith(_Progress value, $Res Function(_Progress) _then) =
      __$ProgressCopyWithImpl;
  @override
  @useResult
  $Res call({int chapterIndex, int lineIndex, double offset});
}

/// @nodoc
class __$ProgressCopyWithImpl<$Res> implements _$ProgressCopyWith<$Res> {
  __$ProgressCopyWithImpl(this._self, this._then);

  final _Progress _self;
  final $Res Function(_Progress) _then;

  /// Create a copy of Progress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? chapterIndex = null,
    Object? lineIndex = null,
    Object? offset = null,
  }) {
    return _then(
      _Progress(
        chapterIndex: null == chapterIndex
            ? _self.chapterIndex
            : chapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        lineIndex: null == lineIndex
            ? _self.lineIndex
            : lineIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        offset: null == offset
            ? _self.offset
            : offset // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}
