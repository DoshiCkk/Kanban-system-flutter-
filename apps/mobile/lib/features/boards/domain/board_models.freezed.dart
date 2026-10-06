// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'board_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Board {

 String get id; String get workspaceId; String get title; DateTime get updatedAt; String? get templateKey;
/// Create a copy of Board
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BoardCopyWith<Board> get copyWith => _$BoardCopyWithImpl<Board>(this as Board, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Board&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.title, title) || other.title == title)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.templateKey, templateKey) || other.templateKey == templateKey));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,title,updatedAt,templateKey);

@override
String toString() {
  return 'Board(id: $id, workspaceId: $workspaceId, title: $title, updatedAt: $updatedAt, templateKey: $templateKey)';
}


}

/// @nodoc
abstract mixin class $BoardCopyWith<$Res>  {
  factory $BoardCopyWith(Board value, $Res Function(Board) _then) = _$BoardCopyWithImpl;
@useResult
$Res call({
 String id, String workspaceId, String title, DateTime updatedAt, String? templateKey
});




}
/// @nodoc
class _$BoardCopyWithImpl<$Res>
    implements $BoardCopyWith<$Res> {
  _$BoardCopyWithImpl(this._self, this._then);

  final Board _self;
  final $Res Function(Board) _then;

/// Create a copy of Board
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? title = null,Object? updatedAt = null,Object? templateKey = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,templateKey: freezed == templateKey ? _self.templateKey : templateKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Board].
extension BoardPatterns on Board {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Board value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Board() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Board value)  $default,){
final _that = this;
switch (_that) {
case _Board():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Board value)?  $default,){
final _that = this;
switch (_that) {
case _Board() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String title,  DateTime updatedAt,  String? templateKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Board() when $default != null:
return $default(_that.id,_that.workspaceId,_that.title,_that.updatedAt,_that.templateKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String workspaceId,  String title,  DateTime updatedAt,  String? templateKey)  $default,) {final _that = this;
switch (_that) {
case _Board():
return $default(_that.id,_that.workspaceId,_that.title,_that.updatedAt,_that.templateKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String workspaceId,  String title,  DateTime updatedAt,  String? templateKey)?  $default,) {final _that = this;
switch (_that) {
case _Board() when $default != null:
return $default(_that.id,_that.workspaceId,_that.title,_that.updatedAt,_that.templateKey);case _:
  return null;

}
}

}

/// @nodoc


class _Board implements Board {
  const _Board({required this.id, required this.workspaceId, required this.title, required this.updatedAt, this.templateKey});
  

@override final  String id;
@override final  String workspaceId;
@override final  String title;
@override final  DateTime updatedAt;
@override final  String? templateKey;

/// Create a copy of Board
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BoardCopyWith<_Board> get copyWith => __$BoardCopyWithImpl<_Board>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Board&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.title, title) || other.title == title)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.templateKey, templateKey) || other.templateKey == templateKey));
}


@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,title,updatedAt,templateKey);

@override
String toString() {
  return 'Board(id: $id, workspaceId: $workspaceId, title: $title, updatedAt: $updatedAt, templateKey: $templateKey)';
}


}

/// @nodoc
abstract mixin class _$BoardCopyWith<$Res> implements $BoardCopyWith<$Res> {
  factory _$BoardCopyWith(_Board value, $Res Function(_Board) _then) = __$BoardCopyWithImpl;
@override @useResult
$Res call({
 String id, String workspaceId, String title, DateTime updatedAt, String? templateKey
});




}
/// @nodoc
class __$BoardCopyWithImpl<$Res>
    implements _$BoardCopyWith<$Res> {
  __$BoardCopyWithImpl(this._self, this._then);

  final _Board _self;
  final $Res Function(_Board) _then;

/// Create a copy of Board
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? title = null,Object? updatedAt = null,Object? templateKey = freezed,}) {
  return _then(_Board(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,templateKey: freezed == templateKey ? _self.templateKey : templateKey // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$BoardColumn {

 String get id; String get boardId; String get title; String get position; int? get wipLimit;
/// Create a copy of BoardColumn
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BoardColumnCopyWith<BoardColumn> get copyWith => _$BoardColumnCopyWithImpl<BoardColumn>(this as BoardColumn, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BoardColumn&&(identical(other.id, id) || other.id == id)&&(identical(other.boardId, boardId) || other.boardId == boardId)&&(identical(other.title, title) || other.title == title)&&(identical(other.position, position) || other.position == position)&&(identical(other.wipLimit, wipLimit) || other.wipLimit == wipLimit));
}


@override
int get hashCode => Object.hash(runtimeType,id,boardId,title,position,wipLimit);

@override
String toString() {
  return 'BoardColumn(id: $id, boardId: $boardId, title: $title, position: $position, wipLimit: $wipLimit)';
}


}

/// @nodoc
abstract mixin class $BoardColumnCopyWith<$Res>  {
  factory $BoardColumnCopyWith(BoardColumn value, $Res Function(BoardColumn) _then) = _$BoardColumnCopyWithImpl;
@useResult
$Res call({
 String id, String boardId, String title, String position, int? wipLimit
});




}
/// @nodoc
class _$BoardColumnCopyWithImpl<$Res>
    implements $BoardColumnCopyWith<$Res> {
  _$BoardColumnCopyWithImpl(this._self, this._then);

  final BoardColumn _self;
  final $Res Function(BoardColumn) _then;

/// Create a copy of BoardColumn
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? boardId = null,Object? title = null,Object? position = null,Object? wipLimit = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,boardId: null == boardId ? _self.boardId : boardId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String,wipLimit: freezed == wipLimit ? _self.wipLimit : wipLimit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [BoardColumn].
extension BoardColumnPatterns on BoardColumn {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BoardColumn value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BoardColumn() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BoardColumn value)  $default,){
final _that = this;
switch (_that) {
case _BoardColumn():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BoardColumn value)?  $default,){
final _that = this;
switch (_that) {
case _BoardColumn() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String boardId,  String title,  String position,  int? wipLimit)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BoardColumn() when $default != null:
return $default(_that.id,_that.boardId,_that.title,_that.position,_that.wipLimit);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String boardId,  String title,  String position,  int? wipLimit)  $default,) {final _that = this;
switch (_that) {
case _BoardColumn():
return $default(_that.id,_that.boardId,_that.title,_that.position,_that.wipLimit);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String boardId,  String title,  String position,  int? wipLimit)?  $default,) {final _that = this;
switch (_that) {
case _BoardColumn() when $default != null:
return $default(_that.id,_that.boardId,_that.title,_that.position,_that.wipLimit);case _:
  return null;

}
}

}

