// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'controller.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Controller {

 String get id;/// What is written on the pad — "HEX-1". This is what staff are told to
/// carry, so it must be the physical marking, not an id.
 String get label;/// The station it belongs to and returns to.
 String get homeResourceId;/// Where it physically is now. Equals [homeResourceId] unless it has been
/// moved.
 String get currentResourceId; ControllerStatus get status;/// Why it is in this state — "left stick drift".
 String? get notes;/// Set while on loan: the station to return it to.
 String? get loanReturnTo;/// Which session owes the return, as `s:<sessionId>`.
 String? get loanSessionRef; DateTime get updatedAt;
/// Create a copy of Controller
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ControllerCopyWith<Controller> get copyWith => _$ControllerCopyWithImpl<Controller>(this as Controller, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Controller;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Controller&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.homeResourceId, _this.homeResourceId) || other.homeResourceId == _this.homeResourceId)&&(identical(other.currentResourceId, _this.currentResourceId) || other.currentResourceId == _this.currentResourceId)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.notes, _this.notes) || other.notes == _this.notes)&&(identical(other.loanReturnTo, _this.loanReturnTo) || other.loanReturnTo == _this.loanReturnTo)&&(identical(other.loanSessionRef, _this.loanSessionRef) || other.loanSessionRef == _this.loanSessionRef)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as Controller;
  return Object.hash(runtimeType,_this.id,_this.label,_this.homeResourceId,_this.currentResourceId,_this.status,_this.notes,_this.loanReturnTo,_this.loanSessionRef,_this.updatedAt);
}

