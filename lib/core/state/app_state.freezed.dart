// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AppState {
  // --- Agentic brain (priority 1) ---
  AgentPhase get agentPhase => throw _privateConstructorUsedError;
  String? get activeToolName =>
      throw _privateConstructorUsedError; // --- Proximity / caress (priority 2) ---
  bool get proximityNear =>
      throw _privateConstructorUsedError; // --- OBD (optional; null when no adapter is connected) ---
  bool? get dtcPresent => throw _privateConstructorUsedError;
  double? get coolantTempC => throw _privateConstructorUsedError;
  double? get rpm =>
      throw _privateConstructorUsedError; // --- Phone motion sensors (always available, already low-pass filtered) ---
  /// Longitudinal g: positive accelerating, negative braking.
  double get longitudinalG => throw _privateConstructorUsedError;

  /// Vertical g spike, used to detect bumps.
  double get verticalG => throw _privateConstructorUsedError;

  /// Lateral g, used to detect curves.
  double get lateralG => throw _privateConstructorUsedError;

  /// Turn rate about the vertical axis (rad/s) from the gyroscope. Drives the
  /// continuous lean into curves.
  double get yawRate =>
      throw _privateConstructorUsedError; // --- Speed (GPS, fused with the accelerometer between fixes) ---
  double get speedKmh =>
      throw _privateConstructorUsedError; // --- Navigation (optional) ---
  bool get arrived => throw _privateConstructorUsedError;
  TurnDirection get turnDirection => throw _privateConstructorUsedError;
  double? get turnDistanceM =>
      throw _privateConstructorUsedError; // --- Stillness ---
  Duration get stillFor =>
      throw _privateConstructorUsedError; // --- Ambient light ---
  double get lux => throw _privateConstructorUsedError;

  /// Create a copy of AppState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppStateCopyWith<AppState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppStateCopyWith<$Res> {
  factory $AppStateCopyWith(AppState value, $Res Function(AppState) then) =
      _$AppStateCopyWithImpl<$Res, AppState>;
  @useResult
  $Res call({
    AgentPhase agentPhase,
    String? activeToolName,
    bool proximityNear,
    bool? dtcPresent,
    double? coolantTempC,
    double? rpm,
    double longitudinalG,
    double verticalG,
    double lateralG,
    double yawRate,
    double speedKmh,
    bool arrived,
    TurnDirection turnDirection,
    double? turnDistanceM,
    Duration stillFor,
    double lux,
  });
}