/// @nodoc


class _BoardColumn implements BoardColumn {
  const _BoardColumn({required this.id, required this.boardId, required this.title, required this.position, this.wipLimit});
  

@override final  String id;
@override final  String boardId;
@override final  String title;
@override final  String position;
@override final  int? wipLimit;

/// Create a copy of BoardColumn
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BoardColumnCopyWith<_BoardColumn> get copyWith => __$BoardColumnCopyWithImpl<_BoardColumn>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BoardColumn&&(identical(other.id, id) || other.id == id)&&(identical(other.boardId, boardId) || other.boardId == boardId)&&(identical(other.title, title) || other.title == title)&&(identical(other.position, position) || other.position == position)&&(identical(other.wipLimit, wipLimit) || other.wipLimit == wipLimit));
}


@override
int get hashCode => Object.hash(runtimeType,id,boardId,title,position,wipLimit);

@override
String toString() {
  return 'BoardColumn(id: $id, boardId: $boardId, title: $title, position: $position, wipLimit: $wipLimit)';
}


}

/// @nodoc
abstract mixin class _$BoardColumnCopyWith<$Res> implements $BoardColumnCopyWith<$Res> {
  factory _$BoardColumnCopyWith(_BoardColumn value, $Res Function(_BoardColumn) _then) = __$BoardColumnCopyWithImpl;
@override @useResult
$Res call({
 String id, String boardId, String title, String position, int? wipLimit
});




}
/// @nodoc
class __$BoardColumnCopyWithImpl<$Res>
    implements _$BoardColumnCopyWith<$Res> {
  __$BoardColumnCopyWithImpl(this._self, this._then);

  final _BoardColumn _self;
  final $Res Function(_BoardColumn) _then;

/// Create a copy of BoardColumn
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? boardId = null,Object? title = null,Object? position = null,Object? wipLimit = freezed,}) {
  return _then(_BoardColumn(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,boardId: null == boardId ? _self.boardId : boardId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String,wipLimit: freezed == wipLimit ? _self.wipLimit : wipLimit // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$CardSummary {

 String get id; String get columnId; String get title; CardPriority get priority; String get position; List<String> get labels; DateTime? get dueDate; String? get assigneeId; int get checklistDone; int get checklistTotal;
/// Create a copy of CardSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardSummaryCopyWith<CardSummary> get copyWith => _$CardSummaryCopyWithImpl<CardSummary>(this as CardSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.columnId, columnId) || other.columnId == columnId)&&(identical(other.title, title) || other.title == title)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.position, position) || other.position == position)&&const DeepCollectionEquality().equals(other.labels, labels)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.assigneeId, assigneeId) || other.assigneeId == assigneeId)&&(identical(other.checklistDone, checklistDone) || other.checklistDone == checklistDone)&&(identical(other.checklistTotal, checklistTotal) || other.checklistTotal == checklistTotal));
}


@override
int get hashCode => Object.hash(runtimeType,id,columnId,title,priority,position,const DeepCollectionEquality().hash(labels),dueDate,assigneeId,checklistDone,checklistTotal);

@override
String toString() {
  return 'CardSummary(id: $id, columnId: $columnId, title: $title, priority: $priority, position: $position, labels: $labels, dueDate: $dueDate, assigneeId: $assigneeId, checklistDone: $checklistDone, checklistTotal: $checklistTotal)';
}


}

/// @nodoc
abstract mixin class $CardSummaryCopyWith<$Res>  {
  factory $CardSummaryCopyWith(CardSummary value, $Res Function(CardSummary) _then) = _$CardSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String columnId, String title, CardPriority priority, String position, List<String> labels, DateTime? dueDate, String? assigneeId, int checklistDone, int checklistTotal
});




}
/// @nodoc
class _$CardSummaryCopyWithImpl<$Res>
    implements $CardSummaryCopyWith<$Res> {
  _$CardSummaryCopyWithImpl(this._self, this._then);

  final CardSummary _self;
  final $Res Function(CardSummary) _then;

/// Create a copy of CardSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? columnId = null,Object? title = null,Object? priority = null,Object? position = null,Object? labels = null,Object? dueDate = freezed,Object? assigneeId = freezed,Object? checklistDone = null,Object? checklistTotal = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,columnId: null == columnId ? _self.columnId : columnId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as CardPriority,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String,labels: null == labels ? _self.labels : labels // ignore: cast_nullable_to_non_nullable
as List<String>,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,assigneeId: freezed == assigneeId ? _self.assigneeId : assigneeId // ignore: cast_nullable_to_non_nullable
as String?,checklistDone: null == checklistDone ? _self.checklistDone : checklistDone // ignore: cast_nullable_to_non_nullable
as int,checklistTotal: null == checklistTotal ? _self.checklistTotal : checklistTotal // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CardSummary].
extension CardSummaryPatterns on CardSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CardSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CardSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CardSummary value)  $default,){
final _that = this;
switch (_that) {
case _CardSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CardSummary value)?  $default,){
final _that = this;
switch (_that) {
case _CardSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String columnId,  String title,  CardPriority priority,  String position,  List<String> labels,  DateTime? dueDate,  String? assigneeId,  int checklistDone,  int checklistTotal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CardSummary() when $default != null:
return $default(_that.id,_that.columnId,_that.title,_that.priority,_that.position,_that.labels,_that.dueDate,_that.assigneeId,_that.checklistDone,_that.checklistTotal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String columnId,  String title,  CardPriority priority,  String position,  List<String> labels,  DateTime? dueDate,  String? assigneeId,  int checklistDone,  int checklistTotal)  $default,) {final _that = this;
switch (_that) {
case _CardSummary():
return $default(_that.id,_that.columnId,_that.title,_that.priority,_that.position,_that.labels,_that.dueDate,_that.assigneeId,_that.checklistDone,_that.checklistTotal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String columnId,  String title,  CardPriority priority,  String position,  List<String> labels,  DateTime? dueDate,  String? assigneeId,  int checklistDone,  int checklistTotal)?  $default,) {final _that = this;
switch (_that) {
case _CardSummary() when $default != null:
return $default(_that.id,_that.columnId,_that.title,_that.priority,_that.position,_that.labels,_that.dueDate,_that.assigneeId,_that.checklistDone,_that.checklistTotal);case _:
  return null;

}
}

}

/// @nodoc


class _CardSummary implements CardSummary {
  const _CardSummary({required this.id, required this.columnId, required this.title, required this.priority, required this.position, final  List<String> labels = const <String>[], this.dueDate, this.assigneeId, this.checklistDone = 0, this.checklistTotal = 0}): _labels = labels;
  

@override final  String id;
@override final  String columnId;
@override final  String title;
@override final  CardPriority priority;
@override final  String position;
 final  List<String> _labels;
@override@JsonKey() List<String> get labels {
  if (_labels is EqualUnmodifiableListView) return _labels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_labels);
}

@override final  DateTime? dueDate;
@override final  String? assigneeId;
@override@JsonKey() final  int checklistDone;
@override@JsonKey() final  int checklistTotal;

/// Create a copy of CardSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CardSummaryCopyWith<_CardSummary> get copyWith => __$CardSummaryCopyWithImpl<_CardSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CardSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.columnId, columnId) || other.columnId == columnId)&&(identical(other.title, title) || other.title == title)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.position, position) || other.position == position)&&const DeepCollectionEquality().equals(other._labels, _labels)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.assigneeId, assigneeId) || other.assigneeId == assigneeId)&&(identical(other.checklistDone, checklistDone) || other.checklistDone == checklistDone)&&(identical(other.checklistTotal, checklistTotal) || other.checklistTotal == checklistTotal));
}