@override
String toString() {
  final _this = this as Controller;
  return 'Controller(id: ${_this.id}, label: ${_this.label}, homeResourceId: ${_this.homeResourceId}, currentResourceId: ${_this.currentResourceId}, status: ${_this.status}, notes: ${_this.notes}, loanReturnTo: ${_this.loanReturnTo}, loanSessionRef: ${_this.loanSessionRef}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $ControllerCopyWith<$Res>  {
  factory $ControllerCopyWith(Controller value, $Res Function(Controller) _then) = _$ControllerCopyWithImpl;
@useResult
$Res call({
 String id, String label, String homeResourceId, String currentResourceId, ControllerStatus status, String? notes, String? loanReturnTo, String? loanSessionRef, DateTime updatedAt
});




}
/// @nodoc
class _$ControllerCopyWithImpl<$Res>
    implements $ControllerCopyWith<$Res> {
  _$ControllerCopyWithImpl(this._self, this._then);

  final Controller _self;
  final $Res Function(Controller) _then;

/// Create a copy of Controller
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? homeResourceId = null,Object? currentResourceId = null,Object? status = null,Object? notes = freezed,Object? loanReturnTo = freezed,Object? loanSessionRef = freezed,Object? updatedAt = null,}) {
  return _then(Controller(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,homeResourceId: null == homeResourceId ? _self.homeResourceId : homeResourceId // ignore: cast_nullable_to_non_nullable
as String,currentResourceId: null == currentResourceId ? _self.currentResourceId : currentResourceId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ControllerStatus,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,loanReturnTo: freezed == loanReturnTo ? _self.loanReturnTo : loanReturnTo // ignore: cast_nullable_to_non_nullable
as String?,loanSessionRef: freezed == loanSessionRef ? _self.loanSessionRef : loanSessionRef // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Controller].
extension ControllerPatterns on Controller {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Controller value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Controller() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Controller value)  $default,){
final _that = this;
switch (_that) {
case _Controller():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Controller value)?  $default,){
final _that = this;
switch (_that) {
case _Controller() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  String homeResourceId,  String currentResourceId,  ControllerStatus status,  String? notes,  String? loanReturnTo,  String? loanSessionRef,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Controller() when $default != null:
return $default(_that.id,_that.label,_that.homeResourceId,_that.currentResourceId,_that.status,_that.notes,_that.loanReturnTo,_that.loanSessionRef,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  String homeResourceId,  String currentResourceId,  ControllerStatus status,  String? notes,  String? loanReturnTo,  String? loanSessionRef,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Controller():
return $default(_that.id,_that.label,_that.homeResourceId,_that.currentResourceId,_that.status,_that.notes,_that.loanReturnTo,_that.loanSessionRef,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  String homeResourceId,  String currentResourceId,  ControllerStatus status,  String? notes,  String? loanReturnTo,  String? loanSessionRef,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Controller() when $default != null:
return $default(_that.id,_that.label,_that.homeResourceId,_that.currentResourceId,_that.status,_that.notes,_that.loanReturnTo,_that.loanSessionRef,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _Controller extends Controller {
  const _Controller({required this.id, required this.label, required this.homeResourceId, required this.currentResourceId, this.status = ControllerStatus.usable, this.notes, this.loanReturnTo, this.loanSessionRef, required this.updatedAt}): super._();
  

@override final  String id;
/// What is written on the pad — "HEX-1". This is what staff are told to
/// carry, so it must be the physical marking, not an id.
@override final  String label;
/// The station it belongs to and returns to.
@override final  String homeResourceId;
/// Where it physically is now. Equals [homeResourceId] unless it has been
/// moved.
@override final  String currentResourceId;
@override@JsonKey() final  ControllerStatus status;
/// Why it is in this state — "left stick drift".
@override final  String? notes;
/// Set while on loan: the station to return it to.
@override final  String? loanReturnTo;
/// Which session owes the return, as `s:<sessionId>`.
@override final  String? loanSessionRef;
@override final  DateTime updatedAt;

/// Create a copy of Controller
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ControllerCopyWith<_Controller> get copyWith => __$ControllerCopyWithImpl<_Controller>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Controller&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.homeResourceId, homeResourceId) || other.homeResourceId == homeResourceId)&&(identical(other.currentResourceId, currentResourceId) || other.currentResourceId == currentResourceId)&&(identical(other.status, status) || other.status == status)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.loanReturnTo, loanReturnTo) || other.loanReturnTo == loanReturnTo)&&(identical(other.loanSessionRef, loanSessionRef) || other.loanSessionRef == loanSessionRef)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,label,homeResourceId,currentResourceId,status,notes,loanReturnTo,loanSessionRef,updatedAt);
}

@override
String toString() {
    return 'Controller(id: $id, label: $label, homeResourceId: $homeResourceId, currentResourceId: $currentResourceId, status: $status, notes: $notes, loanReturnTo: $loanReturnTo, loanSessionRef: $loanSessionRef, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ControllerCopyWith<$Res> implements $ControllerCopyWith<$Res> {
  factory _$ControllerCopyWith(_Controller value, $Res Function(_Controller) _then) = __$ControllerCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, String homeResourceId, String currentResourceId, ControllerStatus status, String? notes, String? loanReturnTo, String? loanSessionRef, DateTime updatedAt
});




}
/// @nodoc
class __$ControllerCopyWithImpl<$Res>
    implements _$ControllerCopyWith<$Res> {
  __$ControllerCopyWithImpl(this._self, this._then);

  final _Controller _self;
  final $Res Function(_Controller) _then;

/// Create a copy of Controller
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? homeResourceId = null,Object? currentResourceId = null,Object? status = null,Object? notes = freezed,Object? loanReturnTo = freezed,Object? loanSessionRef = freezed,Object? updatedAt = null,}) {
  return _then(_Controller(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,homeResourceId: null == homeResourceId ? _self.homeResourceId : homeResourceId // ignore: cast_nullable_to_non_nullable
as String,currentResourceId: null == currentResourceId ? _self.currentResourceId : currentResourceId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ControllerStatus,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,loanReturnTo: freezed == loanReturnTo ? _self.loanReturnTo : loanReturnTo // ignore: cast_nullable_to_non_nullable
as String?,loanSessionRef: freezed == loanSessionRef ? _self.loanSessionRef : loanSessionRef // ignore: cast_nullable_to_non_nullable
as String?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
