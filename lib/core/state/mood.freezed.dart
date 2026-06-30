// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mood.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$MoodState {
  Mood get mood => throw _privateConstructorUsedError;

  /// Where Chispa looks: toward the side of the upcoming turn.
  TurnDirection get gaze => throw _privateConstructorUsedError;

  /// Body lean in the range -1..1 (negative left, positive right).
  double get tilt => throw _privateConstructorUsedError;

  /// True when the next maneuver is close enough to heighten attention.
  bool get turnImminent => throw _privateConstructorUsedError;

  /// Semantic line to say (rendered to EN/ES by `SpeechCatalog`), or null to
  /// stay quiet.
  SpeechLine? get line => throw _privateConstructorUsedError;

  /// Create a copy of MoodState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MoodStateCopyWith<MoodState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MoodStateCopyWith<$Res> {
  factory $MoodStateCopyWith(MoodState value, $Res Function(MoodState) then) =
      _$MoodStateCopyWithImpl<$Res, MoodState>;
  @useResult
  $Res call({
    Mood mood,
    TurnDirection gaze,
    double tilt,
    bool turnImminent,
    SpeechLine? line,
  });
}

/// @nodoc
class _$MoodStateCopyWithImpl<$Res, $Val extends MoodState>
    implements $MoodStateCopyWith<$Res> {
  _$MoodStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MoodState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mood = null,
    Object? gaze = null,
    Object? tilt = null,
    Object? turnImminent = null,
    Object? line = freezed,
  }) {
    return _then(
      _value.copyWith(
            mood: null == mood
                ? _value.mood
                : mood // ignore: cast_nullable_to_non_nullable
                      as Mood,
            gaze: null == gaze
                ? _value.gaze
                : gaze // ignore: cast_nullable_to_non_nullable
                      as TurnDirection,
            tilt: null == tilt
                ? _value.tilt
                : tilt // ignore: cast_nullable_to_non_nullable
                      as double,
            turnImminent: null == turnImminent
                ? _value.turnImminent
                : turnImminent // ignore: cast_nullable_to_non_nullable
                      as bool,
            line: freezed == line
                ? _value.line
                : line // ignore: cast_nullable_to_non_nullable
                      as SpeechLine?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MoodStateImplCopyWith<$Res>
    implements $MoodStateCopyWith<$Res> {
  factory _$$MoodStateImplCopyWith(
    _$MoodStateImpl value,
    $Res Function(_$MoodStateImpl) then,
  ) = __$$MoodStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Mood mood,
    TurnDirection gaze,
    double tilt,
    bool turnImminent,
    SpeechLine? line,
  });
}

/// @nodoc
class __$$MoodStateImplCopyWithImpl<$Res>
    extends _$MoodStateCopyWithImpl<$Res, _$MoodStateImpl>
    implements _$$MoodStateImplCopyWith<$Res> {
  __$$MoodStateImplCopyWithImpl(
    _$MoodStateImpl _value,
    $Res Function(_$MoodStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MoodState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mood = null,
    Object? gaze = null,
    Object? tilt = null,
    Object? turnImminent = null,
    Object? line = freezed,
  }) {
    return _then(
      _$MoodStateImpl(
        mood: null == mood
            ? _value.mood
            : mood // ignore: cast_nullable_to_non_nullable
                  as Mood,
        gaze: null == gaze
            ? _value.gaze
            : gaze // ignore: cast_nullable_to_non_nullable
                  as TurnDirection,
        tilt: null == tilt
            ? _value.tilt
            : tilt // ignore: cast_nullable_to_non_nullable
                  as double,
        turnImminent: null == turnImminent
            ? _value.turnImminent
            : turnImminent // ignore: cast_nullable_to_non_nullable
                  as bool,
        line: freezed == line
            ? _value.line
            : line // ignore: cast_nullable_to_non_nullable
                  as SpeechLine?,
      ),
    );
  }
}

/// @nodoc

class _$MoodStateImpl implements _MoodState {
  const _$MoodStateImpl({
    required this.mood,
    this.gaze = TurnDirection.none,
    this.tilt = 0.0,
    this.turnImminent = false,
    this.line,
  });

  @override
  final Mood mood;

  /// Where Chispa looks: toward the side of the upcoming turn.
  @override
  @JsonKey()
  final TurnDirection gaze;

  /// Body lean in the range -1..1 (negative left, positive right).
  @override
  @JsonKey()
  final double tilt;

  /// True when the next maneuver is close enough to heighten attention.
  @override
  @JsonKey()
  final bool turnImminent;

  /// Semantic line to say (rendered to EN/ES by `SpeechCatalog`), or null to
  /// stay quiet.
  @override
  final SpeechLine? line;

  @override
  String toString() {
    return 'MoodState(mood: $mood, gaze: $gaze, tilt: $tilt, turnImminent: $turnImminent, line: $line)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MoodStateImpl &&
            (identical(other.mood, mood) || other.mood == mood) &&
            (identical(other.gaze, gaze) || other.gaze == gaze) &&
            (identical(other.tilt, tilt) || other.tilt == tilt) &&
            (identical(other.turnImminent, turnImminent) ||
                other.turnImminent == turnImminent) &&
            (identical(other.line, line) || other.line == line));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, mood, gaze, tilt, turnImminent, line);

  /// Create a copy of MoodState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MoodStateImplCopyWith<_$MoodStateImpl> get copyWith =>
      __$$MoodStateImplCopyWithImpl<_$MoodStateImpl>(this, _$identity);
}

abstract class _MoodState implements MoodState {
  const factory _MoodState({
    required final Mood mood,
    final TurnDirection gaze,
    final double tilt,
    final bool turnImminent,
    final SpeechLine? line,
  }) = _$MoodStateImpl;

  @override
  Mood get mood;

  /// Where Chispa looks: toward the side of the upcoming turn.
  @override
  TurnDirection get gaze;

  /// Body lean in the range -1..1 (negative left, positive right).
  @override
  double get tilt;

  /// True when the next maneuver is close enough to heighten attention.
  @override
  bool get turnImminent;

  /// Semantic line to say (rendered to EN/ES by `SpeechCatalog`), or null to
  /// stay quiet.
  @override
  SpeechLine? get line;

  /// Create a copy of MoodState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MoodStateImplCopyWith<_$MoodStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