@override
int get hashCode => Object.hash(runtimeType,id,columnId,title,priority,position,const DeepCollectionEquality().hash(_labels),dueDate,assigneeId,checklistDone,checklistTotal);

@override
String toString() {
  return 'CardSummary(id: $id, columnId: $columnId, title: $title, priority: $priority, position: $position, labels: $labels, dueDate: $dueDate, assigneeId: $assigneeId, checklistDone: $checklistDone, checklistTotal: $checklistTotal)';
}


}

/// @nodoc
abstract mixin class _$CardSummaryCopyWith<$Res> implements $CardSummaryCopyWith<$Res> {
  factory _$CardSummaryCopyWith(_CardSummary value, $Res Function(_CardSummary) _then) = __$CardSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String columnId, String title, CardPriority priority, String position, List<String> labels, DateTime? dueDate, String? assigneeId, int checklistDone, int checklistTotal
});




}
/// @nodoc
class __$CardSummaryCopyWithImpl<$Res>
    implements _$CardSummaryCopyWith<$Res> {
  __$CardSummaryCopyWithImpl(this._self, this._then);

  final _CardSummary _self;
  final $Res Function(_CardSummary) _then;

/// Create a copy of CardSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? columnId = null,Object? title = null,Object? priority = null,Object? position = null,Object? labels = null,Object? dueDate = freezed,Object? assigneeId = freezed,Object? checklistDone = null,Object? checklistTotal = null,}) {
  return _then(_CardSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,columnId: null == columnId ? _self.columnId : columnId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as CardPriority,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String,labels: null == labels ? _self._labels : labels // ignore: cast_nullable_to_non_nullable
as List<String>,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,assigneeId: freezed == assigneeId ? _self.assigneeId : assigneeId // ignore: cast_nullable_to_non_nullable
as String?,checklistDone: null == checklistDone ? _self.checklistDone : checklistDone // ignore: cast_nullable_to_non_nullable
as int,checklistTotal: null == checklistTotal ? _self.checklistTotal : checklistTotal // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$ColumnWithCards {

 BoardColumn get column; List<CardSummary> get cards;
/// Create a copy of ColumnWithCards
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ColumnWithCardsCopyWith<ColumnWithCards> get copyWith => _$ColumnWithCardsCopyWithImpl<ColumnWithCards>(this as ColumnWithCards, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ColumnWithCards&&(identical(other.column, column) || other.column == column)&&const DeepCollectionEquality().equals(other.cards, cards));
}


@override
int get hashCode => Object.hash(runtimeType,column,const DeepCollectionEquality().hash(cards));

@override
String toString() {
  return 'ColumnWithCards(column: $column, cards: $cards)';
}


}

