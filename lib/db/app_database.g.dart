// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $EventsCacheTable extends EventsCache
    with TableInfo<$EventsCacheTable, EventsCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, userId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventsCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventsCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventsCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EventsCacheTable createAlias(String alias) {
    return $EventsCacheTable(attachedDatabase, alias);
  }
}

class EventsCacheData extends DataClass implements Insertable<EventsCacheData> {
  final String id;
  final String userId;
  final String data;
  final int updatedAt;
  const EventsCacheData({
    required this.id,
    required this.userId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  EventsCacheCompanion toCompanion(bool nullToAbsent) {
    return EventsCacheCompanion(
      id: Value(id),
      userId: Value(userId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory EventsCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventsCacheData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  EventsCacheData copyWith({
    String? id,
    String? userId,
    String? data,
    int? updatedAt,
  }) => EventsCacheData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EventsCacheData copyWithCompanion(EventsCacheCompanion data) {
    return EventsCacheData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventsCacheData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventsCacheData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class EventsCacheCompanion extends UpdateCompanion<EventsCacheData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> data;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const EventsCacheCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCacheCompanion.insert({
    required String id,
    required String userId,
    required String data,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<EventsCacheData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? data,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? data,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return EventsCacheCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCacheCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodosCacheTable extends TodosCache
    with TableInfo<$TodosCacheTable, TodosCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodosCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, userId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todos_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodosCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TodosCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodosCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TodosCacheTable createAlias(String alias) {
    return $TodosCacheTable(attachedDatabase, alias);
  }
}

class TodosCacheData extends DataClass implements Insertable<TodosCacheData> {
  final String id;
  final String userId;
  final String data;
  final int updatedAt;
  const TodosCacheData({
    required this.id,
    required this.userId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TodosCacheCompanion toCompanion(bool nullToAbsent) {
    return TodosCacheCompanion(
      id: Value(id),
      userId: Value(userId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory TodosCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodosCacheData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TodosCacheData copyWith({
    String? id,
    String? userId,
    String? data,
    int? updatedAt,
  }) => TodosCacheData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TodosCacheData copyWithCompanion(TodosCacheCompanion data) {
    return TodosCacheData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodosCacheData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodosCacheData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class TodosCacheCompanion extends UpdateCompanion<TodosCacheData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> data;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TodosCacheCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodosCacheCompanion.insert({
    required String id,
    required String userId,
    required String data,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<TodosCacheData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? data,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodosCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? data,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TodosCacheCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodosCacheCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnualEventsCacheTable extends AnnualEventsCache
    with TableInfo<$AnnualEventsCacheTable, AnnualEventsCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnualEventsCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, userId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annual_events_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnnualEventsCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnnualEventsCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnnualEventsCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AnnualEventsCacheTable createAlias(String alias) {
    return $AnnualEventsCacheTable(attachedDatabase, alias);
  }
}

class AnnualEventsCacheData extends DataClass
    implements Insertable<AnnualEventsCacheData> {
  final String id;
  final String userId;
  final String data;
  final int updatedAt;
  const AnnualEventsCacheData({
    required this.id,
    required this.userId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AnnualEventsCacheCompanion toCompanion(bool nullToAbsent) {
    return AnnualEventsCacheCompanion(
      id: Value(id),
      userId: Value(userId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory AnnualEventsCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnnualEventsCacheData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AnnualEventsCacheData copyWith({
    String? id,
    String? userId,
    String? data,
    int? updatedAt,
  }) => AnnualEventsCacheData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AnnualEventsCacheData copyWithCompanion(AnnualEventsCacheCompanion data) {
    return AnnualEventsCacheData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnnualEventsCacheData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnnualEventsCacheData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class AnnualEventsCacheCompanion
    extends UpdateCompanion<AnnualEventsCacheData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> data;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AnnualEventsCacheCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnualEventsCacheCompanion.insert({
    required String id,
    required String userId,
    required String data,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<AnnualEventsCacheData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? data,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnualEventsCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? data,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AnnualEventsCacheCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnualEventsCacheCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeriesRemindersCacheTable extends SeriesRemindersCache
    with TableInfo<$SeriesRemindersCacheTable, SeriesRemindersCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesRemindersCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, userId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series_reminders_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeriesRemindersCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SeriesRemindersCacheData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeriesRemindersCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SeriesRemindersCacheTable createAlias(String alias) {
    return $SeriesRemindersCacheTable(attachedDatabase, alias);
  }
}

class SeriesRemindersCacheData extends DataClass
    implements Insertable<SeriesRemindersCacheData> {
  final String id;
  final String userId;
  final String data;
  final int updatedAt;
  const SeriesRemindersCacheData({
    required this.id,
    required this.userId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SeriesRemindersCacheCompanion toCompanion(bool nullToAbsent) {
    return SeriesRemindersCacheCompanion(
      id: Value(id),
      userId: Value(userId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory SeriesRemindersCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeriesRemindersCacheData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SeriesRemindersCacheData copyWith({
    String? id,
    String? userId,
    String? data,
    int? updatedAt,
  }) => SeriesRemindersCacheData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SeriesRemindersCacheData copyWithCompanion(
    SeriesRemindersCacheCompanion data,
  ) {
    return SeriesRemindersCacheData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeriesRemindersCacheData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeriesRemindersCacheData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class SeriesRemindersCacheCompanion
    extends UpdateCompanion<SeriesRemindersCacheData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> data;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SeriesRemindersCacheCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SeriesRemindersCacheCompanion.insert({
    required String id,
    required String userId,
    required String data,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<SeriesRemindersCacheData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? data,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SeriesRemindersCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? data,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SeriesRemindersCacheCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesRemindersCacheCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $YearlyChecklistsCacheTable extends YearlyChecklistsCache
    with TableInfo<$YearlyChecklistsCacheTable, YearlyChecklistsCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $YearlyChecklistsCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, userId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'yearly_checklists_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<YearlyChecklistsCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  YearlyChecklistsCacheData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return YearlyChecklistsCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $YearlyChecklistsCacheTable createAlias(String alias) {
    return $YearlyChecklistsCacheTable(attachedDatabase, alias);
  }
}

class YearlyChecklistsCacheData extends DataClass
    implements Insertable<YearlyChecklistsCacheData> {
  final String id;
  final String userId;
  final String data;
  final int updatedAt;
  const YearlyChecklistsCacheData({
    required this.id,
    required this.userId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  YearlyChecklistsCacheCompanion toCompanion(bool nullToAbsent) {
    return YearlyChecklistsCacheCompanion(
      id: Value(id),
      userId: Value(userId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory YearlyChecklistsCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return YearlyChecklistsCacheData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  YearlyChecklistsCacheData copyWith({
    String? id,
    String? userId,
    String? data,
    int? updatedAt,
  }) => YearlyChecklistsCacheData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  YearlyChecklistsCacheData copyWithCompanion(
    YearlyChecklistsCacheCompanion data,
  ) {
    return YearlyChecklistsCacheData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('YearlyChecklistsCacheData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is YearlyChecklistsCacheData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class YearlyChecklistsCacheCompanion
    extends UpdateCompanion<YearlyChecklistsCacheData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> data;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const YearlyChecklistsCacheCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  YearlyChecklistsCacheCompanion.insert({
    required String id,
    required String userId,
    required String data,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<YearlyChecklistsCacheData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? data,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  YearlyChecklistsCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? data,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return YearlyChecklistsCacheCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('YearlyChecklistsCacheCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeekNotesCacheTable extends WeekNotesCache
    with TableInfo<$WeekNotesCacheTable, WeekNotesCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeekNotesCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _weekKeyMeta = const VerificationMeta(
    'weekKey',
  );
  @override
  late final GeneratedColumn<String> weekKey = GeneratedColumn<String>(
    'week_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [weekKey, userId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'week_notes_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeekNotesCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('week_key')) {
      context.handle(
        _weekKeyMeta,
        weekKey.isAcceptableOrUnknown(data['week_key']!, _weekKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_weekKeyMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {weekKey, userId};
  @override
  WeekNotesCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeekNotesCacheData(
      weekKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}week_key'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WeekNotesCacheTable createAlias(String alias) {
    return $WeekNotesCacheTable(attachedDatabase, alias);
  }
}

class WeekNotesCacheData extends DataClass
    implements Insertable<WeekNotesCacheData> {
  final String weekKey;
  final String userId;
  final String data;
  final int updatedAt;
  const WeekNotesCacheData({
    required this.weekKey,
    required this.userId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['week_key'] = Variable<String>(weekKey);
    map['user_id'] = Variable<String>(userId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  WeekNotesCacheCompanion toCompanion(bool nullToAbsent) {
    return WeekNotesCacheCompanion(
      weekKey: Value(weekKey),
      userId: Value(userId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory WeekNotesCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeekNotesCacheData(
      weekKey: serializer.fromJson<String>(json['weekKey']),
      userId: serializer.fromJson<String>(json['userId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'weekKey': serializer.toJson<String>(weekKey),
      'userId': serializer.toJson<String>(userId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  WeekNotesCacheData copyWith({
    String? weekKey,
    String? userId,
    String? data,
    int? updatedAt,
  }) => WeekNotesCacheData(
    weekKey: weekKey ?? this.weekKey,
    userId: userId ?? this.userId,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WeekNotesCacheData copyWithCompanion(WeekNotesCacheCompanion data) {
    return WeekNotesCacheData(
      weekKey: data.weekKey.present ? data.weekKey.value : this.weekKey,
      userId: data.userId.present ? data.userId.value : this.userId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeekNotesCacheData(')
          ..write('weekKey: $weekKey, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(weekKey, userId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeekNotesCacheData &&
          other.weekKey == this.weekKey &&
          other.userId == this.userId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class WeekNotesCacheCompanion extends UpdateCompanion<WeekNotesCacheData> {
  final Value<String> weekKey;
  final Value<String> userId;
  final Value<String> data;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const WeekNotesCacheCompanion({
    this.weekKey = const Value.absent(),
    this.userId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeekNotesCacheCompanion.insert({
    required String weekKey,
    required String userId,
    required String data,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : weekKey = Value(weekKey),
       userId = Value(userId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<WeekNotesCacheData> custom({
    Expression<String>? weekKey,
    Expression<String>? userId,
    Expression<String>? data,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (weekKey != null) 'week_key': weekKey,
      if (userId != null) 'user_id': userId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeekNotesCacheCompanion copyWith({
    Value<String>? weekKey,
    Value<String>? userId,
    Value<String>? data,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return WeekNotesCacheCompanion(
      weekKey: weekKey ?? this.weekKey,
      userId: userId ?? this.userId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (weekKey.present) {
      map['week_key'] = Variable<String>(weekKey.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeekNotesCacheCompanion(')
          ..write('weekKey: $weekKey, ')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesCacheTable extends CategoriesCache
    with TableInfo<$CategoriesCacheTable, CategoriesCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoriesCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  CategoriesCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoriesCacheData(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CategoriesCacheTable createAlias(String alias) {
    return $CategoriesCacheTable(attachedDatabase, alias);
  }
}

class CategoriesCacheData extends DataClass
    implements Insertable<CategoriesCacheData> {
  final String userId;
  final String data;
  final int updatedAt;
  const CategoriesCacheData({
    required this.userId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CategoriesCacheCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCacheCompanion(
      userId: Value(userId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory CategoriesCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoriesCacheData(
      userId: serializer.fromJson<String>(json['userId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CategoriesCacheData copyWith({
    String? userId,
    String? data,
    int? updatedAt,
  }) => CategoriesCacheData(
    userId: userId ?? this.userId,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CategoriesCacheData copyWithCompanion(CategoriesCacheCompanion data) {
    return CategoriesCacheData(
      userId: data.userId.present ? data.userId.value : this.userId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCacheData(')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoriesCacheData &&
          other.userId == this.userId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class CategoriesCacheCompanion extends UpdateCompanion<CategoriesCacheData> {
  final Value<String> userId;
  final Value<String> data;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CategoriesCacheCompanion({
    this.userId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCacheCompanion.insert({
    required String userId,
    required String data,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<CategoriesCacheData> custom({
    Expression<String>? userId,
    Expression<String>? data,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCacheCompanion copyWith({
    Value<String>? userId,
    Value<String>? data,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return CategoriesCacheCompanion(
      userId: userId ?? this.userId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCacheCompanion(')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlacesCacheTable extends PlacesCache
    with TableInfo<$PlacesCacheTable, PlacesCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlacesCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'places_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlacesCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  PlacesCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlacesCacheData(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlacesCacheTable createAlias(String alias) {
    return $PlacesCacheTable(attachedDatabase, alias);
  }
}

class PlacesCacheData extends DataClass implements Insertable<PlacesCacheData> {
  final String userId;
  final String data;
  final int updatedAt;
  const PlacesCacheData({
    required this.userId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PlacesCacheCompanion toCompanion(bool nullToAbsent) {
    return PlacesCacheCompanion(
      userId: Value(userId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlacesCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlacesCacheData(
      userId: serializer.fromJson<String>(json['userId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PlacesCacheData copyWith({String? userId, String? data, int? updatedAt}) =>
      PlacesCacheData(
        userId: userId ?? this.userId,
        data: data ?? this.data,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PlacesCacheData copyWithCompanion(PlacesCacheCompanion data) {
    return PlacesCacheData(
      userId: data.userId.present ? data.userId.value : this.userId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlacesCacheData(')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlacesCacheData &&
          other.userId == this.userId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class PlacesCacheCompanion extends UpdateCompanion<PlacesCacheData> {
  final Value<String> userId;
  final Value<String> data;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PlacesCacheCompanion({
    this.userId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlacesCacheCompanion.insert({
    required String userId,
    required String data,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<PlacesCacheData> custom({
    Expression<String>? userId,
    Expression<String>? data,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlacesCacheCompanion copyWith({
    Value<String>? userId,
    Value<String>? data,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return PlacesCacheCompanion(
      userId: userId ?? this.userId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlacesCacheCompanion(')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VorlagenCacheTable extends VorlagenCache
    with TableInfo<$VorlagenCacheTable, VorlagenCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VorlagenCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vorlagen_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<VorlagenCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  VorlagenCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VorlagenCacheData(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VorlagenCacheTable createAlias(String alias) {
    return $VorlagenCacheTable(attachedDatabase, alias);
  }
}

class VorlagenCacheData extends DataClass
    implements Insertable<VorlagenCacheData> {
  final String userId;
  final String data;
  final int updatedAt;
  const VorlagenCacheData({
    required this.userId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  VorlagenCacheCompanion toCompanion(bool nullToAbsent) {
    return VorlagenCacheCompanion(
      userId: Value(userId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory VorlagenCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VorlagenCacheData(
      userId: serializer.fromJson<String>(json['userId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  VorlagenCacheData copyWith({String? userId, String? data, int? updatedAt}) =>
      VorlagenCacheData(
        userId: userId ?? this.userId,
        data: data ?? this.data,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  VorlagenCacheData copyWithCompanion(VorlagenCacheCompanion data) {
    return VorlagenCacheData(
      userId: data.userId.present ? data.userId.value : this.userId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VorlagenCacheData(')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VorlagenCacheData &&
          other.userId == this.userId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class VorlagenCacheCompanion extends UpdateCompanion<VorlagenCacheData> {
  final Value<String> userId;
  final Value<String> data;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const VorlagenCacheCompanion({
    this.userId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VorlagenCacheCompanion.insert({
    required String userId,
    required String data,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<VorlagenCacheData> custom({
    Expression<String>? userId,
    Expression<String>? data,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VorlagenCacheCompanion copyWith({
    Value<String>? userId,
    Value<String>? data,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return VorlagenCacheCompanion(
      userId: userId ?? this.userId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VorlagenCacheCompanion(')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodoListenCacheTable extends TodoListenCache
    with TableInfo<$TodoListenCacheTable, TodoListenCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodoListenCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, data, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todo_listen_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<TodoListenCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  TodoListenCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodoListenCacheData(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TodoListenCacheTable createAlias(String alias) {
    return $TodoListenCacheTable(attachedDatabase, alias);
  }
}

class TodoListenCacheData extends DataClass
    implements Insertable<TodoListenCacheData> {
  final String userId;
  final String data;
  final int updatedAt;
  const TodoListenCacheData({
    required this.userId,
    required this.data,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['data'] = Variable<String>(data);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TodoListenCacheCompanion toCompanion(bool nullToAbsent) {
    return TodoListenCacheCompanion(
      userId: Value(userId),
      data: Value(data),
      updatedAt: Value(updatedAt),
    );
  }

  factory TodoListenCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodoListenCacheData(
      userId: serializer.fromJson<String>(json['userId']),
      data: serializer.fromJson<String>(json['data']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'data': serializer.toJson<String>(data),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TodoListenCacheData copyWith({
    String? userId,
    String? data,
    int? updatedAt,
  }) => TodoListenCacheData(
    userId: userId ?? this.userId,
    data: data ?? this.data,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TodoListenCacheData copyWithCompanion(TodoListenCacheCompanion data) {
    return TodoListenCacheData(
      userId: data.userId.present ? data.userId.value : this.userId,
      data: data.data.present ? data.data.value : this.data,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodoListenCacheData(')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, data, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodoListenCacheData &&
          other.userId == this.userId &&
          other.data == this.data &&
          other.updatedAt == this.updatedAt);
}

class TodoListenCacheCompanion extends UpdateCompanion<TodoListenCacheData> {
  final Value<String> userId;
  final Value<String> data;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TodoListenCacheCompanion({
    this.userId = const Value.absent(),
    this.data = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodoListenCacheCompanion.insert({
    required String userId,
    required String data,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       data = Value(data),
       updatedAt = Value(updatedAt);
  static Insertable<TodoListenCacheData> custom({
    Expression<String>? userId,
    Expression<String>? data,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (data != null) 'data': data,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodoListenCacheCompanion copyWith({
    Value<String>? userId,
    Value<String>? data,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TodoListenCacheCompanion(
      userId: userId ?? this.userId,
      data: data ?? this.data,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodoListenCacheCompanion(')
          ..write('userId: $userId, ')
          ..write('data: $data, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EventsCacheTable eventsCache = $EventsCacheTable(this);
  late final $TodosCacheTable todosCache = $TodosCacheTable(this);
  late final $AnnualEventsCacheTable annualEventsCache =
      $AnnualEventsCacheTable(this);
  late final $SeriesRemindersCacheTable seriesRemindersCache =
      $SeriesRemindersCacheTable(this);
  late final $YearlyChecklistsCacheTable yearlyChecklistsCache =
      $YearlyChecklistsCacheTable(this);
  late final $WeekNotesCacheTable weekNotesCache = $WeekNotesCacheTable(this);
  late final $CategoriesCacheTable categoriesCache = $CategoriesCacheTable(
    this,
  );
  late final $PlacesCacheTable placesCache = $PlacesCacheTable(this);
  late final $VorlagenCacheTable vorlagenCache = $VorlagenCacheTable(this);
  late final $TodoListenCacheTable todoListenCache = $TodoListenCacheTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    eventsCache,
    todosCache,
    annualEventsCache,
    seriesRemindersCache,
    yearlyChecklistsCache,
    weekNotesCache,
    categoriesCache,
    placesCache,
    vorlagenCache,
    todoListenCache,
  ];
}

typedef $$EventsCacheTableCreateCompanionBuilder =
    EventsCacheCompanion Function({
      required String id,
      required String userId,
      required String data,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$EventsCacheTableUpdateCompanionBuilder =
    EventsCacheCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> data,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$EventsCacheTableFilterComposer
    extends Composer<_$AppDatabase, $EventsCacheTable> {
  $$EventsCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventsCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsCacheTable> {
  $$EventsCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsCacheTable> {
  $$EventsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EventsCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsCacheTable,
          EventsCacheData,
          $$EventsCacheTableFilterComposer,
          $$EventsCacheTableOrderingComposer,
          $$EventsCacheTableAnnotationComposer,
          $$EventsCacheTableCreateCompanionBuilder,
          $$EventsCacheTableUpdateCompanionBuilder,
          (
            EventsCacheData,
            BaseReferences<_$AppDatabase, $EventsCacheTable, EventsCacheData>,
          ),
          EventsCacheData,
          PrefetchHooks Function()
        > {
  $$EventsCacheTableTableManager(_$AppDatabase db, $EventsCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCacheCompanion(
                id: id,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String data,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EventsCacheCompanion.insert(
                id: id,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsCacheTable,
      EventsCacheData,
      $$EventsCacheTableFilterComposer,
      $$EventsCacheTableOrderingComposer,
      $$EventsCacheTableAnnotationComposer,
      $$EventsCacheTableCreateCompanionBuilder,
      $$EventsCacheTableUpdateCompanionBuilder,
      (
        EventsCacheData,
        BaseReferences<_$AppDatabase, $EventsCacheTable, EventsCacheData>,
      ),
      EventsCacheData,
      PrefetchHooks Function()
    >;
typedef $$TodosCacheTableCreateCompanionBuilder =
    TodosCacheCompanion Function({
      required String id,
      required String userId,
      required String data,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$TodosCacheTableUpdateCompanionBuilder =
    TodosCacheCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> data,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$TodosCacheTableFilterComposer
    extends Composer<_$AppDatabase, $TodosCacheTable> {
  $$TodosCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodosCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $TodosCacheTable> {
  $$TodosCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodosCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodosCacheTable> {
  $$TodosCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TodosCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodosCacheTable,
          TodosCacheData,
          $$TodosCacheTableFilterComposer,
          $$TodosCacheTableOrderingComposer,
          $$TodosCacheTableAnnotationComposer,
          $$TodosCacheTableCreateCompanionBuilder,
          $$TodosCacheTableUpdateCompanionBuilder,
          (
            TodosCacheData,
            BaseReferences<_$AppDatabase, $TodosCacheTable, TodosCacheData>,
          ),
          TodosCacheData,
          PrefetchHooks Function()
        > {
  $$TodosCacheTableTableManager(_$AppDatabase db, $TodosCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodosCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodosCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodosCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCacheCompanion(
                id: id,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String data,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TodosCacheCompanion.insert(
                id: id,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodosCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodosCacheTable,
      TodosCacheData,
      $$TodosCacheTableFilterComposer,
      $$TodosCacheTableOrderingComposer,
      $$TodosCacheTableAnnotationComposer,
      $$TodosCacheTableCreateCompanionBuilder,
      $$TodosCacheTableUpdateCompanionBuilder,
      (
        TodosCacheData,
        BaseReferences<_$AppDatabase, $TodosCacheTable, TodosCacheData>,
      ),
      TodosCacheData,
      PrefetchHooks Function()
    >;
typedef $$AnnualEventsCacheTableCreateCompanionBuilder =
    AnnualEventsCacheCompanion Function({
      required String id,
      required String userId,
      required String data,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AnnualEventsCacheTableUpdateCompanionBuilder =
    AnnualEventsCacheCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> data,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AnnualEventsCacheTableFilterComposer
    extends Composer<_$AppDatabase, $AnnualEventsCacheTable> {
  $$AnnualEventsCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnnualEventsCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnualEventsCacheTable> {
  $$AnnualEventsCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnnualEventsCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnualEventsCacheTable> {
  $$AnnualEventsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AnnualEventsCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnnualEventsCacheTable,
          AnnualEventsCacheData,
          $$AnnualEventsCacheTableFilterComposer,
          $$AnnualEventsCacheTableOrderingComposer,
          $$AnnualEventsCacheTableAnnotationComposer,
          $$AnnualEventsCacheTableCreateCompanionBuilder,
          $$AnnualEventsCacheTableUpdateCompanionBuilder,
          (
            AnnualEventsCacheData,
            BaseReferences<
              _$AppDatabase,
              $AnnualEventsCacheTable,
              AnnualEventsCacheData
            >,
          ),
          AnnualEventsCacheData,
          PrefetchHooks Function()
        > {
  $$AnnualEventsCacheTableTableManager(
    _$AppDatabase db,
    $AnnualEventsCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnualEventsCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnualEventsCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnualEventsCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnnualEventsCacheCompanion(
                id: id,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String data,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AnnualEventsCacheCompanion.insert(
                id: id,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnnualEventsCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnnualEventsCacheTable,
      AnnualEventsCacheData,
      $$AnnualEventsCacheTableFilterComposer,
      $$AnnualEventsCacheTableOrderingComposer,
      $$AnnualEventsCacheTableAnnotationComposer,
      $$AnnualEventsCacheTableCreateCompanionBuilder,
      $$AnnualEventsCacheTableUpdateCompanionBuilder,
      (
        AnnualEventsCacheData,
        BaseReferences<
          _$AppDatabase,
          $AnnualEventsCacheTable,
          AnnualEventsCacheData
        >,
      ),
      AnnualEventsCacheData,
      PrefetchHooks Function()
    >;
typedef $$SeriesRemindersCacheTableCreateCompanionBuilder =
    SeriesRemindersCacheCompanion Function({
      required String id,
      required String userId,
      required String data,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SeriesRemindersCacheTableUpdateCompanionBuilder =
    SeriesRemindersCacheCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> data,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SeriesRemindersCacheTableFilterComposer
    extends Composer<_$AppDatabase, $SeriesRemindersCacheTable> {
  $$SeriesRemindersCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeriesRemindersCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $SeriesRemindersCacheTable> {
  $$SeriesRemindersCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeriesRemindersCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeriesRemindersCacheTable> {
  $$SeriesRemindersCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SeriesRemindersCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeriesRemindersCacheTable,
          SeriesRemindersCacheData,
          $$SeriesRemindersCacheTableFilterComposer,
          $$SeriesRemindersCacheTableOrderingComposer,
          $$SeriesRemindersCacheTableAnnotationComposer,
          $$SeriesRemindersCacheTableCreateCompanionBuilder,
          $$SeriesRemindersCacheTableUpdateCompanionBuilder,
          (
            SeriesRemindersCacheData,
            BaseReferences<
              _$AppDatabase,
              $SeriesRemindersCacheTable,
              SeriesRemindersCacheData
            >,
          ),
          SeriesRemindersCacheData,
          PrefetchHooks Function()
        > {
  $$SeriesRemindersCacheTableTableManager(
    _$AppDatabase db,
    $SeriesRemindersCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesRemindersCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesRemindersCacheTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SeriesRemindersCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SeriesRemindersCacheCompanion(
                id: id,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String data,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SeriesRemindersCacheCompanion.insert(
                id: id,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeriesRemindersCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeriesRemindersCacheTable,
      SeriesRemindersCacheData,
      $$SeriesRemindersCacheTableFilterComposer,
      $$SeriesRemindersCacheTableOrderingComposer,
      $$SeriesRemindersCacheTableAnnotationComposer,
      $$SeriesRemindersCacheTableCreateCompanionBuilder,
      $$SeriesRemindersCacheTableUpdateCompanionBuilder,
      (
        SeriesRemindersCacheData,
        BaseReferences<
          _$AppDatabase,
          $SeriesRemindersCacheTable,
          SeriesRemindersCacheData
        >,
      ),
      SeriesRemindersCacheData,
      PrefetchHooks Function()
    >;
typedef $$YearlyChecklistsCacheTableCreateCompanionBuilder =
    YearlyChecklistsCacheCompanion Function({
      required String id,
      required String userId,
      required String data,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$YearlyChecklistsCacheTableUpdateCompanionBuilder =
    YearlyChecklistsCacheCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> data,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$YearlyChecklistsCacheTableFilterComposer
    extends Composer<_$AppDatabase, $YearlyChecklistsCacheTable> {
  $$YearlyChecklistsCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$YearlyChecklistsCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $YearlyChecklistsCacheTable> {
  $$YearlyChecklistsCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$YearlyChecklistsCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $YearlyChecklistsCacheTable> {
  $$YearlyChecklistsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$YearlyChecklistsCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $YearlyChecklistsCacheTable,
          YearlyChecklistsCacheData,
          $$YearlyChecklistsCacheTableFilterComposer,
          $$YearlyChecklistsCacheTableOrderingComposer,
          $$YearlyChecklistsCacheTableAnnotationComposer,
          $$YearlyChecklistsCacheTableCreateCompanionBuilder,
          $$YearlyChecklistsCacheTableUpdateCompanionBuilder,
          (
            YearlyChecklistsCacheData,
            BaseReferences<
              _$AppDatabase,
              $YearlyChecklistsCacheTable,
              YearlyChecklistsCacheData
            >,
          ),
          YearlyChecklistsCacheData,
          PrefetchHooks Function()
        > {
  $$YearlyChecklistsCacheTableTableManager(
    _$AppDatabase db,
    $YearlyChecklistsCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$YearlyChecklistsCacheTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$YearlyChecklistsCacheTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$YearlyChecklistsCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => YearlyChecklistsCacheCompanion(
                id: id,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String data,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => YearlyChecklistsCacheCompanion.insert(
                id: id,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$YearlyChecklistsCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $YearlyChecklistsCacheTable,
      YearlyChecklistsCacheData,
      $$YearlyChecklistsCacheTableFilterComposer,
      $$YearlyChecklistsCacheTableOrderingComposer,
      $$YearlyChecklistsCacheTableAnnotationComposer,
      $$YearlyChecklistsCacheTableCreateCompanionBuilder,
      $$YearlyChecklistsCacheTableUpdateCompanionBuilder,
      (
        YearlyChecklistsCacheData,
        BaseReferences<
          _$AppDatabase,
          $YearlyChecklistsCacheTable,
          YearlyChecklistsCacheData
        >,
      ),
      YearlyChecklistsCacheData,
      PrefetchHooks Function()
    >;
typedef $$WeekNotesCacheTableCreateCompanionBuilder =
    WeekNotesCacheCompanion Function({
      required String weekKey,
      required String userId,
      required String data,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$WeekNotesCacheTableUpdateCompanionBuilder =
    WeekNotesCacheCompanion Function({
      Value<String> weekKey,
      Value<String> userId,
      Value<String> data,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$WeekNotesCacheTableFilterComposer
    extends Composer<_$AppDatabase, $WeekNotesCacheTable> {
  $$WeekNotesCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get weekKey => $composableBuilder(
    column: $table.weekKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeekNotesCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $WeekNotesCacheTable> {
  $$WeekNotesCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get weekKey => $composableBuilder(
    column: $table.weekKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeekNotesCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeekNotesCacheTable> {
  $$WeekNotesCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get weekKey =>
      $composableBuilder(column: $table.weekKey, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$WeekNotesCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeekNotesCacheTable,
          WeekNotesCacheData,
          $$WeekNotesCacheTableFilterComposer,
          $$WeekNotesCacheTableOrderingComposer,
          $$WeekNotesCacheTableAnnotationComposer,
          $$WeekNotesCacheTableCreateCompanionBuilder,
          $$WeekNotesCacheTableUpdateCompanionBuilder,
          (
            WeekNotesCacheData,
            BaseReferences<
              _$AppDatabase,
              $WeekNotesCacheTable,
              WeekNotesCacheData
            >,
          ),
          WeekNotesCacheData,
          PrefetchHooks Function()
        > {
  $$WeekNotesCacheTableTableManager(
    _$AppDatabase db,
    $WeekNotesCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeekNotesCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeekNotesCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeekNotesCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> weekKey = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeekNotesCacheCompanion(
                weekKey: weekKey,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String weekKey,
                required String userId,
                required String data,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WeekNotesCacheCompanion.insert(
                weekKey: weekKey,
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeekNotesCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeekNotesCacheTable,
      WeekNotesCacheData,
      $$WeekNotesCacheTableFilterComposer,
      $$WeekNotesCacheTableOrderingComposer,
      $$WeekNotesCacheTableAnnotationComposer,
      $$WeekNotesCacheTableCreateCompanionBuilder,
      $$WeekNotesCacheTableUpdateCompanionBuilder,
      (
        WeekNotesCacheData,
        BaseReferences<_$AppDatabase, $WeekNotesCacheTable, WeekNotesCacheData>,
      ),
      WeekNotesCacheData,
      PrefetchHooks Function()
    >;
typedef $$CategoriesCacheTableCreateCompanionBuilder =
    CategoriesCacheCompanion Function({
      required String userId,
      required String data,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$CategoriesCacheTableUpdateCompanionBuilder =
    CategoriesCacheCompanion Function({
      Value<String> userId,
      Value<String> data,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$CategoriesCacheTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesCacheTable> {
  $$CategoriesCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesCacheTable> {
  $$CategoriesCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesCacheTable> {
  $$CategoriesCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CategoriesCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesCacheTable,
          CategoriesCacheData,
          $$CategoriesCacheTableFilterComposer,
          $$CategoriesCacheTableOrderingComposer,
          $$CategoriesCacheTableAnnotationComposer,
          $$CategoriesCacheTableCreateCompanionBuilder,
          $$CategoriesCacheTableUpdateCompanionBuilder,
          (
            CategoriesCacheData,
            BaseReferences<
              _$AppDatabase,
              $CategoriesCacheTable,
              CategoriesCacheData
            >,
          ),
          CategoriesCacheData,
          PrefetchHooks Function()
        > {
  $$CategoriesCacheTableTableManager(
    _$AppDatabase db,
    $CategoriesCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCacheCompanion(
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String data,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCacheCompanion.insert(
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesCacheTable,
      CategoriesCacheData,
      $$CategoriesCacheTableFilterComposer,
      $$CategoriesCacheTableOrderingComposer,
      $$CategoriesCacheTableAnnotationComposer,
      $$CategoriesCacheTableCreateCompanionBuilder,
      $$CategoriesCacheTableUpdateCompanionBuilder,
      (
        CategoriesCacheData,
        BaseReferences<
          _$AppDatabase,
          $CategoriesCacheTable,
          CategoriesCacheData
        >,
      ),
      CategoriesCacheData,
      PrefetchHooks Function()
    >;
typedef $$PlacesCacheTableCreateCompanionBuilder =
    PlacesCacheCompanion Function({
      required String userId,
      required String data,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$PlacesCacheTableUpdateCompanionBuilder =
    PlacesCacheCompanion Function({
      Value<String> userId,
      Value<String> data,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$PlacesCacheTableFilterComposer
    extends Composer<_$AppDatabase, $PlacesCacheTable> {
  $$PlacesCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlacesCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $PlacesCacheTable> {
  $$PlacesCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlacesCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlacesCacheTable> {
  $$PlacesCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PlacesCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlacesCacheTable,
          PlacesCacheData,
          $$PlacesCacheTableFilterComposer,
          $$PlacesCacheTableOrderingComposer,
          $$PlacesCacheTableAnnotationComposer,
          $$PlacesCacheTableCreateCompanionBuilder,
          $$PlacesCacheTableUpdateCompanionBuilder,
          (
            PlacesCacheData,
            BaseReferences<_$AppDatabase, $PlacesCacheTable, PlacesCacheData>,
          ),
          PlacesCacheData,
          PrefetchHooks Function()
        > {
  $$PlacesCacheTableTableManager(_$AppDatabase db, $PlacesCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlacesCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlacesCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlacesCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlacesCacheCompanion(
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String data,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlacesCacheCompanion.insert(
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlacesCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlacesCacheTable,
      PlacesCacheData,
      $$PlacesCacheTableFilterComposer,
      $$PlacesCacheTableOrderingComposer,
      $$PlacesCacheTableAnnotationComposer,
      $$PlacesCacheTableCreateCompanionBuilder,
      $$PlacesCacheTableUpdateCompanionBuilder,
      (
        PlacesCacheData,
        BaseReferences<_$AppDatabase, $PlacesCacheTable, PlacesCacheData>,
      ),
      PlacesCacheData,
      PrefetchHooks Function()
    >;
typedef $$VorlagenCacheTableCreateCompanionBuilder =
    VorlagenCacheCompanion Function({
      required String userId,
      required String data,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$VorlagenCacheTableUpdateCompanionBuilder =
    VorlagenCacheCompanion Function({
      Value<String> userId,
      Value<String> data,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$VorlagenCacheTableFilterComposer
    extends Composer<_$AppDatabase, $VorlagenCacheTable> {
  $$VorlagenCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VorlagenCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $VorlagenCacheTable> {
  $$VorlagenCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VorlagenCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $VorlagenCacheTable> {
  $$VorlagenCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$VorlagenCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VorlagenCacheTable,
          VorlagenCacheData,
          $$VorlagenCacheTableFilterComposer,
          $$VorlagenCacheTableOrderingComposer,
          $$VorlagenCacheTableAnnotationComposer,
          $$VorlagenCacheTableCreateCompanionBuilder,
          $$VorlagenCacheTableUpdateCompanionBuilder,
          (
            VorlagenCacheData,
            BaseReferences<
              _$AppDatabase,
              $VorlagenCacheTable,
              VorlagenCacheData
            >,
          ),
          VorlagenCacheData,
          PrefetchHooks Function()
        > {
  $$VorlagenCacheTableTableManager(_$AppDatabase db, $VorlagenCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VorlagenCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VorlagenCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VorlagenCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VorlagenCacheCompanion(
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String data,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => VorlagenCacheCompanion.insert(
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VorlagenCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VorlagenCacheTable,
      VorlagenCacheData,
      $$VorlagenCacheTableFilterComposer,
      $$VorlagenCacheTableOrderingComposer,
      $$VorlagenCacheTableAnnotationComposer,
      $$VorlagenCacheTableCreateCompanionBuilder,
      $$VorlagenCacheTableUpdateCompanionBuilder,
      (
        VorlagenCacheData,
        BaseReferences<_$AppDatabase, $VorlagenCacheTable, VorlagenCacheData>,
      ),
      VorlagenCacheData,
      PrefetchHooks Function()
    >;
typedef $$TodoListenCacheTableCreateCompanionBuilder =
    TodoListenCacheCompanion Function({
      required String userId,
      required String data,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$TodoListenCacheTableUpdateCompanionBuilder =
    TodoListenCacheCompanion Function({
      Value<String> userId,
      Value<String> data,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$TodoListenCacheTableFilterComposer
    extends Composer<_$AppDatabase, $TodoListenCacheTable> {
  $$TodoListenCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodoListenCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $TodoListenCacheTable> {
  $$TodoListenCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodoListenCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodoListenCacheTable> {
  $$TodoListenCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TodoListenCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodoListenCacheTable,
          TodoListenCacheData,
          $$TodoListenCacheTableFilterComposer,
          $$TodoListenCacheTableOrderingComposer,
          $$TodoListenCacheTableAnnotationComposer,
          $$TodoListenCacheTableCreateCompanionBuilder,
          $$TodoListenCacheTableUpdateCompanionBuilder,
          (
            TodoListenCacheData,
            BaseReferences<
              _$AppDatabase,
              $TodoListenCacheTable,
              TodoListenCacheData
            >,
          ),
          TodoListenCacheData,
          PrefetchHooks Function()
        > {
  $$TodoListenCacheTableTableManager(
    _$AppDatabase db,
    $TodoListenCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodoListenCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodoListenCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodoListenCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodoListenCacheCompanion(
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                required String data,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TodoListenCacheCompanion.insert(
                userId: userId,
                data: data,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodoListenCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodoListenCacheTable,
      TodoListenCacheData,
      $$TodoListenCacheTableFilterComposer,
      $$TodoListenCacheTableOrderingComposer,
      $$TodoListenCacheTableAnnotationComposer,
      $$TodoListenCacheTableCreateCompanionBuilder,
      $$TodoListenCacheTableUpdateCompanionBuilder,
      (
        TodoListenCacheData,
        BaseReferences<
          _$AppDatabase,
          $TodoListenCacheTable,
          TodoListenCacheData
        >,
      ),
      TodoListenCacheData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EventsCacheTableTableManager get eventsCache =>
      $$EventsCacheTableTableManager(_db, _db.eventsCache);
  $$TodosCacheTableTableManager get todosCache =>
      $$TodosCacheTableTableManager(_db, _db.todosCache);
  $$AnnualEventsCacheTableTableManager get annualEventsCache =>
      $$AnnualEventsCacheTableTableManager(_db, _db.annualEventsCache);
  $$SeriesRemindersCacheTableTableManager get seriesRemindersCache =>
      $$SeriesRemindersCacheTableTableManager(_db, _db.seriesRemindersCache);
  $$YearlyChecklistsCacheTableTableManager get yearlyChecklistsCache =>
      $$YearlyChecklistsCacheTableTableManager(_db, _db.yearlyChecklistsCache);
  $$WeekNotesCacheTableTableManager get weekNotesCache =>
      $$WeekNotesCacheTableTableManager(_db, _db.weekNotesCache);
  $$CategoriesCacheTableTableManager get categoriesCache =>
      $$CategoriesCacheTableTableManager(_db, _db.categoriesCache);
  $$PlacesCacheTableTableManager get placesCache =>
      $$PlacesCacheTableTableManager(_db, _db.placesCache);
  $$VorlagenCacheTableTableManager get vorlagenCache =>
      $$VorlagenCacheTableTableManager(_db, _db.vorlagenCache);
  $$TodoListenCacheTableTableManager get todoListenCache =>
      $$TodoListenCacheTableTableManager(_db, _db.todoListenCache);
}