/// @nodoc
class _$AppStateCopyWithImpl<$Res, $Val extends AppState>
    implements $AppStateCopyWith<$Res> {
  _$AppStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? agentPhase = null,
    Object? activeToolName = freezed,
    Object? proximityNear = null,
    Object? dtcPresent = freezed,
    Object? coolantTempC = freezed,
    Object? rpm = freezed,
    Object? longitudinalG = null,
    Object? verticalG = null,
    Object? lateralG = null,
    Object? yawRate = null,
    Object? speedKmh = null,
    Object? arrived = null,
    Object? turnDirection = null,
    Object? turnDistanceM = freezed,
    Object? stillFor = null,
    Object? lux = null,
  }) {
    return _then(
      _value.copyWith(
            agentPhase: null == agentPhase
                ? _value.agentPhase
                : agentPhase // ignore: cast_nullable_to_non_nullable
                      as AgentPhase,
            activeToolName: freezed == activeToolName
                ? _value.activeToolName
                : activeToolName // ignore: cast_nullable_to_non_nullable
                      as String?,
            proximityNear: null == proximityNear
                ? _value.proximityNear
                : proximityNear // ignore: cast_nullable_to_non_nullable
                      as bool,
            dtcPresent: freezed == dtcPresent
                ? _value.dtcPresent
                : dtcPresent // ignore: cast_nullable_to_non_nullable
                      as bool?,
            coolantTempC: freezed == coolantTempC
                ? _value.coolantTempC
                : coolantTempC // ignore: cast_nullable_to_non_nullable
                      as double?,
            rpm: freezed == rpm
                ? _value.rpm
                : rpm // ignore: cast_nullable_to_non_nullable
                      as double?,
            longitudinalG: null == longitudinalG
                ? _value.longitudinalG
                : longitudinalG // ignore: cast_nullable_to_non_nullable
                      as double,
            verticalG: null == verticalG
                ? _value.verticalG
                : verticalG // ignore: cast_nullable_to_non_nullable
                      as double,
            lateralG: null == lateralG
                ? _value.lateralG
                : lateralG // ignore: cast_nullable_to_non_nullable
                      as double,
            yawRate: null == yawRate
                ? _value.yawRate
                : yawRate // ignore: cast_nullable_to_non_nullable
                      as double,
            speedKmh: null == speedKmh
                ? _value.speedKmh
                : speedKmh // ignore: cast_nullable_to_non_nullable
                      as double,
            arrived: null == arrived
                ? _value.arrived
                : arrived // ignore: cast_nullable_to_non_nullable
                      as bool,
            turnDirection: null == turnDirection
                ? _value.turnDirection
                : turnDirection // ignore: cast_nullable_to_non_nullable
                      as TurnDirection,
            turnDistanceM: freezed == turnDistanceM
                ? _value.turnDistanceM
                : turnDistanceM // ignore: cast_nullable_to_non_nullable
                      as double?,
            stillFor: null == stillFor
                ? _value.stillFor
                : stillFor // ignore: cast_nullable_to_non_nullable
                      as Duration,
            lux: null == lux
                ? _value.lux
                : lux // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AppStateImplCopyWith<$Res>
    implements $AppStateCopyWith<$Res> {
  factory _$$AppStateImplCopyWith(
    _$AppStateImpl value,
    $Res Function(_$AppStateImpl) then,
  ) = __$$AppStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    AgentPhase agentPhase,
    String? activeToolName,
    bool proximityNear,
    bool? dtcPresent,
    double? coolantTempC,
    double? rpm,
    double longitudinalG,
    double verticalG,
    double lateralG,
    double yawRate,
    double speedKmh,
    bool arrived,
    TurnDirection turnDirection,
    double? turnDistanceM,
    Duration stillFor,
    double lux,
  });
}

/// @nodoc
class __$$AppStateImplCopyWithImpl<$Res>
    extends _$AppStateCopyWithImpl<$Res, _$AppStateImpl>
    implements _$$AppStateImplCopyWith<$Res> {
  __$$AppStateImplCopyWithImpl(
    _$AppStateImpl _value,
    $Res Function(_$AppStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? agentPhase = null,
    Object? activeToolName = freezed,
    Object? proximityNear = null,
    Object? dtcPresent = freezed,
    Object? coolantTempC = freezed,
    Object? rpm = freezed,
    Object? longitudinalG = null,
    Object? verticalG = null,
    Object? lateralG = null,
    Object? yawRate = null,
    Object? speedKmh = null,
    Object? arrived = null,
    Object? turnDirection = null,
    Object? turnDistanceM = freezed,
    Object? stillFor = null,
    Object? lux = null,
  }) {
    return _then(
      _$AppStateImpl(
        agentPhase: null == agentPhase
            ? _value.agentPhase
            : agentPhase // ignore: cast_nullable_to_non_nullable
                  as AgentPhase,
        activeToolName: freezed == activeToolName
            ? _value.activeToolName
            : activeToolName // ignore: cast_nullable_to_non_nullable
                  as String?,
        proximityNear: null == proximityNear
            ? _value.proximityNear
            : proximityNear // ignore: cast_nullable_to_non_nullable
                  as bool,
        dtcPresent: freezed == dtcPresent
            ? _value.dtcPresent
            : dtcPresent // ignore: cast_nullable_to_non_nullable
                  as bool?,
        coolantTempC: freezed == coolantTempC
            ? _value.coolantTempC
            : coolantTempC // ignore: cast_nullable_to_non_nullable
                  as double?,
        rpm: freezed == rpm
            ? _value.rpm
            : rpm // ignore: cast_nullable_to_non_nullable
                  as double?,
        longitudinalG: null == longitudinalG
            ? _value.longitudinalG
            : longitudinalG // ignore: cast_nullable_to_non_nullable
                  as double,
        verticalG: null == verticalG
            ? _value.verticalG
            : verticalG // ignore: cast_nullable_to_non_nullable
                  as double,
        lateralG: null == lateralG
            ? _value.lateralG
            : lateralG // ignore: cast_nullable_to_non_nullable
                  as double,
        yawRate: null == yawRate
            ? _value.yawRate
            : yawRate // ignore: cast_nullable_to_non_nullable
                  as double,
        speedKmh: null == speedKmh
            ? _value.speedKmh
            : speedKmh // ignore: cast_nullable_to_non_nullable
                  as double,
        arrived: null == arrived
            ? _value.arrived
            : arrived // ignore: cast_nullable_to_non_nullable
                  as bool,
        turnDirection: null == turnDirection
            ? _value.turnDirection
            : turnDirection // ignore: cast_nullable_to_non_nullable
                  as TurnDirection,
        turnDistanceM: freezed == turnDistanceM
            ? _value.turnDistanceM
            : turnDistanceM // ignore: cast_nullable_to_non_nullable
                  as double?,
        stillFor: null == stillFor
            ? _value.stillFor
            : stillFor // ignore: cast_nullable_to_non_nullable
                  as Duration,
        lux: null == lux
            ? _value.lux
            : lux // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc

class _$AppStateImpl implements _AppState {
  const _$AppStateImpl({
    this.agentPhase = AgentPhase.idle,
    this.activeToolName,
    this.proximityNear = false,
    this.dtcPresent,
    this.coolantTempC,
    this.rpm,
    this.longitudinalG = 0.0,
    this.verticalG = 0.0,
    this.lateralG = 0.0,
    this.yawRate = 0.0,
    this.speedKmh = 0.0,
    this.arrived = false,
    this.turnDirection = TurnDirection.none,
    this.turnDistanceM,
    this.stillFor = Duration.zero,
    this.lux = 12000.0,
  });

  // --- Agentic brain (priority 1) ---
  @override
  @JsonKey()
  final AgentPhase agentPhase;
  @override
  final String? activeToolName;
  // --- Proximity / caress (priority 2) ---
  @override
  @JsonKey()
  final bool proximityNear;
  // --- OBD (optional; null when no adapter is connected) ---
  @override
  final bool? dtcPresent;
  @override
  final double? coolantTempC;
  @override
  final double? rpm;
  // --- Phone motion sensors (always available, already low-pass filtered) ---
  /// Longitudinal g: positive accelerating, negative braking.
  @override
  @JsonKey()
  final double longitudinalG;

  /// Vertical g spike, used to detect bumps.
  @override
  @JsonKey()
  final double verticalG;

  /// Lateral g, used to detect curves.
  @override
  @JsonKey()
  final double lateralG;

  /// Turn rate about the vertical axis (rad/s) from the gyroscope. Drives the
  /// continuous lean into curves.
  @override
  @JsonKey()
  final double yawRate;
  // --- Speed (GPS, fused with the accelerometer between fixes) ---
  @override
  @JsonKey()
  final double speedKmh;
  // --- Navigation (optional) ---
  @override
  @JsonKey()
  final bool arrived;
  @override
  @JsonKey()
  final TurnDirection turnDirection;
  @override
  final double? turnDistanceM;
  // --- Stillness ---
  @override
  @JsonKey()
  final Duration stillFor;
  // --- Ambient light ---
  @override
  @JsonKey()
  final double lux;

  @override
  String toString() {
    return 'AppState(agentPhase: $agentPhase, activeToolName: $activeToolName, proximityNear: $proximityNear, dtcPresent: $dtcPresent, coolantTempC: $coolantTempC, rpm: $rpm, longitudinalG: $longitudinalG, verticalG: $verticalG, lateralG: $lateralG, yawRate: $yawRate, speedKmh: $speedKmh, arrived: $arrived, turnDirection: $turnDirection, turnDistanceM: $turnDistanceM, stillFor: $stillFor, lux: $lux)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AppStateImpl &&
            (identical(other.agentPhase, agentPhase) ||
                other.agentPhase == agentPhase) &&
            (identical(other.activeToolName, activeToolName) ||
                other.activeToolName == activeToolName) &&
            (identical(other.proximityNear, proximityNear) ||
                other.proximityNear == proximityNear) &&
            (identical(other.dtcPresent, dtcPresent) ||
                other.dtcPresent == dtcPresent) &&
            (identical(other.coolantTempC, coolantTempC) ||
                other.coolantTempC == coolantTempC) &&
            (identical(other.rpm, rpm) || other.rpm == rpm) &&
            (identical(other.longitudinalG, longitudinalG) ||
                other.longitudinalG == longitudinalG) &&
            (identical(other.verticalG, verticalG) ||
                other.verticalG == verticalG) &&
            (identical(other.lateralG, lateralG) ||
                other.lateralG == lateralG) &&
            (identical(other.yawRate, yawRate) || other.yawRate == yawRate) &&
            (identical(other.speedKmh, speedKmh) ||
                other.speedKmh == speedKmh) &&
            (identical(other.arrived, arrived) || other.arrived == arrived) &&
            (identical(other.turnDirection, turnDirection) ||
                other.turnDirection == turnDirection) &&
            (identical(other.turnDistanceM, turnDistanceM) ||
                other.turnDistanceM == turnDistanceM) &&
            (identical(other.stillFor, stillFor) ||
                other.stillFor == stillFor) &&
            (identical(other.lux, lux) || other.lux == lux));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    agentPhase,
    activeToolName,
    proximityNear,
    dtcPresent,
    coolantTempC,
    rpm,
    longitudinalG,
    verticalG,
    lateralG,
    yawRate,
    speedKmh,
    arrived,
    turnDirection,
    turnDistanceM,
    stillFor,
    lux,
  );

  /// Create a copy of AppState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AppStateImplCopyWith<_$AppStateImpl> get copyWith =>
      __$$AppStateImplCopyWithImpl<_$AppStateImpl>(this, _$identity);
}

abstract class _AppState implements AppState {
  const factory _AppState({
    final AgentPhase agentPhase,
    final String? activeToolName,
    final bool proximityNear,
    final bool? dtcPresent,
    final double? coolantTempC,
    final double? rpm,
    final double longitudinalG,
    final double verticalG,
    final double lateralG,
    final double yawRate,
    final double speedKmh,
    final bool arrived,
    final TurnDirection turnDirection,
    final double? turnDistanceM,
    final Duration stillFor,
    final double lux,
  }) = _$AppStateImpl;

  // --- Agentic brain (priority 1) ---
  @override
  AgentPhase get agentPhase;
  @override
  String? get activeToolName; // --- Proximity / caress (priority 2) ---
  @override
  bool get proximityNear; // --- OBD (optional; null when no adapter is connected) ---
  @override
  bool? get dtcPresent;
  @override
  double? get coolantTempC;
  @override
  double? get rpm; // --- Phone motion sensors (always available, already low-pass filtered) ---
  /// Longitudinal g: positive accelerating, negative braking.
  @override
  double get longitudinalG;

  /// Vertical g spike, used to detect bumps.
  @override
  double get verticalG;

  /// Lateral g, used to detect curves.
  @override
  double get lateralG;

  /// Turn rate about the vertical axis (rad/s) from the gyroscope. Drives the
  /// continuous lean into curves.
  @override
  double get yawRate; // --- Speed (GPS, fused with the accelerometer between fixes) ---
  @override
  double get speedKmh; // --- Navigation (optional) ---
  @override
  bool get arrived;
  @override
  TurnDirection get turnDirection;
  @override
  double? get turnDistanceM; // --- Stillness ---
  @override
  Duration get stillFor; // --- Ambient light ---
  @override
  double get lux;

  /// Create a copy of AppState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AppStateImplCopyWith<_$AppStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