/// @nodoc
abstract mixin class $ColumnWithCardsCopyWith<$Res>  {
  factory $ColumnWithCardsCopyWith(ColumnWithCards value, $Res Function(ColumnWithCards) _then) = _$ColumnWithCardsCopyWithImpl;
@useResult
$Res call({
 BoardColumn column, List<CardSummary> cards
});


$BoardColumnCopyWith<$Res> get column;

}
/// @nodoc
class _$ColumnWithCardsCopyWithImpl<$Res>
    implements $ColumnWithCardsCopyWith<$Res> {
  _$ColumnWithCardsCopyWithImpl(this._self, this._then);

  final ColumnWithCards _self;
  final $Res Function(ColumnWithCards) _then;

/// Create a copy of ColumnWithCards
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? column = null,Object? cards = null,}) {
  return _then(_self.copyWith(
column: null == column ? _self.column : column // ignore: cast_nullable_to_non_nullable
as BoardColumn,cards: null == cards ? _self.cards : cards // ignore: cast_nullable_to_non_nullable
as List<CardSummary>,
  ));
}
/// Create a copy of ColumnWithCards
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BoardColumnCopyWith<$Res> get column {
  
  return $BoardColumnCopyWith<$Res>(_self.column, (value) {
    return _then(_self.copyWith(column: value));
  });
}
}


/// Adds pattern-matching-related methods to [ColumnWithCards].
extension ColumnWithCardsPatterns on ColumnWithCards {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ColumnWithCards value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ColumnWithCards() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ColumnWithCards value)  $default,){
final _that = this;
switch (_that) {
case _ColumnWithCards():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ColumnWithCards value)?  $default,){
final _that = this;
switch (_that) {
case _ColumnWithCards() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BoardColumn column,  List<CardSummary> cards)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ColumnWithCards() when $default != null:
return $default(_that.column,_that.cards);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BoardColumn column,  List<CardSummary> cards)  $default,) {final _that = this;
switch (_that) {
case _ColumnWithCards():
return $default(_that.column,_that.cards);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BoardColumn column,  List<CardSummary> cards)?  $default,) {final _that = this;
switch (_that) {
case _ColumnWithCards() when $default != null:
return $default(_that.column,_that.cards);case _:
  return null;

}
}

}

/// @nodoc


class _ColumnWithCards implements ColumnWithCards {
  const _ColumnWithCards({required this.column, required final  List<CardSummary> cards}): _cards = cards;
  

@override final  BoardColumn column;
 final  List<CardSummary> _cards;
@override List<CardSummary> get cards {
  if (_cards is EqualUnmodifiableListView) return _cards;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cards);
}


/// Create a copy of ColumnWithCards
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ColumnWithCardsCopyWith<_ColumnWithCards> get copyWith => __$ColumnWithCardsCopyWithImpl<_ColumnWithCards>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ColumnWithCards&&(identical(other.column, column) || other.column == column)&&const DeepCollectionEquality().equals(other._cards, _cards));
}


@override
int get hashCode => Object.hash(runtimeType,column,const DeepCollectionEquality().hash(_cards));

@override
String toString() {
  return 'ColumnWithCards(column: $column, cards: $cards)';
}


}

/// @nodoc
abstract mixin class _$ColumnWithCardsCopyWith<$Res> implements $ColumnWithCardsCopyWith<$Res> {
  factory _$ColumnWithCardsCopyWith(_ColumnWithCards value, $Res Function(_ColumnWithCards) _then) = __$ColumnWithCardsCopyWithImpl;
@override @useResult
$Res call({
 BoardColumn column, List<CardSummary> cards
});


@override $BoardColumnCopyWith<$Res> get column;

}
/// @nodoc
class __$ColumnWithCardsCopyWithImpl<$Res>
    implements _$ColumnWithCardsCopyWith<$Res> {
  __$ColumnWithCardsCopyWithImpl(this._self, this._then);

  final _ColumnWithCards _self;
  final $Res Function(_ColumnWithCards) _then;

/// Create a copy of ColumnWithCards
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? column = null,Object? cards = null,}) {
  return _then(_ColumnWithCards(
column: null == column ? _self.column : column // ignore: cast_nullable_to_non_nullable
as BoardColumn,cards: null == cards ? _self._cards : cards // ignore: cast_nullable_to_non_nullable
as List<CardSummary>,
  ));
}

/// Create a copy of ColumnWithCards
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BoardColumnCopyWith<$Res> get column {
  
  return $BoardColumnCopyWith<$Res>(_self.column, (value) {
    return _then(_self.copyWith(column: value));
  });
}
}

/// @nodoc
mixin _$BoardContent {

 Board get board; List<ColumnWithCards> get columns;
/// Create a copy of BoardContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BoardContentCopyWith<BoardContent> get copyWith => _$BoardContentCopyWithImpl<BoardContent>(this as BoardContent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BoardContent&&(identical(other.board, board) || other.board == board)&&const DeepCollectionEquality().equals(other.columns, columns));
}


@override
int get hashCode => Object.hash(runtimeType,board,const DeepCollectionEquality().hash(columns));

@override
String toString() {
  return 'BoardContent(board: $board, columns: $columns)';
}


}

/// @nodoc
abstract mixin class $BoardContentCopyWith<$Res>  {
  factory $BoardContentCopyWith(BoardContent value, $Res Function(BoardContent) _then) = _$BoardContentCopyWithImpl;
@useResult
$Res call({
 Board board, List<ColumnWithCards> columns
});


$BoardCopyWith<$Res> get board;

}
/// @nodoc
class _$BoardContentCopyWithImpl<$Res>
    implements $BoardContentCopyWith<$Res> {
  _$BoardContentCopyWithImpl(this._self, this._then);

  final BoardContent _self;
  final $Res Function(BoardContent) _then;

/// Create a copy of BoardContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? board = null,Object? columns = null,}) {
  return _then(_self.copyWith(
board: null == board ? _self.board : board // ignore: cast_nullable_to_non_nullable
as Board,columns: null == columns ? _self.columns : columns // ignore: cast_nullable_to_non_nullable
as List<ColumnWithCards>,
  ));
}
/// Create a copy of BoardContent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BoardCopyWith<$Res> get board {
  
  return $BoardCopyWith<$Res>(_self.board, (value) {
    return _then(_self.copyWith(board: value));
  });
}
}


/// Adds pattern-matching-related methods to [BoardContent].
extension BoardContentPatterns on BoardContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BoardContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BoardContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BoardContent value)  $default,){
final _that = this;
switch (_that) {
case _BoardContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BoardContent value)?  $default,){
final _that = this;
switch (_that) {
case _BoardContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Board board,  List<ColumnWithCards> columns)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BoardContent() when $default != null:
return $default(_that.board,_that.columns);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Board board,  List<ColumnWithCards> columns)  $default,) {final _that = this;
switch (_that) {
case _BoardContent():
return $default(_that.board,_that.columns);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Board board,  List<ColumnWithCards> columns)?  $default,) {final _that = this;
switch (_that) {
case _BoardContent() when $default != null:
return $default(_that.board,_that.columns);case _:
  return null;

}
}

}

/// @nodoc


class _BoardContent implements BoardContent {
  const _BoardContent({required this.board, required final  List<ColumnWithCards> columns}): _columns = columns;
  

@override final  Board board;
 final  List<ColumnWithCards> _columns;
@override List<ColumnWithCards> get columns {
  if (_columns is EqualUnmodifiableListView) return _columns;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_columns);
}


/// Create a copy of BoardContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BoardContentCopyWith<_BoardContent> get copyWith => __$BoardContentCopyWithImpl<_BoardContent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BoardContent&&(identical(other.board, board) || other.board == board)&&const DeepCollectionEquality().equals(other._columns, _columns));
}


@override
int get hashCode => Object.hash(runtimeType,board,const DeepCollectionEquality().hash(_columns));

@override
String toString() {
  return 'BoardContent(board: $board, columns: $columns)';
}


}

/// @nodoc
abstract mixin class _$BoardContentCopyWith<$Res> implements $BoardContentCopyWith<$Res> {
  factory _$BoardContentCopyWith(_BoardContent value, $Res Function(_BoardContent) _then) = __$BoardContentCopyWithImpl;
@override @useResult
$Res call({
 Board board, List<ColumnWithCards> columns
});


@override $BoardCopyWith<$Res> get board;

}
/// @nodoc
class __$BoardContentCopyWithImpl<$Res>
    implements _$BoardContentCopyWith<$Res> {
  __$BoardContentCopyWithImpl(this._self, this._then);

  final _BoardContent _self;
  final $Res Function(_BoardContent) _then;

/// Create a copy of BoardContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? board = null,Object? columns = null,}) {
  return _then(_BoardContent(
board: null == board ? _self.board : board // ignore: cast_nullable_to_non_nullable
as Board,columns: null == columns ? _self._columns : columns // ignore: cast_nullable_to_non_nullable
as List<ColumnWithCards>,
  ));
}

/// Create a copy of BoardContent
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BoardCopyWith<$Res> get board {
  
  return $BoardCopyWith<$Res>(_self.board, (value) {
    return _then(_self.copyWith(board: value));
  });
}
}

/// @nodoc
mixin _$ChecklistItem {

 String get id; String get text; bool get done; String get position;
/// Create a copy of ChecklistItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChecklistItemCopyWith<ChecklistItem> get copyWith => _$ChecklistItemCopyWithImpl<ChecklistItem>(this as ChecklistItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChecklistItem&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.done, done) || other.done == done)&&(identical(other.position, position) || other.position == position));
}


@override
int get hashCode => Object.hash(runtimeType,id,text,done,position);

@override
String toString() {
  return 'ChecklistItem(id: $id, text: $text, done: $done, position: $position)';
}


}

/// @nodoc
abstract mixin class $ChecklistItemCopyWith<$Res>  {
  factory $ChecklistItemCopyWith(ChecklistItem value, $Res Function(ChecklistItem) _then) = _$ChecklistItemCopyWithImpl;
@useResult
$Res call({
 String id, String text, bool done, String position
});




}
/// @nodoc
class _$ChecklistItemCopyWithImpl<$Res>
    implements $ChecklistItemCopyWith<$Res> {
  _$ChecklistItemCopyWithImpl(this._self, this._then);

  final ChecklistItem _self;
  final $Res Function(ChecklistItem) _then;

/// Create a copy of ChecklistItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? text = null,Object? done = null,Object? position = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ChecklistItem].
extension ChecklistItemPatterns on ChecklistItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChecklistItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChecklistItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChecklistItem value)  $default,){
final _that = this;
switch (_that) {
case _ChecklistItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChecklistItem value)?  $default,){
final _that = this;
switch (_that) {
case _ChecklistItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String text,  bool done,  String position)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChecklistItem() when $default != null:
return $default(_that.id,_that.text,_that.done,_that.position);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String text,  bool done,  String position)  $default,) {final _that = this;
switch (_that) {
case _ChecklistItem():
return $default(_that.id,_that.text,_that.done,_that.position);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String text,  bool done,  String position)?  $default,) {final _that = this;
switch (_that) {
case _ChecklistItem() when $default != null:
return $default(_that.id,_that.text,_that.done,_that.position);case _:
  return null;

}
}

}

/// @nodoc


class _ChecklistItem implements ChecklistItem {
  const _ChecklistItem({required this.id, required this.text, required this.done, required this.position});
  

@override final  String id;
@override final  String text;
@override final  bool done;
@override final  String position;

/// Create a copy of ChecklistItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChecklistItemCopyWith<_ChecklistItem> get copyWith => __$ChecklistItemCopyWithImpl<_ChecklistItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChecklistItem&&(identical(other.id, id) || other.id == id)&&(identical(other.text, text) || other.text == text)&&(identical(other.done, done) || other.done == done)&&(identical(other.position, position) || other.position == position));
}


@override
int get hashCode => Object.hash(runtimeType,id,text,done,position);

@override
String toString() {
  return 'ChecklistItem(id: $id, text: $text, done: $done, position: $position)';
}


}

/// @nodoc
abstract mixin class _$ChecklistItemCopyWith<$Res> implements $ChecklistItemCopyWith<$Res> {
  factory _$ChecklistItemCopyWith(_ChecklistItem value, $Res Function(_ChecklistItem) _then) = __$ChecklistItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String text, bool done, String position
});




}
/// @nodoc
class __$ChecklistItemCopyWithImpl<$Res>
    implements _$ChecklistItemCopyWith<$Res> {
  __$ChecklistItemCopyWithImpl(this._self, this._then);

  final _ChecklistItem _self;
  final $Res Function(_ChecklistItem) _then;

/// Create a copy of ChecklistItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? text = null,Object? done = null,Object? position = null,}) {
  return _then(_ChecklistItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$CardDetails {

 String get id; String get boardId; String get workspaceId; String get columnId; String get title; String get description; CardPriority get priority; List<String> get labels; List<ChecklistItem> get checklist;/// All live columns of the board in order (for status and "next").
 List<BoardColumn> get columns; DateTime? get dueDate; String? get assigneeId;
/// Create a copy of CardDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardDetailsCopyWith<CardDetails> get copyWith => _$CardDetailsCopyWithImpl<CardDetails>(this as CardDetails, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CardDetails&&(identical(other.id, id) || other.id == id)&&(identical(other.boardId, boardId) || other.boardId == boardId)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.columnId, columnId) || other.columnId == columnId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other.labels, labels)&&const DeepCollectionEquality().equals(other.checklist, checklist)&&const DeepCollectionEquality().equals(other.columns, columns)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.assigneeId, assigneeId) || other.assigneeId == assigneeId));
}


@override
int get hashCode => Object.hash(runtimeType,id,boardId,workspaceId,columnId,title,description,priority,const DeepCollectionEquality().hash(labels),const DeepCollectionEquality().hash(checklist),const DeepCollectionEquality().hash(columns),dueDate,assigneeId);

@override
String toString() {
  return 'CardDetails(id: $id, boardId: $boardId, workspaceId: $workspaceId, columnId: $columnId, title: $title, description: $description, priority: $priority, labels: $labels, checklist: $checklist, columns: $columns, dueDate: $dueDate, assigneeId: $assigneeId)';
}


}

/// @nodoc
abstract mixin class $CardDetailsCopyWith<$Res>  {
  factory $CardDetailsCopyWith(CardDetails value, $Res Function(CardDetails) _then) = _$CardDetailsCopyWithImpl;
@useResult
$Res call({
 String id, String boardId, String workspaceId, String columnId, String title, String description, CardPriority priority, List<String> labels, List<ChecklistItem> checklist, List<BoardColumn> columns, DateTime? dueDate, String? assigneeId
});




}
/// @nodoc
class _$CardDetailsCopyWithImpl<$Res>
    implements $CardDetailsCopyWith<$Res> {
  _$CardDetailsCopyWithImpl(this._self, this._then);

  final CardDetails _self;
  final $Res Function(CardDetails) _then;

/// Create a copy of CardDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? boardId = null,Object? workspaceId = null,Object? columnId = null,Object? title = null,Object? description = null,Object? priority = null,Object? labels = null,Object? checklist = null,Object? columns = null,Object? dueDate = freezed,Object? assigneeId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,boardId: null == boardId ? _self.boardId : boardId // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,columnId: null == columnId ? _self.columnId : columnId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as CardPriority,labels: null == labels ? _self.labels : labels // ignore: cast_nullable_to_non_nullable
as List<String>,checklist: null == checklist ? _self.checklist : checklist // ignore: cast_nullable_to_non_nullable
as List<ChecklistItem>,columns: null == columns ? _self.columns : columns // ignore: cast_nullable_to_non_nullable
as List<BoardColumn>,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,assigneeId: freezed == assigneeId ? _self.assigneeId : assigneeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CardDetails].
extension CardDetailsPatterns on CardDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CardDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CardDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CardDetails value)  $default,){
final _that = this;
switch (_that) {
case _CardDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CardDetails value)?  $default,){
final _that = this;
switch (_that) {
case _CardDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String boardId,  String workspaceId,  String columnId,  String title,  String description,  CardPriority priority,  List<String> labels,  List<ChecklistItem> checklist,  List<BoardColumn> columns,  DateTime? dueDate,  String? assigneeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CardDetails() when $default != null:
return $default(_that.id,_that.boardId,_that.workspaceId,_that.columnId,_that.title,_that.description,_that.priority,_that.labels,_that.checklist,_that.columns,_that.dueDate,_that.assigneeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String boardId,  String workspaceId,  String columnId,  String title,  String description,  CardPriority priority,  List<String> labels,  List<ChecklistItem> checklist,  List<BoardColumn> columns,  DateTime? dueDate,  String? assigneeId)  $default,) {final _that = this;
switch (_that) {
case _CardDetails():
return $default(_that.id,_that.boardId,_that.workspaceId,_that.columnId,_that.title,_that.description,_that.priority,_that.labels,_that.checklist,_that.columns,_that.dueDate,_that.assigneeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String boardId,  String workspaceId,  String columnId,  String title,  String description,  CardPriority priority,  List<String> labels,  List<ChecklistItem> checklist,  List<BoardColumn> columns,  DateTime? dueDate,  String? assigneeId)?  $default,) {final _that = this;
switch (_that) {
case _CardDetails() when $default != null:
return $default(_that.id,_that.boardId,_that.workspaceId,_that.columnId,_that.title,_that.description,_that.priority,_that.labels,_that.checklist,_that.columns,_that.dueDate,_that.assigneeId);case _:
  return null;

}
}

}

/// @nodoc


class _CardDetails extends CardDetails {
  const _CardDetails({required this.id, required this.boardId, required this.workspaceId, required this.columnId, required this.title, required this.description, required this.priority, required final  List<String> labels, required final  List<ChecklistItem> checklist, required final  List<BoardColumn> columns, this.dueDate, this.assigneeId}): _labels = labels,_checklist = checklist,_columns = columns,super._();
  

@override final  String id;
@override final  String boardId;
@override final  String workspaceId;
@override final  String columnId;
@override final  String title;
@override final  String description;
@override final  CardPriority priority;
 final  List<String> _labels;
@override List<String> get labels {
  if (_labels is EqualUnmodifiableListView) return _labels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_labels);
}

 final  List<ChecklistItem> _checklist;
@override List<ChecklistItem> get checklist {
  if (_checklist is EqualUnmodifiableListView) return _checklist;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_checklist);
}

/// All live columns of the board in order (for status and "next").
 final  List<BoardColumn> _columns;
/// All live columns of the board in order (for status and "next").
@override List<BoardColumn> get columns {
  if (_columns is EqualUnmodifiableListView) return _columns;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_columns);
}

@override final  DateTime? dueDate;
@override final  String? assigneeId;

/// Create a copy of CardDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CardDetailsCopyWith<_CardDetails> get copyWith => __$CardDetailsCopyWithImpl<_CardDetails>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CardDetails&&(identical(other.id, id) || other.id == id)&&(identical(other.boardId, boardId) || other.boardId == boardId)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.columnId, columnId) || other.columnId == columnId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other._labels, _labels)&&const DeepCollectionEquality().equals(other._checklist, _checklist)&&const DeepCollectionEquality().equals(other._columns, _columns)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.assigneeId, assigneeId) || other.assigneeId == assigneeId));
}


@override
int get hashCode => Object.hash(runtimeType,id,boardId,workspaceId,columnId,title,description,priority,const DeepCollectionEquality().hash(_labels),const DeepCollectionEquality().hash(_checklist),const DeepCollectionEquality().hash(_columns),dueDate,assigneeId);

@override
String toString() {
  return 'CardDetails(id: $id, boardId: $boardId, workspaceId: $workspaceId, columnId: $columnId, title: $title, description: $description, priority: $priority, labels: $labels, checklist: $checklist, columns: $columns, dueDate: $dueDate, assigneeId: $assigneeId)';
}


}

/// @nodoc
abstract mixin class _$CardDetailsCopyWith<$Res> implements $CardDetailsCopyWith<$Res> {
  factory _$CardDetailsCopyWith(_CardDetails value, $Res Function(_CardDetails) _then) = __$CardDetailsCopyWithImpl;
@override @useResult
$Res call({
 String id, String boardId, String workspaceId, String columnId, String title, String description, CardPriority priority, List<String> labels, List<ChecklistItem> checklist, List<BoardColumn> columns, DateTime? dueDate, String? assigneeId
});




}
/// @nodoc
class __$CardDetailsCopyWithImpl<$Res>
    implements _$CardDetailsCopyWith<$Res> {
  __$CardDetailsCopyWithImpl(this._self, this._then);

  final _CardDetails _self;
  final $Res Function(_CardDetails) _then;

/// Create a copy of CardDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? boardId = null,Object? workspaceId = null,Object? columnId = null,Object? title = null,Object? description = null,Object? priority = null,Object? labels = null,Object? checklist = null,Object? columns = null,Object? dueDate = freezed,Object? assigneeId = freezed,}) {
  return _then(_CardDetails(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,boardId: null == boardId ? _self.boardId : boardId // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,columnId: null == columnId ? _self.columnId : columnId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as CardPriority,labels: null == labels ? _self._labels : labels // ignore: cast_nullable_to_non_nullable
as List<String>,checklist: null == checklist ? _self._checklist : checklist // ignore: cast_nullable_to_non_nullable
as List<ChecklistItem>,columns: null == columns ? _self._columns : columns // ignore: cast_nullable_to_non_nullable
as List<BoardColumn>,dueDate: freezed == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as DateTime?,assigneeId: freezed == assigneeId ? _self.assigneeId : assigneeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
