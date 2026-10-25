// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CustomersTable extends Customers
    with TableInfo<$CustomersTable, CustomerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastVisitAtMeta = const VerificationMeta(
    'lastVisitAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastVisitAt = GeneratedColumn<DateTime>(
    'last_visit_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isGuestMeta = const VerificationMeta(
    'isGuest',
  );
  @override
  late final GeneratedColumn<bool> isGuest = GeneratedColumn<bool>(
    'is_guest',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_guest" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _birthYearMeta = const VerificationMeta(
    'birthYear',
  );
  @override
  late final GeneratedColumn<int> birthYear = GeneratedColumn<int>(
    'birth_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    notes,
    lastVisitAt,
    isGuest,
    birthYear,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('last_visit_at')) {
      context.handle(
        _lastVisitAtMeta,
        lastVisitAt.isAcceptableOrUnknown(
          data['last_visit_at']!,
          _lastVisitAtMeta,
        ),
      );
    }
    if (data.containsKey('is_guest')) {
      context.handle(
        _isGuestMeta,
        isGuest.isAcceptableOrUnknown(data['is_guest']!, _isGuestMeta),
      );
    }
    if (data.containsKey('birth_year')) {
      context.handle(
        _birthYearMeta,
        birthYear.isAcceptableOrUnknown(data['birth_year']!, _birthYearMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  CustomerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      lastVisitAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_visit_at'],
      ),
      isGuest: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_guest'],
      )!,
      birthYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birth_year'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CustomersTable createAlias(String alias) {
    return $CustomersTable(attachedDatabase, alias);
  }
}

class CustomerRow extends DataClass implements Insertable<CustomerRow> {
  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime? lastVisitAt;

  /// A walk-in who never registered (brief §12).
  final bool isGuest;

  /// Year of birth given at registration; null when not given (v15).
  final int? birthYear;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CustomerRow({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    this.lastVisitAt,
    required this.isGuest,
    this.birthYear,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || lastVisitAt != null) {
      map['last_visit_at'] = Variable<DateTime>(lastVisitAt);
    }
    map['is_guest'] = Variable<bool>(isGuest);
    if (!nullToAbsent || birthYear != null) {
      map['birth_year'] = Variable<int>(birthYear);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CustomersCompanion toCompanion(bool nullToAbsent) {
    return CustomersCompanion(
      id: Value(id),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      lastVisitAt: lastVisitAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastVisitAt),
      isGuest: Value(isGuest),
      birthYear: birthYear == null && nullToAbsent
          ? const Value.absent()
          : Value(birthYear),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CustomerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomerRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      notes: serializer.fromJson<String?>(json['notes']),
      lastVisitAt: serializer.fromJson<DateTime?>(json['lastVisitAt']),
      isGuest: serializer.fromJson<bool>(json['isGuest']),
      birthYear: serializer.fromJson<int?>(json['birthYear']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'notes': serializer.toJson<String?>(notes),
      'lastVisitAt': serializer.toJson<DateTime?>(lastVisitAt),
      'isGuest': serializer.toJson<bool>(isGuest),
      'birthYear': serializer.toJson<int?>(birthYear),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CustomerRow copyWith({
    String? id,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> lastVisitAt = const Value.absent(),
    bool? isGuest,
    Value<int?> birthYear = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CustomerRow(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    notes: notes.present ? notes.value : this.notes,
    lastVisitAt: lastVisitAt.present ? lastVisitAt.value : this.lastVisitAt,
    isGuest: isGuest ?? this.isGuest,
    birthYear: birthYear.present ? birthYear.value : this.birthYear,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CustomerRow copyWithCompanion(CustomersCompanion data) {
    return CustomerRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      notes: data.notes.present ? data.notes.value : this.notes,
      lastVisitAt: data.lastVisitAt.present
          ? data.lastVisitAt.value
          : this.lastVisitAt,
      isGuest: data.isGuest.present ? data.isGuest.value : this.isGuest,
      birthYear: data.birthYear.present ? data.birthYear.value : this.birthYear,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomerRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('lastVisitAt: $lastVisitAt, ')
          ..write('isGuest: $isGuest, ')
          ..write('birthYear: $birthYear, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    notes,
    lastVisitAt,
    isGuest,
    birthYear,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomerRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.notes == this.notes &&
          other.lastVisitAt == this.lastVisitAt &&
          other.isGuest == this.isGuest &&
          other.birthYear == this.birthYear &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CustomersCompanion extends UpdateCompanion<CustomerRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> notes;
  final Value<DateTime?> lastVisitAt;
  final Value<bool> isGuest;
  final Value<int?> birthYear;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    this.lastVisitAt = const Value.absent(),
    this.isGuest = const Value.absent(),
    this.birthYear = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomersCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    this.lastVisitAt = const Value.absent(),
    this.isGuest = const Value.absent(),
    this.birthYear = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CustomerRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? notes,
    Expression<DateTime>? lastVisitAt,
    Expression<bool>? isGuest,
    Expression<int>? birthYear,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (notes != null) 'notes': notes,
      if (lastVisitAt != null) 'last_visit_at': lastVisitAt,
      if (isGuest != null) 'is_guest': isGuest,
      if (birthYear != null) 'birth_year': birthYear,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? notes,
    Value<DateTime?>? lastVisitAt,
    Value<bool>? isGuest,
    Value<int?>? birthYear,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      lastVisitAt: lastVisitAt ?? this.lastVisitAt,
      isGuest: isGuest ?? this.isGuest,
      birthYear: birthYear ?? this.birthYear,
      createdAt: createdAt ?? this.createdAt,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (lastVisitAt.present) {
      map['last_visit_at'] = Variable<DateTime>(lastVisitAt.value);
    }
    if (isGuest.present) {
      map['is_guest'] = Variable<bool>(isGuest.value);
    }
    if (birthYear.present) {
      map['birth_year'] = Variable<int>(birthYear.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('lastVisitAt: $lastVisitAt, ')
          ..write('isGuest: $isGuest, ')
          ..write('birthYear: $birthYear, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActivitiesTable extends Activities
    with TableInfo<$ActivitiesTable, ActivityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usesControllersMeta = const VerificationMeta(
    'usesControllers',
  );
  @override
  late final GeneratedColumn<bool> usesControllers = GeneratedColumn<bool>(
    'uses_controllers',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("uses_controllers" IN (0, 1))',
    ),
  );
  static const VerificationMeta _usesGamesMeta = const VerificationMeta(
    'usesGames',
  );
  @override
  late final GeneratedColumn<bool> usesGames = GeneratedColumn<bool>(
    'uses_games',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("uses_games" IN (0, 1))',
    ),
  );
  static const VerificationMeta _durationModelMeta = const VerificationMeta(
    'durationModel',
  );
  @override
  late final GeneratedColumn<String> durationModel = GeneratedColumn<String>(
    'duration_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legacyHappyHourEligibleMeta =
      const VerificationMeta('legacyHappyHourEligible');
  @override
  late final GeneratedColumn<bool> legacyHappyHourEligible =
      GeneratedColumn<bool>(
        'happy_hour_eligible',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("happy_hour_eligible" IN (0, 1))',
        ),
        clientDefault: () => false,
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _overtimeGraceMinutesMeta =
      const VerificationMeta('overtimeGraceMinutes');
  @override
  late final GeneratedColumn<int> overtimeGraceMinutes = GeneratedColumn<int>(
    'overtime_grace_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    name,
    usesControllers,
    usesGames,
    durationModel,
    legacyHappyHourEligible,
    sortOrder,
    active,
    overtimeGraceMinutes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('uses_controllers')) {
      context.handle(
        _usesControllersMeta,
        usesControllers.isAcceptableOrUnknown(
          data['uses_controllers']!,
          _usesControllersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_usesControllersMeta);
    }
    if (data.containsKey('uses_games')) {
      context.handle(
        _usesGamesMeta,
        usesGames.isAcceptableOrUnknown(data['uses_games']!, _usesGamesMeta),
      );
    } else if (isInserting) {
      context.missing(_usesGamesMeta);
    }
    if (data.containsKey('duration_model')) {
      context.handle(
        _durationModelMeta,
        durationModel.isAcceptableOrUnknown(
          data['duration_model']!,
          _durationModelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationModelMeta);
    }
    if (data.containsKey('happy_hour_eligible')) {
      context.handle(
        _legacyHappyHourEligibleMeta,
        legacyHappyHourEligible.isAcceptableOrUnknown(
          data['happy_hour_eligible']!,
          _legacyHappyHourEligibleMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('overtime_grace_minutes')) {
      context.handle(
        _overtimeGraceMinutesMeta,
        overtimeGraceMinutes.isAcceptableOrUnknown(
          data['overtime_grace_minutes']!,
          _overtimeGraceMinutesMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      usesControllers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}uses_controllers'],
      )!,
      usesGames: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}uses_games'],
      )!,
      durationModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duration_model'],
      )!,
      legacyHappyHourEligible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}happy_hour_eligible'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      overtimeGraceMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overtime_grace_minutes'],
      )!,
    );
  }

  @override
  $ActivitiesTable createAlias(String alias) {
    return $ActivitiesTable(attachedDatabase, alias);
  }
}

class ActivityRow extends DataClass implements Insertable<ActivityRow> {
  final String id;
  final String code;
  final String name;
  final bool usesControllers;
  final bool usesGames;
  final String durationModel;

  /// Retired in v16: an activity pricing flag older builds billed by (time-of-
  /// day prices are pricing rules now). The column stays so device files made
  /// by those builds keep opening and inserting; nothing reads it. Filled in
  /// Dart because the old column has no SQL default.
  final bool legacyHappyHourEligible;
  final int sortOrder;
  final bool active;

  /// v17: overtime allowed free past a session's booked end when it ends on
  /// this type (Activity.overtimeGraceMinutes). Part of the pricing snapshot.
  final int overtimeGraceMinutes;
  const ActivityRow({
    required this.id,
    required this.code,
    required this.name,
    required this.usesControllers,
    required this.usesGames,
    required this.durationModel,
    required this.legacyHappyHourEligible,
    required this.sortOrder,
    required this.active,
    required this.overtimeGraceMinutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['uses_controllers'] = Variable<bool>(usesControllers);
    map['uses_games'] = Variable<bool>(usesGames);
    map['duration_model'] = Variable<String>(durationModel);
    map['happy_hour_eligible'] = Variable<bool>(legacyHappyHourEligible);
    map['sort_order'] = Variable<int>(sortOrder);
    map['active'] = Variable<bool>(active);
    map['overtime_grace_minutes'] = Variable<int>(overtimeGraceMinutes);
    return map;
  }

  ActivitiesCompanion toCompanion(bool nullToAbsent) {
    return ActivitiesCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      usesControllers: Value(usesControllers),
      usesGames: Value(usesGames),
      durationModel: Value(durationModel),
      legacyHappyHourEligible: Value(legacyHappyHourEligible),
      sortOrder: Value(sortOrder),
      active: Value(active),
      overtimeGraceMinutes: Value(overtimeGraceMinutes),
    );
  }

  factory ActivityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityRow(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      usesControllers: serializer.fromJson<bool>(json['usesControllers']),
      usesGames: serializer.fromJson<bool>(json['usesGames']),
      durationModel: serializer.fromJson<String>(json['durationModel']),
      legacyHappyHourEligible: serializer.fromJson<bool>(
        json['legacyHappyHourEligible'],
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      active: serializer.fromJson<bool>(json['active']),
      overtimeGraceMinutes: serializer.fromJson<int>(
        json['overtimeGraceMinutes'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'usesControllers': serializer.toJson<bool>(usesControllers),
      'usesGames': serializer.toJson<bool>(usesGames),
      'durationModel': serializer.toJson<String>(durationModel),
      'legacyHappyHourEligible': serializer.toJson<bool>(
        legacyHappyHourEligible,
      ),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'active': serializer.toJson<bool>(active),
      'overtimeGraceMinutes': serializer.toJson<int>(overtimeGraceMinutes),
    };
  }

  ActivityRow copyWith({
    String? id,
    String? code,
    String? name,
    bool? usesControllers,
    bool? usesGames,
    String? durationModel,
    bool? legacyHappyHourEligible,
    int? sortOrder,
    bool? active,
    int? overtimeGraceMinutes,
  }) => ActivityRow(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    usesControllers: usesControllers ?? this.usesControllers,
    usesGames: usesGames ?? this.usesGames,
    durationModel: durationModel ?? this.durationModel,
    legacyHappyHourEligible:
        legacyHappyHourEligible ?? this.legacyHappyHourEligible,
    sortOrder: sortOrder ?? this.sortOrder,
    active: active ?? this.active,
    overtimeGraceMinutes: overtimeGraceMinutes ?? this.overtimeGraceMinutes,
  );
  ActivityRow copyWithCompanion(ActivitiesCompanion data) {
    return ActivityRow(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      usesControllers: data.usesControllers.present
          ? data.usesControllers.value
          : this.usesControllers,
      usesGames: data.usesGames.present ? data.usesGames.value : this.usesGames,
      durationModel: data.durationModel.present
          ? data.durationModel.value
          : this.durationModel,
      legacyHappyHourEligible: data.legacyHappyHourEligible.present
          ? data.legacyHappyHourEligible.value
          : this.legacyHappyHourEligible,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      active: data.active.present ? data.active.value : this.active,
      overtimeGraceMinutes: data.overtimeGraceMinutes.present
          ? data.overtimeGraceMinutes.value
          : this.overtimeGraceMinutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityRow(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('usesControllers: $usesControllers, ')
          ..write('usesGames: $usesGames, ')
          ..write('durationModel: $durationModel, ')
          ..write('legacyHappyHourEligible: $legacyHappyHourEligible, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('active: $active, ')
          ..write('overtimeGraceMinutes: $overtimeGraceMinutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    usesControllers,
    usesGames,
    durationModel,
    legacyHappyHourEligible,
    sortOrder,
    active,
    overtimeGraceMinutes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityRow &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.usesControllers == this.usesControllers &&
          other.usesGames == this.usesGames &&
          other.durationModel == this.durationModel &&
          other.legacyHappyHourEligible == this.legacyHappyHourEligible &&
          other.sortOrder == this.sortOrder &&
          other.active == this.active &&
          other.overtimeGraceMinutes == this.overtimeGraceMinutes);
}

class ActivitiesCompanion extends UpdateCompanion<ActivityRow> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<bool> usesControllers;
  final Value<bool> usesGames;
  final Value<String> durationModel;
  final Value<bool> legacyHappyHourEligible;
  final Value<int> sortOrder;
  final Value<bool> active;
  final Value<int> overtimeGraceMinutes;
  final Value<int> rowid;
  const ActivitiesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.usesControllers = const Value.absent(),
    this.usesGames = const Value.absent(),
    this.durationModel = const Value.absent(),
    this.legacyHappyHourEligible = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.active = const Value.absent(),
    this.overtimeGraceMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivitiesCompanion.insert({
    required String id,
    required String code,
    required String name,
    required bool usesControllers,
    required bool usesGames,
    required String durationModel,
    this.legacyHappyHourEligible = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.active = const Value.absent(),
    this.overtimeGraceMinutes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name),
       usesControllers = Value(usesControllers),
       usesGames = Value(usesGames),
       durationModel = Value(durationModel);
  static Insertable<ActivityRow> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<bool>? usesControllers,
    Expression<bool>? usesGames,
    Expression<String>? durationModel,
    Expression<bool>? legacyHappyHourEligible,
    Expression<int>? sortOrder,
    Expression<bool>? active,
    Expression<int>? overtimeGraceMinutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (usesControllers != null) 'uses_controllers': usesControllers,
      if (usesGames != null) 'uses_games': usesGames,
      if (durationModel != null) 'duration_model': durationModel,
      if (legacyHappyHourEligible != null)
        'happy_hour_eligible': legacyHappyHourEligible,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (active != null) 'active': active,
      if (overtimeGraceMinutes != null)
        'overtime_grace_minutes': overtimeGraceMinutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivitiesCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<bool>? usesControllers,
    Value<bool>? usesGames,
    Value<String>? durationModel,
    Value<bool>? legacyHappyHourEligible,
    Value<int>? sortOrder,
    Value<bool>? active,
    Value<int>? overtimeGraceMinutes,
    Value<int>? rowid,
  }) {
    return ActivitiesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      usesControllers: usesControllers ?? this.usesControllers,
      usesGames: usesGames ?? this.usesGames,
      durationModel: durationModel ?? this.durationModel,
      legacyHappyHourEligible:
          legacyHappyHourEligible ?? this.legacyHappyHourEligible,
      sortOrder: sortOrder ?? this.sortOrder,
      active: active ?? this.active,
      overtimeGraceMinutes: overtimeGraceMinutes ?? this.overtimeGraceMinutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (usesControllers.present) {
      map['uses_controllers'] = Variable<bool>(usesControllers.value);
    }
    if (usesGames.present) {
      map['uses_games'] = Variable<bool>(usesGames.value);
    }
    if (durationModel.present) {
      map['duration_model'] = Variable<String>(durationModel.value);
    }
    if (legacyHappyHourEligible.present) {
      map['happy_hour_eligible'] = Variable<bool>(
        legacyHappyHourEligible.value,
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (overtimeGraceMinutes.present) {
      map['overtime_grace_minutes'] = Variable<int>(overtimeGraceMinutes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivitiesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('usesControllers: $usesControllers, ')
          ..write('usesGames: $usesGames, ')
          ..write('durationModel: $durationModel, ')
          ..write('legacyHappyHourEligible: $legacyHappyHourEligible, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('active: $active, ')
          ..write('overtimeGraceMinutes: $overtimeGraceMinutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ResourcesTable extends Resources
    with TableInfo<$ResourcesTable, ResourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('available'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentModeMeta = const VerificationMeta(
    'currentMode',
  );
  @override
  late final GeneratedColumn<String> currentMode = GeneratedColumn<String>(
    'current_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kind,
    status,
    sortOrder,
    currentMode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resources';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('current_mode')) {
      context.handle(
        _currentModeMeta,
        currentMode.isAcceptableOrUnknown(
          data['current_mode']!,
          _currentModeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ResourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      currentMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_mode'],
      ),
    );
  }

  @override
  $ResourcesTable createAlias(String alias) {
    return $ResourcesTable(attachedDatabase, alias);
  }
}

class ResourceRow extends DataClass implements Insertable<ResourceRow> {
  final String id;
  final String name;
  final String kind;
  final String status;
  final int sortOrder;

  /// For a dual-capability station (RIFT: PS5 *or* VR). Null = not mode-locked.
  /// When set to an activity code, only that activity may be allocated here.
  final String? currentMode;
  const ResourceRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.status,
    required this.sortOrder,
    this.currentMode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || currentMode != null) {
      map['current_mode'] = Variable<String>(currentMode);
    }
    return map;
  }

  ResourcesCompanion toCompanion(bool nullToAbsent) {
    return ResourcesCompanion(
      id: Value(id),
      name: Value(name),
      kind: Value(kind),
      status: Value(status),
      sortOrder: Value(sortOrder),
      currentMode: currentMode == null && nullToAbsent
          ? const Value.absent()
          : Value(currentMode),
    );
  }

  factory ResourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResourceRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      currentMode: serializer.fromJson<String?>(json['currentMode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'currentMode': serializer.toJson<String?>(currentMode),
    };
  }

  ResourceRow copyWith({
    String? id,
    String? name,
    String? kind,
    String? status,
    int? sortOrder,
    Value<String?> currentMode = const Value.absent(),
  }) => ResourceRow(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    sortOrder: sortOrder ?? this.sortOrder,
    currentMode: currentMode.present ? currentMode.value : this.currentMode,
  );
  ResourceRow copyWithCompanion(ResourcesCompanion data) {
    return ResourceRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      currentMode: data.currentMode.present
          ? data.currentMode.value
          : this.currentMode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResourceRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('currentMode: $currentMode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, kind, status, sortOrder, currentMode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.sortOrder == this.sortOrder &&
          other.currentMode == this.currentMode);
}

class ResourcesCompanion extends UpdateCompanion<ResourceRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> kind;
  final Value<String> status;
  final Value<int> sortOrder;
  final Value<String?> currentMode;
  final Value<int> rowid;
  const ResourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.currentMode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResourcesCompanion.insert({
    required String id,
    required String name,
    required String kind,
    this.status = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.currentMode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       kind = Value(kind);
  static Insertable<ResourceRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<int>? sortOrder,
    Expression<String>? currentMode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (currentMode != null) 'current_mode': currentMode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? kind,
    Value<String>? status,
    Value<int>? sortOrder,
    Value<String?>? currentMode,
    Value<int>? rowid,
  }) {
    return ResourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      currentMode: currentMode ?? this.currentMode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (currentMode.present) {
      map['current_mode'] = Variable<String>(currentMode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('currentMode: $currentMode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ResourceActivitiesTable extends ResourceActivities
    with TableInfo<$ResourceActivitiesTable, ResourceActivityRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResourceActivitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityCodeMeta = const VerificationMeta(
    'activityCode',
  );
  @override
  late final GeneratedColumn<String> activityCode = GeneratedColumn<String>(
    'activity_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [resourceId, activityCode];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resource_activities';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResourceActivityRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_resourceIdMeta);
    }
    if (data.containsKey('activity_code')) {
      context.handle(
        _activityCodeMeta,
        activityCode.isAcceptableOrUnknown(
          data['activity_code']!,
          _activityCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityCodeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {resourceId, activityCode};
  @override
  ResourceActivityRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResourceActivityRow(
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      )!,
      activityCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_code'],
      )!,
    );
  }

  @override
  $ResourceActivitiesTable createAlias(String alias) {
    return $ResourceActivitiesTable(attachedDatabase, alias);
  }
}

class ResourceActivityRow extends DataClass
    implements Insertable<ResourceActivityRow> {
  final String resourceId;
  final String activityCode;
  const ResourceActivityRow({
    required this.resourceId,
    required this.activityCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['resource_id'] = Variable<String>(resourceId);
    map['activity_code'] = Variable<String>(activityCode);
    return map;
  }

  ResourceActivitiesCompanion toCompanion(bool nullToAbsent) {
    return ResourceActivitiesCompanion(
      resourceId: Value(resourceId),
      activityCode: Value(activityCode),
    );
  }

  factory ResourceActivityRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResourceActivityRow(
      resourceId: serializer.fromJson<String>(json['resourceId']),
      activityCode: serializer.fromJson<String>(json['activityCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'resourceId': serializer.toJson<String>(resourceId),
      'activityCode': serializer.toJson<String>(activityCode),
    };
  }

  ResourceActivityRow copyWith({String? resourceId, String? activityCode}) =>
      ResourceActivityRow(
        resourceId: resourceId ?? this.resourceId,
        activityCode: activityCode ?? this.activityCode,
      );
  ResourceActivityRow copyWithCompanion(ResourceActivitiesCompanion data) {
    return ResourceActivityRow(
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
      activityCode: data.activityCode.present
          ? data.activityCode.value
          : this.activityCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResourceActivityRow(')
          ..write('resourceId: $resourceId, ')
          ..write('activityCode: $activityCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(resourceId, activityCode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceActivityRow &&
          other.resourceId == this.resourceId &&
          other.activityCode == this.activityCode);
}

class ResourceActivitiesCompanion extends UpdateCompanion<ResourceActivityRow> {
  final Value<String> resourceId;
  final Value<String> activityCode;
  final Value<int> rowid;
  const ResourceActivitiesCompanion({
    this.resourceId = const Value.absent(),
    this.activityCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResourceActivitiesCompanion.insert({
    required String resourceId,
    required String activityCode,
    this.rowid = const Value.absent(),
  }) : resourceId = Value(resourceId),
       activityCode = Value(activityCode);
  static Insertable<ResourceActivityRow> custom({
    Expression<String>? resourceId,
    Expression<String>? activityCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (resourceId != null) 'resource_id': resourceId,
      if (activityCode != null) 'activity_code': activityCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResourceActivitiesCompanion copyWith({
    Value<String>? resourceId,
    Value<String>? activityCode,
    Value<int>? rowid,
  }) {
    return ResourceActivitiesCompanion(
      resourceId: resourceId ?? this.resourceId,
      activityCode: activityCode ?? this.activityCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (activityCode.present) {
      map['activity_code'] = Variable<String>(activityCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResourceActivitiesCompanion(')
          ..write('resourceId: $resourceId, ')
          ..write('activityCode: $activityCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ControllersTable extends Controllers
    with TableInfo<$ControllersTable, ControllerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ControllersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeResourceIdMeta = const VerificationMeta(
    'homeResourceId',
  );
  @override
  late final GeneratedColumn<String> homeResourceId = GeneratedColumn<String>(
    'home_resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentResourceIdMeta = const VerificationMeta(
    'currentResourceId',
  );
  @override
  late final GeneratedColumn<String> currentResourceId =
      GeneratedColumn<String>(
        'current_resource_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('usable'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loanReturnToMeta = const VerificationMeta(
    'loanReturnTo',
  );
  @override
  late final GeneratedColumn<String> loanReturnTo = GeneratedColumn<String>(
    'loan_return_to',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loanSessionRefMeta = const VerificationMeta(
    'loanSessionRef',
  );
  @override
  late final GeneratedColumn<String> loanSessionRef = GeneratedColumn<String>(
    'loan_session_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    homeResourceId,
    currentResourceId,
    status,
    notes,
    loanReturnTo,
    loanSessionRef,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'controllers';
  @override
  VerificationContext validateIntegrity(
    Insertable<ControllerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('home_resource_id')) {
      context.handle(
        _homeResourceIdMeta,
        homeResourceId.isAcceptableOrUnknown(
          data['home_resource_id']!,
          _homeResourceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_homeResourceIdMeta);
    }
    if (data.containsKey('current_resource_id')) {
      context.handle(
        _currentResourceIdMeta,
        currentResourceId.isAcceptableOrUnknown(
          data['current_resource_id']!,
          _currentResourceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentResourceIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('loan_return_to')) {
      context.handle(
        _loanReturnToMeta,
        loanReturnTo.isAcceptableOrUnknown(
          data['loan_return_to']!,
          _loanReturnToMeta,
        ),
      );
    }
    if (data.containsKey('loan_session_ref')) {
      context.handle(
        _loanSessionRefMeta,
        loanSessionRef.isAcceptableOrUnknown(
          data['loan_session_ref']!,
          _loanSessionRefMeta,
        ),
      );
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
  ControllerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ControllerRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      homeResourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_resource_id'],
      )!,
      currentResourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_resource_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      loanReturnTo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loan_return_to'],
      ),
      loanSessionRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}loan_session_ref'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ControllersTable createAlias(String alias) {
    return $ControllersTable(attachedDatabase, alias);
  }
}

class ControllerRow extends DataClass implements Insertable<ControllerRow> {
  final String id;
  final String label;
  final String homeResourceId;
  final String currentResourceId;
  final String status;
  final String? notes;

  /// Set while on loan: where to return it, and which session owes the return
  /// (`s:<sessionId>`). Both null for a permanent move.
  final String? loanReturnTo;
  final String? loanSessionRef;
  final DateTime updatedAt;
  const ControllerRow({
    required this.id,
    required this.label,
    required this.homeResourceId,
    required this.currentResourceId,
    required this.status,
    this.notes,
    this.loanReturnTo,
    this.loanSessionRef,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['home_resource_id'] = Variable<String>(homeResourceId);
    map['current_resource_id'] = Variable<String>(currentResourceId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || loanReturnTo != null) {
      map['loan_return_to'] = Variable<String>(loanReturnTo);
    }
    if (!nullToAbsent || loanSessionRef != null) {
      map['loan_session_ref'] = Variable<String>(loanSessionRef);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ControllersCompanion toCompanion(bool nullToAbsent) {
    return ControllersCompanion(
      id: Value(id),
      label: Value(label),
      homeResourceId: Value(homeResourceId),
      currentResourceId: Value(currentResourceId),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      loanReturnTo: loanReturnTo == null && nullToAbsent
          ? const Value.absent()
          : Value(loanReturnTo),
      loanSessionRef: loanSessionRef == null && nullToAbsent
          ? const Value.absent()
          : Value(loanSessionRef),
      updatedAt: Value(updatedAt),
    );
  }

  factory ControllerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ControllerRow(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      homeResourceId: serializer.fromJson<String>(json['homeResourceId']),
      currentResourceId: serializer.fromJson<String>(json['currentResourceId']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      loanReturnTo: serializer.fromJson<String?>(json['loanReturnTo']),
      loanSessionRef: serializer.fromJson<String?>(json['loanSessionRef']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'homeResourceId': serializer.toJson<String>(homeResourceId),
      'currentResourceId': serializer.toJson<String>(currentResourceId),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'loanReturnTo': serializer.toJson<String?>(loanReturnTo),
      'loanSessionRef': serializer.toJson<String?>(loanSessionRef),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ControllerRow copyWith({
    String? id,
    String? label,
    String? homeResourceId,
    String? currentResourceId,
    String? status,
    Value<String?> notes = const Value.absent(),
    Value<String?> loanReturnTo = const Value.absent(),
    Value<String?> loanSessionRef = const Value.absent(),
    DateTime? updatedAt,
  }) => ControllerRow(
    id: id ?? this.id,
    label: label ?? this.label,
    homeResourceId: homeResourceId ?? this.homeResourceId,
    currentResourceId: currentResourceId ?? this.currentResourceId,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    loanReturnTo: loanReturnTo.present ? loanReturnTo.value : this.loanReturnTo,
    loanSessionRef: loanSessionRef.present
        ? loanSessionRef.value
        : this.loanSessionRef,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ControllerRow copyWithCompanion(ControllersCompanion data) {
    return ControllerRow(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      homeResourceId: data.homeResourceId.present
          ? data.homeResourceId.value
          : this.homeResourceId,
      currentResourceId: data.currentResourceId.present
          ? data.currentResourceId.value
          : this.currentResourceId,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      loanReturnTo: data.loanReturnTo.present
          ? data.loanReturnTo.value
          : this.loanReturnTo,
      loanSessionRef: data.loanSessionRef.present
          ? data.loanSessionRef.value
          : this.loanSessionRef,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ControllerRow(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('homeResourceId: $homeResourceId, ')
          ..write('currentResourceId: $currentResourceId, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('loanReturnTo: $loanReturnTo, ')
          ..write('loanSessionRef: $loanSessionRef, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    homeResourceId,
    currentResourceId,
    status,
    notes,
    loanReturnTo,
    loanSessionRef,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ControllerRow &&
          other.id == this.id &&
          other.label == this.label &&
          other.homeResourceId == this.homeResourceId &&
          other.currentResourceId == this.currentResourceId &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.loanReturnTo == this.loanReturnTo &&
          other.loanSessionRef == this.loanSessionRef &&
          other.updatedAt == this.updatedAt);
}

class ControllersCompanion extends UpdateCompanion<ControllerRow> {
  final Value<String> id;
  final Value<String> label;
  final Value<String> homeResourceId;
  final Value<String> currentResourceId;
  final Value<String> status;
  final Value<String?> notes;
  final Value<String?> loanReturnTo;
  final Value<String?> loanSessionRef;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ControllersCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.homeResourceId = const Value.absent(),
    this.currentResourceId = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.loanReturnTo = const Value.absent(),
    this.loanSessionRef = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ControllersCompanion.insert({
    required String id,
    required String label,
    required String homeResourceId,
    required String currentResourceId,
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.loanReturnTo = const Value.absent(),
    this.loanSessionRef = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       homeResourceId = Value(homeResourceId),
       currentResourceId = Value(currentResourceId),
       updatedAt = Value(updatedAt);
  static Insertable<ControllerRow> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<String>? homeResourceId,
    Expression<String>? currentResourceId,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<String>? loanReturnTo,
    Expression<String>? loanSessionRef,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (homeResourceId != null) 'home_resource_id': homeResourceId,
      if (currentResourceId != null) 'current_resource_id': currentResourceId,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (loanReturnTo != null) 'loan_return_to': loanReturnTo,
      if (loanSessionRef != null) 'loan_session_ref': loanSessionRef,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ControllersCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<String>? homeResourceId,
    Value<String>? currentResourceId,
    Value<String>? status,
    Value<String?>? notes,
    Value<String?>? loanReturnTo,
    Value<String?>? loanSessionRef,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ControllersCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      homeResourceId: homeResourceId ?? this.homeResourceId,
      currentResourceId: currentResourceId ?? this.currentResourceId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      loanReturnTo: loanReturnTo ?? this.loanReturnTo,
      loanSessionRef: loanSessionRef ?? this.loanSessionRef,
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
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (homeResourceId.present) {
      map['home_resource_id'] = Variable<String>(homeResourceId.value);
    }
    if (currentResourceId.present) {
      map['current_resource_id'] = Variable<String>(currentResourceId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (loanReturnTo.present) {
      map['loan_return_to'] = Variable<String>(loanReturnTo.value);
    }
    if (loanSessionRef.present) {
      map['loan_session_ref'] = Variable<String>(loanSessionRef.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ControllersCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('homeResourceId: $homeResourceId, ')
          ..write('currentResourceId: $currentResourceId, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('loanReturnTo: $loanReturnTo, ')
          ..write('loanSessionRef: $loanSessionRef, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ControllerAllocationsTable extends ControllerAllocations
    with TableInfo<$ControllerAllocationsTable, ControllerAllocationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ControllerAllocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _controllerIdMeta = const VerificationMeta(
    'controllerId',
  );
  @override
  late final GeneratedColumn<String> controllerId = GeneratedColumn<String>(
    'controller_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<String> segmentId = GeneratedColumn<String>(
    'segment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityCodeMeta = const VerificationMeta(
    'activityCode',
  );
  @override
  late final GeneratedColumn<String> activityCode = GeneratedColumn<String>(
    'activity_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    controllerId,
    scope,
    sessionId,
    segmentId,
    resourceId,
    activityCode,
    gameId,
    startedAt,
    endedAt,
    requestId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'controller_allocations';
  @override
  VerificationContext validateIntegrity(
    Insertable<ControllerAllocationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('controller_id')) {
      context.handle(
        _controllerIdMeta,
        controllerId.isAcceptableOrUnknown(
          data['controller_id']!,
          _controllerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_controllerIdMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    }
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_resourceIdMeta);
    }
    if (data.containsKey('activity_code')) {
      context.handle(
        _activityCodeMeta,
        activityCode.isAcceptableOrUnknown(
          data['activity_code']!,
          _activityCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityCodeMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ControllerAllocationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ControllerAllocationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      controllerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}controller_id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_id'],
      ),
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      )!,
      activityCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_code'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ControllerAllocationsTable createAlias(String alias) {
    return $ControllerAllocationsTable(attachedDatabase, alias);
  }
}

class ControllerAllocationRow extends DataClass
    implements Insertable<ControllerAllocationRow> {
  final String id;
  final String controllerId;
  final String scope;
  final String? sessionId;
  final String? segmentId;
  final String resourceId;
  final String activityCode;
  final String? gameId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? requestId;
  final DateTime createdAt;
  const ControllerAllocationRow({
    required this.id,
    required this.controllerId,
    required this.scope,
    this.sessionId,
    this.segmentId,
    required this.resourceId,
    required this.activityCode,
    this.gameId,
    required this.startedAt,
    this.endedAt,
    this.requestId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['controller_id'] = Variable<String>(controllerId);
    map['scope'] = Variable<String>(scope);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    if (!nullToAbsent || segmentId != null) {
      map['segment_id'] = Variable<String>(segmentId);
    }
    map['resource_id'] = Variable<String>(resourceId);
    map['activity_code'] = Variable<String>(activityCode);
    if (!nullToAbsent || gameId != null) {
      map['game_id'] = Variable<String>(gameId);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || requestId != null) {
      map['request_id'] = Variable<String>(requestId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ControllerAllocationsCompanion toCompanion(bool nullToAbsent) {
    return ControllerAllocationsCompanion(
      id: Value(id),
      controllerId: Value(controllerId),
      scope: Value(scope),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      segmentId: segmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(segmentId),
      resourceId: Value(resourceId),
      activityCode: Value(activityCode),
      gameId: gameId == null && nullToAbsent
          ? const Value.absent()
          : Value(gameId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      requestId: requestId == null && nullToAbsent
          ? const Value.absent()
          : Value(requestId),
      createdAt: Value(createdAt),
    );
  }

  factory ControllerAllocationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ControllerAllocationRow(
      id: serializer.fromJson<String>(json['id']),
      controllerId: serializer.fromJson<String>(json['controllerId']),
      scope: serializer.fromJson<String>(json['scope']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      segmentId: serializer.fromJson<String?>(json['segmentId']),
      resourceId: serializer.fromJson<String>(json['resourceId']),
      activityCode: serializer.fromJson<String>(json['activityCode']),
      gameId: serializer.fromJson<String?>(json['gameId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      requestId: serializer.fromJson<String?>(json['requestId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'controllerId': serializer.toJson<String>(controllerId),
      'scope': serializer.toJson<String>(scope),
      'sessionId': serializer.toJson<String?>(sessionId),
      'segmentId': serializer.toJson<String?>(segmentId),
      'resourceId': serializer.toJson<String>(resourceId),
      'activityCode': serializer.toJson<String>(activityCode),
      'gameId': serializer.toJson<String?>(gameId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'requestId': serializer.toJson<String?>(requestId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ControllerAllocationRow copyWith({
    String? id,
    String? controllerId,
    String? scope,
    Value<String?> sessionId = const Value.absent(),
    Value<String?> segmentId = const Value.absent(),
    String? resourceId,
    String? activityCode,
    Value<String?> gameId = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<String?> requestId = const Value.absent(),
    DateTime? createdAt,
  }) => ControllerAllocationRow(
    id: id ?? this.id,
    controllerId: controllerId ?? this.controllerId,
    scope: scope ?? this.scope,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    segmentId: segmentId.present ? segmentId.value : this.segmentId,
    resourceId: resourceId ?? this.resourceId,
    activityCode: activityCode ?? this.activityCode,
    gameId: gameId.present ? gameId.value : this.gameId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    requestId: requestId.present ? requestId.value : this.requestId,
    createdAt: createdAt ?? this.createdAt,
  );
  ControllerAllocationRow copyWithCompanion(
    ControllerAllocationsCompanion data,
  ) {
    return ControllerAllocationRow(
      id: data.id.present ? data.id.value : this.id,
      controllerId: data.controllerId.present
          ? data.controllerId.value
          : this.controllerId,
      scope: data.scope.present ? data.scope.value : this.scope,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
      activityCode: data.activityCode.present
          ? data.activityCode.value
          : this.activityCode,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ControllerAllocationRow(')
          ..write('id: $id, ')
          ..write('controllerId: $controllerId, ')
          ..write('scope: $scope, ')
          ..write('sessionId: $sessionId, ')
          ..write('segmentId: $segmentId, ')
          ..write('resourceId: $resourceId, ')
          ..write('activityCode: $activityCode, ')
          ..write('gameId: $gameId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('requestId: $requestId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    controllerId,
    scope,
    sessionId,
    segmentId,
    resourceId,
    activityCode,
    gameId,
    startedAt,
    endedAt,
    requestId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ControllerAllocationRow &&
          other.id == this.id &&
          other.controllerId == this.controllerId &&
          other.scope == this.scope &&
          other.sessionId == this.sessionId &&
          other.segmentId == this.segmentId &&
          other.resourceId == this.resourceId &&
          other.activityCode == this.activityCode &&
          other.gameId == this.gameId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.requestId == this.requestId &&
          other.createdAt == this.createdAt);
}

class ControllerAllocationsCompanion
    extends UpdateCompanion<ControllerAllocationRow> {
  final Value<String> id;
  final Value<String> controllerId;
  final Value<String> scope;
  final Value<String?> sessionId;
  final Value<String?> segmentId;
  final Value<String> resourceId;
  final Value<String> activityCode;
  final Value<String?> gameId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String?> requestId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ControllerAllocationsCompanion({
    this.id = const Value.absent(),
    this.controllerId = const Value.absent(),
    this.scope = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.segmentId = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.activityCode = const Value.absent(),
    this.gameId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.requestId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ControllerAllocationsCompanion.insert({
    required String id,
    required String controllerId,
    required String scope,
    this.sessionId = const Value.absent(),
    this.segmentId = const Value.absent(),
    required String resourceId,
    required String activityCode,
    this.gameId = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.requestId = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       controllerId = Value(controllerId),
       scope = Value(scope),
       resourceId = Value(resourceId),
       activityCode = Value(activityCode),
       startedAt = Value(startedAt),
       createdAt = Value(createdAt);
  static Insertable<ControllerAllocationRow> custom({
    Expression<String>? id,
    Expression<String>? controllerId,
    Expression<String>? scope,
    Expression<String>? sessionId,
    Expression<String>? segmentId,
    Expression<String>? resourceId,
    Expression<String>? activityCode,
    Expression<String>? gameId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? requestId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (controllerId != null) 'controller_id': controllerId,
      if (scope != null) 'scope': scope,
      if (sessionId != null) 'session_id': sessionId,
      if (segmentId != null) 'segment_id': segmentId,
      if (resourceId != null) 'resource_id': resourceId,
      if (activityCode != null) 'activity_code': activityCode,
      if (gameId != null) 'game_id': gameId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (requestId != null) 'request_id': requestId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ControllerAllocationsCompanion copyWith({
    Value<String>? id,
    Value<String>? controllerId,
    Value<String>? scope,
    Value<String?>? sessionId,
    Value<String?>? segmentId,
    Value<String>? resourceId,
    Value<String>? activityCode,
    Value<String?>? gameId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<String?>? requestId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ControllerAllocationsCompanion(
      id: id ?? this.id,
      controllerId: controllerId ?? this.controllerId,
      scope: scope ?? this.scope,
      sessionId: sessionId ?? this.sessionId,
      segmentId: segmentId ?? this.segmentId,
      resourceId: resourceId ?? this.resourceId,
      activityCode: activityCode ?? this.activityCode,
      gameId: gameId ?? this.gameId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      requestId: requestId ?? this.requestId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (controllerId.present) {
      map['controller_id'] = Variable<String>(controllerId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<String>(segmentId.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (activityCode.present) {
      map['activity_code'] = Variable<String>(activityCode.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ControllerAllocationsCompanion(')
          ..write('id: $id, ')
          ..write('controllerId: $controllerId, ')
          ..write('scope: $scope, ')
          ..write('sessionId: $sessionId, ')
          ..write('segmentId: $segmentId, ')
          ..write('resourceId: $resourceId, ')
          ..write('activityCode: $activityCode, ')
          ..write('gameId: $gameId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('requestId: $requestId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ControllerMovesTable extends ControllerMoves
    with TableInfo<$ControllerMovesTable, ControllerMoveRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ControllerMovesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _controllerIdMeta = const VerificationMeta(
    'controllerId',
  );
  @override
  late final GeneratedColumn<String> controllerId = GeneratedColumn<String>(
    'controller_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromResourceIdMeta = const VerificationMeta(
    'fromResourceId',
  );
  @override
  late final GeneratedColumn<String> fromResourceId = GeneratedColumn<String>(
    'from_resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toResourceIdMeta = const VerificationMeta(
    'toResourceId',
  );
  @override
  late final GeneratedColumn<String> toResourceId = GeneratedColumn<String>(
    'to_resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionRefMeta = const VerificationMeta(
    'sessionRef',
  );
  @override
  late final GeneratedColumn<String> sessionRef = GeneratedColumn<String>(
    'session_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _movedAtMeta = const VerificationMeta(
    'movedAt',
  );
  @override
  late final GeneratedColumn<DateTime> movedAt = GeneratedColumn<DateTime>(
    'moved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    controllerId,
    fromResourceId,
    toResourceId,
    kind,
    sessionRef,
    movedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'controller_moves';
  @override
  VerificationContext validateIntegrity(
    Insertable<ControllerMoveRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('controller_id')) {
      context.handle(
        _controllerIdMeta,
        controllerId.isAcceptableOrUnknown(
          data['controller_id']!,
          _controllerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_controllerIdMeta);
    }
    if (data.containsKey('from_resource_id')) {
      context.handle(
        _fromResourceIdMeta,
        fromResourceId.isAcceptableOrUnknown(
          data['from_resource_id']!,
          _fromResourceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromResourceIdMeta);
    }
    if (data.containsKey('to_resource_id')) {
      context.handle(
        _toResourceIdMeta,
        toResourceId.isAcceptableOrUnknown(
          data['to_resource_id']!,
          _toResourceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toResourceIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('session_ref')) {
      context.handle(
        _sessionRefMeta,
        sessionRef.isAcceptableOrUnknown(data['session_ref']!, _sessionRefMeta),
      );
    }
    if (data.containsKey('moved_at')) {
      context.handle(
        _movedAtMeta,
        movedAt.isAcceptableOrUnknown(data['moved_at']!, _movedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_movedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ControllerMoveRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ControllerMoveRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      controllerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}controller_id'],
      )!,
      fromResourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_resource_id'],
      )!,
      toResourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_resource_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      sessionRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_ref'],
      ),
      movedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}moved_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ControllerMovesTable createAlias(String alias) {
    return $ControllerMovesTable(attachedDatabase, alias);
  }
}

class ControllerMoveRow extends DataClass
    implements Insertable<ControllerMoveRow> {
  final String id;
  final String controllerId;
  final String fromResourceId;
  final String toResourceId;
  final String kind;
  final String? sessionRef;
  final DateTime movedAt;
  final DateTime createdAt;
  const ControllerMoveRow({
    required this.id,
    required this.controllerId,
    required this.fromResourceId,
    required this.toResourceId,
    required this.kind,
    this.sessionRef,
    required this.movedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['controller_id'] = Variable<String>(controllerId);
    map['from_resource_id'] = Variable<String>(fromResourceId);
    map['to_resource_id'] = Variable<String>(toResourceId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || sessionRef != null) {
      map['session_ref'] = Variable<String>(sessionRef);
    }
    map['moved_at'] = Variable<DateTime>(movedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ControllerMovesCompanion toCompanion(bool nullToAbsent) {
    return ControllerMovesCompanion(
      id: Value(id),
      controllerId: Value(controllerId),
      fromResourceId: Value(fromResourceId),
      toResourceId: Value(toResourceId),
      kind: Value(kind),
      sessionRef: sessionRef == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionRef),
      movedAt: Value(movedAt),
      createdAt: Value(createdAt),
    );
  }

  factory ControllerMoveRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ControllerMoveRow(
      id: serializer.fromJson<String>(json['id']),
      controllerId: serializer.fromJson<String>(json['controllerId']),
      fromResourceId: serializer.fromJson<String>(json['fromResourceId']),
      toResourceId: serializer.fromJson<String>(json['toResourceId']),
      kind: serializer.fromJson<String>(json['kind']),
      sessionRef: serializer.fromJson<String?>(json['sessionRef']),
      movedAt: serializer.fromJson<DateTime>(json['movedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'controllerId': serializer.toJson<String>(controllerId),
      'fromResourceId': serializer.toJson<String>(fromResourceId),
      'toResourceId': serializer.toJson<String>(toResourceId),
      'kind': serializer.toJson<String>(kind),
      'sessionRef': serializer.toJson<String?>(sessionRef),
      'movedAt': serializer.toJson<DateTime>(movedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ControllerMoveRow copyWith({
    String? id,
    String? controllerId,
    String? fromResourceId,
    String? toResourceId,
    String? kind,
    Value<String?> sessionRef = const Value.absent(),
    DateTime? movedAt,
    DateTime? createdAt,
  }) => ControllerMoveRow(
    id: id ?? this.id,
    controllerId: controllerId ?? this.controllerId,
    fromResourceId: fromResourceId ?? this.fromResourceId,
    toResourceId: toResourceId ?? this.toResourceId,
    kind: kind ?? this.kind,
    sessionRef: sessionRef.present ? sessionRef.value : this.sessionRef,
    movedAt: movedAt ?? this.movedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ControllerMoveRow copyWithCompanion(ControllerMovesCompanion data) {
    return ControllerMoveRow(
      id: data.id.present ? data.id.value : this.id,
      controllerId: data.controllerId.present
          ? data.controllerId.value
          : this.controllerId,
      fromResourceId: data.fromResourceId.present
          ? data.fromResourceId.value
          : this.fromResourceId,
      toResourceId: data.toResourceId.present
          ? data.toResourceId.value
          : this.toResourceId,
      kind: data.kind.present ? data.kind.value : this.kind,
      sessionRef: data.sessionRef.present
          ? data.sessionRef.value
          : this.sessionRef,
      movedAt: data.movedAt.present ? data.movedAt.value : this.movedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ControllerMoveRow(')
          ..write('id: $id, ')
          ..write('controllerId: $controllerId, ')
          ..write('fromResourceId: $fromResourceId, ')
          ..write('toResourceId: $toResourceId, ')
          ..write('kind: $kind, ')
          ..write('sessionRef: $sessionRef, ')
          ..write('movedAt: $movedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    controllerId,
    fromResourceId,
    toResourceId,
    kind,
    sessionRef,
    movedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ControllerMoveRow &&
          other.id == this.id &&
          other.controllerId == this.controllerId &&
          other.fromResourceId == this.fromResourceId &&
          other.toResourceId == this.toResourceId &&
          other.kind == this.kind &&
          other.sessionRef == this.sessionRef &&
          other.movedAt == this.movedAt &&
          other.createdAt == this.createdAt);
}

class ControllerMovesCompanion extends UpdateCompanion<ControllerMoveRow> {
  final Value<String> id;
  final Value<String> controllerId;
  final Value<String> fromResourceId;
  final Value<String> toResourceId;
  final Value<String> kind;
  final Value<String?> sessionRef;
  final Value<DateTime> movedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ControllerMovesCompanion({
    this.id = const Value.absent(),
    this.controllerId = const Value.absent(),
    this.fromResourceId = const Value.absent(),
    this.toResourceId = const Value.absent(),
    this.kind = const Value.absent(),
    this.sessionRef = const Value.absent(),
    this.movedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ControllerMovesCompanion.insert({
    required String id,
    required String controllerId,
    required String fromResourceId,
    required String toResourceId,
    required String kind,
    this.sessionRef = const Value.absent(),
    required DateTime movedAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       controllerId = Value(controllerId),
       fromResourceId = Value(fromResourceId),
       toResourceId = Value(toResourceId),
       kind = Value(kind),
       movedAt = Value(movedAt),
       createdAt = Value(createdAt);
  static Insertable<ControllerMoveRow> custom({
    Expression<String>? id,
    Expression<String>? controllerId,
    Expression<String>? fromResourceId,
    Expression<String>? toResourceId,
    Expression<String>? kind,
    Expression<String>? sessionRef,
    Expression<DateTime>? movedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (controllerId != null) 'controller_id': controllerId,
      if (fromResourceId != null) 'from_resource_id': fromResourceId,
      if (toResourceId != null) 'to_resource_id': toResourceId,
      if (kind != null) 'kind': kind,
      if (sessionRef != null) 'session_ref': sessionRef,
      if (movedAt != null) 'moved_at': movedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ControllerMovesCompanion copyWith({
    Value<String>? id,
    Value<String>? controllerId,
    Value<String>? fromResourceId,
    Value<String>? toResourceId,
    Value<String>? kind,
    Value<String?>? sessionRef,
    Value<DateTime>? movedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ControllerMovesCompanion(
      id: id ?? this.id,
      controllerId: controllerId ?? this.controllerId,
      fromResourceId: fromResourceId ?? this.fromResourceId,
      toResourceId: toResourceId ?? this.toResourceId,
      kind: kind ?? this.kind,
      sessionRef: sessionRef ?? this.sessionRef,
      movedAt: movedAt ?? this.movedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (controllerId.present) {
      map['controller_id'] = Variable<String>(controllerId.value);
    }
    if (fromResourceId.present) {
      map['from_resource_id'] = Variable<String>(fromResourceId.value);
    }
    if (toResourceId.present) {
      map['to_resource_id'] = Variable<String>(toResourceId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sessionRef.present) {
      map['session_ref'] = Variable<String>(sessionRef.value);
    }
    if (movedAt.present) {
      map['moved_at'] = Variable<DateTime>(movedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ControllerMovesCompanion(')
          ..write('id: $id, ')
          ..write('controllerId: $controllerId, ')
          ..write('fromResourceId: $fromResourceId, ')
          ..write('toResourceId: $toResourceId, ')
          ..write('kind: $kind, ')
          ..write('sessionRef: $sessionRef, ')
          ..write('movedAt: $movedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GameCategoriesTable extends GameCategories
    with TableInfo<$GameCategoriesTable, GameCategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameCategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameCategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameCategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $GameCategoriesTable createAlias(String alias) {
    return $GameCategoriesTable(attachedDatabase, alias);
  }
}

class GameCategoryRow extends DataClass implements Insertable<GameCategoryRow> {
  final String id;
  final String name;
  final int sortOrder;
  const GameCategoryRow({
    required this.id,
    required this.name,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  GameCategoriesCompanion toCompanion(bool nullToAbsent) {
    return GameCategoriesCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
    );
  }

  factory GameCategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameCategoryRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  GameCategoryRow copyWith({String? id, String? name, int? sortOrder}) =>
      GameCategoryRow(
        id: id ?? this.id,
        name: name ?? this.name,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  GameCategoryRow copyWithCompanion(GameCategoriesCompanion data) {
    return GameCategoryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameCategoryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameCategoryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class GameCategoriesCompanion extends UpdateCompanion<GameCategoryRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const GameCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GameCategoriesCompanion.insert({
    required String id,
    required String name,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<GameCategoryRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GameCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return GameCategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GamesTable extends Games with TableInfo<$GamesTable, GameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> aliases =
      GeneratedColumn<String>(
        'aliases',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>($GamesTable.$converteraliases);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> platforms =
      GeneratedColumn<String>(
        'platforms',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>($GamesTable.$converterplatforms);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> playModes =
      GeneratedColumn<String>(
        'play_modes',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('["single"]'),
      ).withConverter<List<String>>($GamesTable.$converterplayModes);
  static const VerificationMeta _maxLocalPlayersMeta = const VerificationMeta(
    'maxLocalPlayers',
  );
  @override
  late final GeneratedColumn<int> maxLocalPlayers = GeneratedColumn<int>(
    'max_local_players',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    aliases,
    categoryId,
    platforms,
    playModes,
    maxLocalPlayers,
    active,
    lastPlayedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'games';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('max_local_players')) {
      context.handle(
        _maxLocalPlayersMeta,
        maxLocalPlayers.isAcceptableOrUnknown(
          data['max_local_players']!,
          _maxLocalPlayersMeta,
        ),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      aliases: $GamesTable.$converteraliases.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}aliases'],
        )!,
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      platforms: $GamesTable.$converterplatforms.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}platforms'],
        )!,
      ),
      playModes: $GamesTable.$converterplayModes.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}play_modes'],
        )!,
      ),
      maxLocalPlayers: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_local_players'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
    );
  }

  @override
  $GamesTable createAlias(String alias) {
    return $GamesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converteraliases =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterplatforms =
      const StringListConverter();
  static TypeConverter<List<String>, String> $converterplayModes =
      const StringListConverter();
}

class GameRow extends DataClass implements Insertable<GameRow> {
  final String id;
  final String name;
  final List<String> aliases;
  final String? categoryId;
  final List<String> platforms;

  /// [PlayerMode] codes, one or more (server games.play_modes).
  final List<String> playModes;
  final int maxLocalPlayers;
  final bool active;
  final DateTime? lastPlayedAt;
  const GameRow({
    required this.id,
    required this.name,
    required this.aliases,
    this.categoryId,
    required this.platforms,
    required this.playModes,
    required this.maxLocalPlayers,
    required this.active,
    this.lastPlayedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['aliases'] = Variable<String>(
        $GamesTable.$converteraliases.toSql(aliases),
      );
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    {
      map['platforms'] = Variable<String>(
        $GamesTable.$converterplatforms.toSql(platforms),
      );
    }
    {
      map['play_modes'] = Variable<String>(
        $GamesTable.$converterplayModes.toSql(playModes),
      );
    }
    map['max_local_players'] = Variable<int>(maxLocalPlayers);
    map['active'] = Variable<bool>(active);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    return map;
  }

  GamesCompanion toCompanion(bool nullToAbsent) {
    return GamesCompanion(
      id: Value(id),
      name: Value(name),
      aliases: Value(aliases),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      platforms: Value(platforms),
      playModes: Value(playModes),
      maxLocalPlayers: Value(maxLocalPlayers),
      active: Value(active),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
    );
  }

  factory GameRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      aliases: serializer.fromJson<List<String>>(json['aliases']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      platforms: serializer.fromJson<List<String>>(json['platforms']),
      playModes: serializer.fromJson<List<String>>(json['playModes']),
      maxLocalPlayers: serializer.fromJson<int>(json['maxLocalPlayers']),
      active: serializer.fromJson<bool>(json['active']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'aliases': serializer.toJson<List<String>>(aliases),
      'categoryId': serializer.toJson<String?>(categoryId),
      'platforms': serializer.toJson<List<String>>(platforms),
      'playModes': serializer.toJson<List<String>>(playModes),
      'maxLocalPlayers': serializer.toJson<int>(maxLocalPlayers),
      'active': serializer.toJson<bool>(active),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
    };
  }

  GameRow copyWith({
    String? id,
    String? name,
    List<String>? aliases,
    Value<String?> categoryId = const Value.absent(),
    List<String>? platforms,
    List<String>? playModes,
    int? maxLocalPlayers,
    bool? active,
    Value<DateTime?> lastPlayedAt = const Value.absent(),
  }) => GameRow(
    id: id ?? this.id,
    name: name ?? this.name,
    aliases: aliases ?? this.aliases,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    platforms: platforms ?? this.platforms,
    playModes: playModes ?? this.playModes,
    maxLocalPlayers: maxLocalPlayers ?? this.maxLocalPlayers,
    active: active ?? this.active,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
  );
  GameRow copyWithCompanion(GamesCompanion data) {
    return GameRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      aliases: data.aliases.present ? data.aliases.value : this.aliases,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      platforms: data.platforms.present ? data.platforms.value : this.platforms,
      playModes: data.playModes.present ? data.playModes.value : this.playModes,
      maxLocalPlayers: data.maxLocalPlayers.present
          ? data.maxLocalPlayers.value
          : this.maxLocalPlayers,
      active: data.active.present ? data.active.value : this.active,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('aliases: $aliases, ')
          ..write('categoryId: $categoryId, ')
          ..write('platforms: $platforms, ')
          ..write('playModes: $playModes, ')
          ..write('maxLocalPlayers: $maxLocalPlayers, ')
          ..write('active: $active, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    aliases,
    categoryId,
    platforms,
    playModes,
    maxLocalPlayers,
    active,
    lastPlayedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.aliases == this.aliases &&
          other.categoryId == this.categoryId &&
          other.platforms == this.platforms &&
          other.playModes == this.playModes &&
          other.maxLocalPlayers == this.maxLocalPlayers &&
          other.active == this.active &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class GamesCompanion extends UpdateCompanion<GameRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<List<String>> aliases;
  final Value<String?> categoryId;
  final Value<List<String>> platforms;
  final Value<List<String>> playModes;
  final Value<int> maxLocalPlayers;
  final Value<bool> active;
  final Value<DateTime?> lastPlayedAt;
  final Value<int> rowid;
  const GamesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.aliases = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.platforms = const Value.absent(),
    this.playModes = const Value.absent(),
    this.maxLocalPlayers = const Value.absent(),
    this.active = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GamesCompanion.insert({
    required String id,
    required String name,
    required List<String> aliases,
    this.categoryId = const Value.absent(),
    required List<String> platforms,
    this.playModes = const Value.absent(),
    this.maxLocalPlayers = const Value.absent(),
    this.active = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       aliases = Value(aliases),
       platforms = Value(platforms);
  static Insertable<GameRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? aliases,
    Expression<String>? categoryId,
    Expression<String>? platforms,
    Expression<String>? playModes,
    Expression<int>? maxLocalPlayers,
    Expression<bool>? active,
    Expression<DateTime>? lastPlayedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (aliases != null) 'aliases': aliases,
      if (categoryId != null) 'category_id': categoryId,
      if (platforms != null) 'platforms': platforms,
      if (playModes != null) 'play_modes': playModes,
      if (maxLocalPlayers != null) 'max_local_players': maxLocalPlayers,
      if (active != null) 'active': active,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GamesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<List<String>>? aliases,
    Value<String?>? categoryId,
    Value<List<String>>? platforms,
    Value<List<String>>? playModes,
    Value<int>? maxLocalPlayers,
    Value<bool>? active,
    Value<DateTime?>? lastPlayedAt,
    Value<int>? rowid,
  }) {
    return GamesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      aliases: aliases ?? this.aliases,
      categoryId: categoryId ?? this.categoryId,
      platforms: platforms ?? this.platforms,
      playModes: playModes ?? this.playModes,
      maxLocalPlayers: maxLocalPlayers ?? this.maxLocalPlayers,
      active: active ?? this.active,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (aliases.present) {
      map['aliases'] = Variable<String>(
        $GamesTable.$converteraliases.toSql(aliases.value),
      );
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (platforms.present) {
      map['platforms'] = Variable<String>(
        $GamesTable.$converterplatforms.toSql(platforms.value),
      );
    }
    if (playModes.present) {
      map['play_modes'] = Variable<String>(
        $GamesTable.$converterplayModes.toSql(playModes.value),
      );
    }
    if (maxLocalPlayers.present) {
      map['max_local_players'] = Variable<int>(maxLocalPlayers.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('aliases: $aliases, ')
          ..write('categoryId: $categoryId, ')
          ..write('platforms: $platforms, ')
          ..write('playModes: $playModes, ')
          ..write('maxLocalPlayers: $maxLocalPlayers, ')
          ..write('active: $active, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GameResourcesTable extends GameResources
    with TableInfo<$GameResourcesTable, GameResourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameResourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gameId,
    resourceId,
    status,
    notes,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_resources';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameResourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_resourceIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gameId, resourceId};
  @override
  GameResourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameResourceRow(
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $GameResourcesTable createAlias(String alias) {
    return $GameResourcesTable(attachedDatabase, alias);
  }
}

class GameResourceRow extends DataClass implements Insertable<GameResourceRow> {
  final String gameId;
  final String resourceId;
  final String status;

  /// Why this game is in this state on this system ("disc scratched").
  final String? notes;
  final DateTime? updatedAt;
  const GameResourceRow({
    required this.gameId,
    required this.resourceId,
    required this.status,
    this.notes,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['game_id'] = Variable<String>(gameId);
    map['resource_id'] = Variable<String>(resourceId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  GameResourcesCompanion toCompanion(bool nullToAbsent) {
    return GameResourcesCompanion(
      gameId: Value(gameId),
      resourceId: Value(resourceId),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory GameResourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameResourceRow(
      gameId: serializer.fromJson<String>(json['gameId']),
      resourceId: serializer.fromJson<String>(json['resourceId']),
      status: serializer.fromJson<String>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gameId': serializer.toJson<String>(gameId),
      'resourceId': serializer.toJson<String>(resourceId),
      'status': serializer.toJson<String>(status),
      'notes': serializer.toJson<String?>(notes),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  GameResourceRow copyWith({
    String? gameId,
    String? resourceId,
    String? status,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => GameResourceRow(
    gameId: gameId ?? this.gameId,
    resourceId: resourceId ?? this.resourceId,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  GameResourceRow copyWithCompanion(GameResourcesCompanion data) {
    return GameResourceRow(
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameResourceRow(')
          ..write('gameId: $gameId, ')
          ..write('resourceId: $resourceId, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gameId, resourceId, status, notes, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameResourceRow &&
          other.gameId == this.gameId &&
          other.resourceId == this.resourceId &&
          other.status == this.status &&
          other.notes == this.notes &&
          other.updatedAt == this.updatedAt);
}

class GameResourcesCompanion extends UpdateCompanion<GameResourceRow> {
  final Value<String> gameId;
  final Value<String> resourceId;
  final Value<String> status;
  final Value<String?> notes;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const GameResourcesCompanion({
    this.gameId = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GameResourcesCompanion.insert({
    required String gameId,
    required String resourceId,
    required String status,
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : gameId = Value(gameId),
       resourceId = Value(resourceId),
       status = Value(status);
  static Insertable<GameResourceRow> custom({
    Expression<String>? gameId,
    Expression<String>? resourceId,
    Expression<String>? status,
    Expression<String>? notes,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gameId != null) 'game_id': gameId,
      if (resourceId != null) 'resource_id': resourceId,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GameResourcesCompanion copyWith({
    Value<String>? gameId,
    Value<String>? resourceId,
    Value<String>? status,
    Value<String?>? notes,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return GameResourcesCompanion(
      gameId: gameId ?? this.gameId,
      resourceId: resourceId ?? this.resourceId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameResourcesCompanion(')
          ..write('gameId: $gameId, ')
          ..write('resourceId: $resourceId, ')
          ..write('status: $status, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GameControlsTable extends GameControls
    with TableInfo<$GameControlsTable, GameControlRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameControlsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> buttons =
      GeneratedColumn<String>(
        'buttons',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>($GameControlsTable.$converterbuttons);
  static const VerificationMeta _explanationMeta = const VerificationMeta(
    'explanation',
  );
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    gameId,
    section,
    action,
    buttons,
    explanation,
    notes,
    imageUrl,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_controls';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameControlRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    } else if (isInserting) {
      context.missing(_sectionMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(
        _explanationMeta,
        explanation.isAcceptableOrUnknown(
          data['explanation']!,
          _explanationMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameControlRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameControlRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      buttons: $GameControlsTable.$converterbuttons.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}buttons'],
        )!,
      ),
      explanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $GameControlsTable createAlias(String alias) {
    return $GameControlsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterbuttons =
      const StringListConverter();
}

class GameControlRow extends DataClass implements Insertable<GameControlRow> {
  final String id;
  final String gameId;
  final String section;
  final String action;
  final List<String> buttons;
  final String? explanation;
  final String? notes;
  final String? imageUrl;
  final int sortOrder;
  const GameControlRow({
    required this.id,
    required this.gameId,
    required this.section,
    required this.action,
    required this.buttons,
    this.explanation,
    this.notes,
    this.imageUrl,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['game_id'] = Variable<String>(gameId);
    map['section'] = Variable<String>(section);
    map['action'] = Variable<String>(action);
    {
      map['buttons'] = Variable<String>(
        $GameControlsTable.$converterbuttons.toSql(buttons),
      );
    }
    if (!nullToAbsent || explanation != null) {
      map['explanation'] = Variable<String>(explanation);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  GameControlsCompanion toCompanion(bool nullToAbsent) {
    return GameControlsCompanion(
      id: Value(id),
      gameId: Value(gameId),
      section: Value(section),
      action: Value(action),
      buttons: Value(buttons),
      explanation: explanation == null && nullToAbsent
          ? const Value.absent()
          : Value(explanation),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      sortOrder: Value(sortOrder),
    );
  }

  factory GameControlRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameControlRow(
      id: serializer.fromJson<String>(json['id']),
      gameId: serializer.fromJson<String>(json['gameId']),
      section: serializer.fromJson<String>(json['section']),
      action: serializer.fromJson<String>(json['action']),
      buttons: serializer.fromJson<List<String>>(json['buttons']),
      explanation: serializer.fromJson<String?>(json['explanation']),
      notes: serializer.fromJson<String?>(json['notes']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'gameId': serializer.toJson<String>(gameId),
      'section': serializer.toJson<String>(section),
      'action': serializer.toJson<String>(action),
      'buttons': serializer.toJson<List<String>>(buttons),
      'explanation': serializer.toJson<String?>(explanation),
      'notes': serializer.toJson<String?>(notes),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  GameControlRow copyWith({
    String? id,
    String? gameId,
    String? section,
    String? action,
    List<String>? buttons,
    Value<String?> explanation = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    int? sortOrder,
  }) => GameControlRow(
    id: id ?? this.id,
    gameId: gameId ?? this.gameId,
    section: section ?? this.section,
    action: action ?? this.action,
    buttons: buttons ?? this.buttons,
    explanation: explanation.present ? explanation.value : this.explanation,
    notes: notes.present ? notes.value : this.notes,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  GameControlRow copyWithCompanion(GameControlsCompanion data) {
    return GameControlRow(
      id: data.id.present ? data.id.value : this.id,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      section: data.section.present ? data.section.value : this.section,
      action: data.action.present ? data.action.value : this.action,
      buttons: data.buttons.present ? data.buttons.value : this.buttons,
      explanation: data.explanation.present
          ? data.explanation.value
          : this.explanation,
      notes: data.notes.present ? data.notes.value : this.notes,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameControlRow(')
          ..write('id: $id, ')
          ..write('gameId: $gameId, ')
          ..write('section: $section, ')
          ..write('action: $action, ')
          ..write('buttons: $buttons, ')
          ..write('explanation: $explanation, ')
          ..write('notes: $notes, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    gameId,
    section,
    action,
    buttons,
    explanation,
    notes,
    imageUrl,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameControlRow &&
          other.id == this.id &&
          other.gameId == this.gameId &&
          other.section == this.section &&
          other.action == this.action &&
          other.buttons == this.buttons &&
          other.explanation == this.explanation &&
          other.notes == this.notes &&
          other.imageUrl == this.imageUrl &&
          other.sortOrder == this.sortOrder);
}

class GameControlsCompanion extends UpdateCompanion<GameControlRow> {
  final Value<String> id;
  final Value<String> gameId;
  final Value<String> section;
  final Value<String> action;
  final Value<List<String>> buttons;
  final Value<String?> explanation;
  final Value<String?> notes;
  final Value<String?> imageUrl;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const GameControlsCompanion({
    this.id = const Value.absent(),
    this.gameId = const Value.absent(),
    this.section = const Value.absent(),
    this.action = const Value.absent(),
    this.buttons = const Value.absent(),
    this.explanation = const Value.absent(),
    this.notes = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GameControlsCompanion.insert({
    required String id,
    required String gameId,
    required String section,
    required String action,
    required List<String> buttons,
    this.explanation = const Value.absent(),
    this.notes = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       gameId = Value(gameId),
       section = Value(section),
       action = Value(action),
       buttons = Value(buttons);
  static Insertable<GameControlRow> custom({
    Expression<String>? id,
    Expression<String>? gameId,
    Expression<String>? section,
    Expression<String>? action,
    Expression<String>? buttons,
    Expression<String>? explanation,
    Expression<String>? notes,
    Expression<String>? imageUrl,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (gameId != null) 'game_id': gameId,
      if (section != null) 'section': section,
      if (action != null) 'action': action,
      if (buttons != null) 'buttons': buttons,
      if (explanation != null) 'explanation': explanation,
      if (notes != null) 'notes': notes,
      if (imageUrl != null) 'image_url': imageUrl,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GameControlsCompanion copyWith({
    Value<String>? id,
    Value<String>? gameId,
    Value<String>? section,
    Value<String>? action,
    Value<List<String>>? buttons,
    Value<String?>? explanation,
    Value<String?>? notes,
    Value<String?>? imageUrl,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return GameControlsCompanion(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      section: section ?? this.section,
      action: action ?? this.action,
      buttons: buttons ?? this.buttons,
      explanation: explanation ?? this.explanation,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (buttons.present) {
      map['buttons'] = Variable<String>(
        $GameControlsTable.$converterbuttons.toSql(buttons.value),
      );
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameControlsCompanion(')
          ..write('id: $id, ')
          ..write('gameId: $gameId, ')
          ..write('section: $section, ')
          ..write('action: $action, ')
          ..write('buttons: $buttons, ')
          ..write('explanation: $explanation, ')
          ..write('notes: $notes, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RatesTable extends Rates with TableInfo<$RatesTable, RateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityCodeMeta = const VerificationMeta(
    'activityCode',
  );
  @override
  late final GeneratedColumn<String> activityCode = GeneratedColumn<String>(
    'activity_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bandMeta = const VerificationMeta('band');
  @override
  late final GeneratedColumn<String> band = GeneratedColumn<String>(
    'band',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _controllerCountMeta = const VerificationMeta(
    'controllerCount',
  );
  @override
  late final GeneratedColumn<int> controllerCount = GeneratedColumn<int>(
    'controller_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMinutesMeta = const VerificationMeta(
    'unitMinutes',
  );
  @override
  late final GeneratedColumn<int> unitMinutes = GeneratedColumn<int>(
    'unit_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pricePaiseMeta = const VerificationMeta(
    'pricePaise',
  );
  @override
  late final GeneratedColumn<int> pricePaise = GeneratedColumn<int>(
    'price_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activityCode,
    band,
    controllerCount,
    unitMinutes,
    pricePaise,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rates';
  @override
  VerificationContext validateIntegrity(
    Insertable<RateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('activity_code')) {
      context.handle(
        _activityCodeMeta,
        activityCode.isAcceptableOrUnknown(
          data['activity_code']!,
          _activityCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityCodeMeta);
    }
    if (data.containsKey('band')) {
      context.handle(
        _bandMeta,
        band.isAcceptableOrUnknown(data['band']!, _bandMeta),
      );
    } else if (isInserting) {
      context.missing(_bandMeta);
    }
    if (data.containsKey('controller_count')) {
      context.handle(
        _controllerCountMeta,
        controllerCount.isAcceptableOrUnknown(
          data['controller_count']!,
          _controllerCountMeta,
        ),
      );
    }
    if (data.containsKey('unit_minutes')) {
      context.handle(
        _unitMinutesMeta,
        unitMinutes.isAcceptableOrUnknown(
          data['unit_minutes']!,
          _unitMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitMinutesMeta);
    }
    if (data.containsKey('price_paise')) {
      context.handle(
        _pricePaiseMeta,
        pricePaise.isAcceptableOrUnknown(data['price_paise']!, _pricePaiseMeta),
      );
    } else if (isInserting) {
      context.missing(_pricePaiseMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      activityCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_code'],
      )!,
      band: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}band'],
      )!,
      controllerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}controller_count'],
      ),
      unitMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_minutes'],
      )!,
      pricePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price_paise'],
      )!,
    );
  }

  @override
  $RatesTable createAlias(String alias) {
    return $RatesTable(attachedDatabase, alias);
  }
}

class RateRow extends DataClass implements Insertable<RateRow> {
  final String id;
  final String activityCode;
  final String band;
  final int? controllerCount;
  final int unitMinutes;
  final int pricePaise;
  const RateRow({
    required this.id,
    required this.activityCode,
    required this.band,
    this.controllerCount,
    required this.unitMinutes,
    required this.pricePaise,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['activity_code'] = Variable<String>(activityCode);
    map['band'] = Variable<String>(band);
    if (!nullToAbsent || controllerCount != null) {
      map['controller_count'] = Variable<int>(controllerCount);
    }
    map['unit_minutes'] = Variable<int>(unitMinutes);
    map['price_paise'] = Variable<int>(pricePaise);
    return map;
  }

  RatesCompanion toCompanion(bool nullToAbsent) {
    return RatesCompanion(
      id: Value(id),
      activityCode: Value(activityCode),
      band: Value(band),
      controllerCount: controllerCount == null && nullToAbsent
          ? const Value.absent()
          : Value(controllerCount),
      unitMinutes: Value(unitMinutes),
      pricePaise: Value(pricePaise),
    );
  }

  factory RateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RateRow(
      id: serializer.fromJson<String>(json['id']),
      activityCode: serializer.fromJson<String>(json['activityCode']),
      band: serializer.fromJson<String>(json['band']),
      controllerCount: serializer.fromJson<int?>(json['controllerCount']),
      unitMinutes: serializer.fromJson<int>(json['unitMinutes']),
      pricePaise: serializer.fromJson<int>(json['pricePaise']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'activityCode': serializer.toJson<String>(activityCode),
      'band': serializer.toJson<String>(band),
      'controllerCount': serializer.toJson<int?>(controllerCount),
      'unitMinutes': serializer.toJson<int>(unitMinutes),
      'pricePaise': serializer.toJson<int>(pricePaise),
    };
  }

  RateRow copyWith({
    String? id,
    String? activityCode,
    String? band,
    Value<int?> controllerCount = const Value.absent(),
    int? unitMinutes,
    int? pricePaise,
  }) => RateRow(
    id: id ?? this.id,
    activityCode: activityCode ?? this.activityCode,
    band: band ?? this.band,
    controllerCount: controllerCount.present
        ? controllerCount.value
        : this.controllerCount,
    unitMinutes: unitMinutes ?? this.unitMinutes,
    pricePaise: pricePaise ?? this.pricePaise,
  );
  RateRow copyWithCompanion(RatesCompanion data) {
    return RateRow(
      id: data.id.present ? data.id.value : this.id,
      activityCode: data.activityCode.present
          ? data.activityCode.value
          : this.activityCode,
      band: data.band.present ? data.band.value : this.band,
      controllerCount: data.controllerCount.present
          ? data.controllerCount.value
          : this.controllerCount,
      unitMinutes: data.unitMinutes.present
          ? data.unitMinutes.value
          : this.unitMinutes,
      pricePaise: data.pricePaise.present
          ? data.pricePaise.value
          : this.pricePaise,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RateRow(')
          ..write('id: $id, ')
          ..write('activityCode: $activityCode, ')
          ..write('band: $band, ')
          ..write('controllerCount: $controllerCount, ')
          ..write('unitMinutes: $unitMinutes, ')
          ..write('pricePaise: $pricePaise')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activityCode,
    band,
    controllerCount,
    unitMinutes,
    pricePaise,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RateRow &&
          other.id == this.id &&
          other.activityCode == this.activityCode &&
          other.band == this.band &&
          other.controllerCount == this.controllerCount &&
          other.unitMinutes == this.unitMinutes &&
          other.pricePaise == this.pricePaise);
}

class RatesCompanion extends UpdateCompanion<RateRow> {
  final Value<String> id;
  final Value<String> activityCode;
  final Value<String> band;
  final Value<int?> controllerCount;
  final Value<int> unitMinutes;
  final Value<int> pricePaise;
  final Value<int> rowid;
  const RatesCompanion({
    this.id = const Value.absent(),
    this.activityCode = const Value.absent(),
    this.band = const Value.absent(),
    this.controllerCount = const Value.absent(),
    this.unitMinutes = const Value.absent(),
    this.pricePaise = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RatesCompanion.insert({
    required String id,
    required String activityCode,
    required String band,
    this.controllerCount = const Value.absent(),
    required int unitMinutes,
    required int pricePaise,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityCode = Value(activityCode),
       band = Value(band),
       unitMinutes = Value(unitMinutes),
       pricePaise = Value(pricePaise);
  static Insertable<RateRow> custom({
    Expression<String>? id,
    Expression<String>? activityCode,
    Expression<String>? band,
    Expression<int>? controllerCount,
    Expression<int>? unitMinutes,
    Expression<int>? pricePaise,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activityCode != null) 'activity_code': activityCode,
      if (band != null) 'band': band,
      if (controllerCount != null) 'controller_count': controllerCount,
      if (unitMinutes != null) 'unit_minutes': unitMinutes,
      if (pricePaise != null) 'price_paise': pricePaise,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RatesCompanion copyWith({
    Value<String>? id,
    Value<String>? activityCode,
    Value<String>? band,
    Value<int?>? controllerCount,
    Value<int>? unitMinutes,
    Value<int>? pricePaise,
    Value<int>? rowid,
  }) {
    return RatesCompanion(
      id: id ?? this.id,
      activityCode: activityCode ?? this.activityCode,
      band: band ?? this.band,
      controllerCount: controllerCount ?? this.controllerCount,
      unitMinutes: unitMinutes ?? this.unitMinutes,
      pricePaise: pricePaise ?? this.pricePaise,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (activityCode.present) {
      map['activity_code'] = Variable<String>(activityCode.value);
    }
    if (band.present) {
      map['band'] = Variable<String>(band.value);
    }
    if (controllerCount.present) {
      map['controller_count'] = Variable<int>(controllerCount.value);
    }
    if (unitMinutes.present) {
      map['unit_minutes'] = Variable<int>(unitMinutes.value);
    }
    if (pricePaise.present) {
      map['price_paise'] = Variable<int>(pricePaise.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RatesCompanion(')
          ..write('id: $id, ')
          ..write('activityCode: $activityCode, ')
          ..write('band: $band, ')
          ..write('controllerCount: $controllerCount, ')
          ..write('unitMinutes: $unitMinutes, ')
          ..write('pricePaise: $pricePaise, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BillingPoliciesTable extends BillingPolicies
    with TableInfo<$BillingPoliciesTable, BillingPolicyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillingPoliciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'billing_policies';
  @override
  VerificationContext validateIntegrity(
    Insertable<BillingPolicyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillingPolicyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillingPolicyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $BillingPoliciesTable createAlias(String alias) {
    return $BillingPoliciesTable(attachedDatabase, alias);
  }
}

class BillingPolicyRow extends DataClass
    implements Insertable<BillingPolicyRow> {
  final String id;
  final String json;
  const BillingPolicyRow({required this.id, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['json'] = Variable<String>(json);
    return map;
  }

  BillingPoliciesCompanion toCompanion(bool nullToAbsent) {
    return BillingPoliciesCompanion(id: Value(id), json: Value(json));
  }

  factory BillingPolicyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillingPolicyRow(
      id: serializer.fromJson<String>(json['id']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'json': serializer.toJson<String>(json),
    };
  }

  BillingPolicyRow copyWith({String? id, String? json}) =>
      BillingPolicyRow(id: id ?? this.id, json: json ?? this.json);
  BillingPolicyRow copyWithCompanion(BillingPoliciesCompanion data) {
    return BillingPolicyRow(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillingPolicyRow(')
          ..write('id: $id, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillingPolicyRow &&
          other.id == this.id &&
          other.json == this.json);
}

class BillingPoliciesCompanion extends UpdateCompanion<BillingPolicyRow> {
  final Value<String> id;
  final Value<String> json;
  final Value<int> rowid;
  const BillingPoliciesCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BillingPoliciesCompanion.insert({
    required String id,
    required String json,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       json = Value(json);
  static Insertable<BillingPolicyRow> custom({
    Expression<String>? id,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BillingPoliciesCompanion copyWith({
    Value<String>? id,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return BillingPoliciesCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillingPoliciesCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HolidaysTable extends Holidays
    with TableInfo<$HolidaysTable, HolidayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HolidaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedMeta = const VerificationMeta('closed');
  @override
  late final GeneratedColumn<bool> closed = GeneratedColumn<bool>(
    'closed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("closed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [day, name, closed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holidays';
  @override
  VerificationContext validateIntegrity(
    Insertable<HolidayRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('closed')) {
      context.handle(
        _closedMeta,
        closed.isAcceptableOrUnknown(data['closed']!, _closedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  HolidayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HolidayRow(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      closed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}closed'],
      )!,
    );
  }

  @override
  $HolidaysTable createAlias(String alias) {
    return $HolidaysTable(attachedDatabase, alias);
  }
}

class HolidayRow extends DataClass implements Insertable<HolidayRow> {
  final String day;
  final String name;

  /// A public holiday (pricing rules can target or skip it). [closed]
  /// additionally means the centre does not trade that day (OWNER
  /// CONFIRMATION #26).
  final bool closed;
  const HolidayRow({
    required this.day,
    required this.name,
    required this.closed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['name'] = Variable<String>(name);
    map['closed'] = Variable<bool>(closed);
    return map;
  }

  HolidaysCompanion toCompanion(bool nullToAbsent) {
    return HolidaysCompanion(
      day: Value(day),
      name: Value(name),
      closed: Value(closed),
    );
  }

  factory HolidayRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HolidayRow(
      day: serializer.fromJson<String>(json['day']),
      name: serializer.fromJson<String>(json['name']),
      closed: serializer.fromJson<bool>(json['closed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'name': serializer.toJson<String>(name),
      'closed': serializer.toJson<bool>(closed),
    };
  }

  HolidayRow copyWith({String? day, String? name, bool? closed}) => HolidayRow(
    day: day ?? this.day,
    name: name ?? this.name,
    closed: closed ?? this.closed,
  );
  HolidayRow copyWithCompanion(HolidaysCompanion data) {
    return HolidayRow(
      day: data.day.present ? data.day.value : this.day,
      name: data.name.present ? data.name.value : this.name,
      closed: data.closed.present ? data.closed.value : this.closed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HolidayRow(')
          ..write('day: $day, ')
          ..write('name: $name, ')
          ..write('closed: $closed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, name, closed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HolidayRow &&
          other.day == this.day &&
          other.name == this.name &&
          other.closed == this.closed);
}

class HolidaysCompanion extends UpdateCompanion<HolidayRow> {
  final Value<String> day;
  final Value<String> name;
  final Value<bool> closed;
  final Value<int> rowid;
  const HolidaysCompanion({
    this.day = const Value.absent(),
    this.name = const Value.absent(),
    this.closed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HolidaysCompanion.insert({
    required String day,
    required String name,
    this.closed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : day = Value(day),
       name = Value(name);
  static Insertable<HolidayRow> custom({
    Expression<String>? day,
    Expression<String>? name,
    Expression<bool>? closed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (name != null) 'name': name,
      if (closed != null) 'closed': closed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HolidaysCompanion copyWith({
    Value<String>? day,
    Value<String>? name,
    Value<bool>? closed,
    Value<int>? rowid,
  }) {
    return HolidaysCompanion(
      day: day ?? this.day,
      name: name ?? this.name,
      closed: closed ?? this.closed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (closed.present) {
      map['closed'] = Variable<bool>(closed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HolidaysCompanion(')
          ..write('day: $day, ')
          ..write('name: $name, ')
          ..write('closed: $closed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String json;
  const SettingRow({required this.key, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), json: Value(json));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
    };
  }

  SettingRow copyWith({String? key, String? json}) =>
      SettingRow(key: key ?? this.key, json: json ?? this.json);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow && other.key == this.key && other.json == this.json);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> json;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String json,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       json = Value(json);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PricingRulesTable extends PricingRules
    with TableInfo<$PricingRulesTable, PricingRuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PricingRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String> days =
      GeneratedColumn<String>(
        'days',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<int>>($PricingRulesTable.$converterdays);
  static const VerificationMeta _startMinMeta = const VerificationMeta(
    'startMin',
  );
  @override
  late final GeneratedColumn<int> startMin = GeneratedColumn<int>(
    'start_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMinMeta = const VerificationMeta('endMin');
  @override
  late final GeneratedColumn<int> endMin = GeneratedColumn<int>(
    'end_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _holidayModeMeta = const VerificationMeta(
    'holidayMode',
  );
  @override
  late final GeneratedColumn<String> holidayMode = GeneratedColumn<String>(
    'holiday_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('any'),
  );
  static const VerificationMeta _validFromMeta = const VerificationMeta(
    'validFrom',
  );
  @override
  late final GeneratedColumn<String> validFrom = GeneratedColumn<String>(
    'valid_from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _validUntilMeta = const VerificationMeta(
    'validUntil',
  );
  @override
  late final GeneratedColumn<String> validUntil = GeneratedColumn<String>(
    'valid_until',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
  activityCodes = GeneratedColumn<String>(
    'activity_codes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<String>>($PricingRulesTable.$converteractivityCodes);
  static const VerificationMeta _adjustKindMeta = const VerificationMeta(
    'adjustKind',
  );
  @override
  late final GeneratedColumn<String> adjustKind = GeneratedColumn<String>(
    'adjust_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _adjustValueMeta = const VerificationMeta(
    'adjustValue',
  );
  @override
  late final GeneratedColumn<int> adjustValue = GeneratedColumn<int>(
    'adjust_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    priority,
    active,
    days,
    startMin,
    endMin,
    holidayMode,
    validFrom,
    validUntil,
    activityCodes,
    adjustKind,
    adjustValue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pricing_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<PricingRuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('start_min')) {
      context.handle(
        _startMinMeta,
        startMin.isAcceptableOrUnknown(data['start_min']!, _startMinMeta),
      );
    } else if (isInserting) {
      context.missing(_startMinMeta);
    }
    if (data.containsKey('end_min')) {
      context.handle(
        _endMinMeta,
        endMin.isAcceptableOrUnknown(data['end_min']!, _endMinMeta),
      );
    } else if (isInserting) {
      context.missing(_endMinMeta);
    }
    if (data.containsKey('holiday_mode')) {
      context.handle(
        _holidayModeMeta,
        holidayMode.isAcceptableOrUnknown(
          data['holiday_mode']!,
          _holidayModeMeta,
        ),
      );
    }
    if (data.containsKey('valid_from')) {
      context.handle(
        _validFromMeta,
        validFrom.isAcceptableOrUnknown(data['valid_from']!, _validFromMeta),
      );
    }
    if (data.containsKey('valid_until')) {
      context.handle(
        _validUntilMeta,
        validUntil.isAcceptableOrUnknown(data['valid_until']!, _validUntilMeta),
      );
    }
    if (data.containsKey('adjust_kind')) {
      context.handle(
        _adjustKindMeta,
        adjustKind.isAcceptableOrUnknown(data['adjust_kind']!, _adjustKindMeta),
      );
    } else if (isInserting) {
      context.missing(_adjustKindMeta);
    }
    if (data.containsKey('adjust_value')) {
      context.handle(
        _adjustValueMeta,
        adjustValue.isAcceptableOrUnknown(
          data['adjust_value']!,
          _adjustValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_adjustValueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PricingRuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricingRuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      days: $PricingRulesTable.$converterdays.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}days'],
        )!,
      ),
      startMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_min'],
      )!,
      endMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_min'],
      )!,
      holidayMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holiday_mode'],
      )!,
      validFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valid_from'],
      ),
      validUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valid_until'],
      ),
      activityCodes: $PricingRulesTable.$converteractivityCodes.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}activity_codes'],
        )!,
      ),
      adjustKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}adjust_kind'],
      )!,
      adjustValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}adjust_value'],
      )!,
    );
  }

  @override
  $PricingRulesTable createAlias(String alias) {
    return $PricingRulesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<int>, String> $converterdays =
      const IntListConverter();
  static TypeConverter<List<String>, String> $converteractivityCodes =
      const StringListConverter();
}

class PricingRuleRow extends DataClass implements Insertable<PricingRuleRow> {
  final String id;
  final String name;
  final int priority;
  final bool active;

  /// ISO weekdays (1 = Monday … 7 = Sunday).
  final List<int> days;
  final int startMin;
  final int endMin;
  final String holidayMode;

  /// IST ISO dates, inclusive; null = open-ended.
  final String? validFrom;
  final String? validUntil;

  /// Empty = every activity.
  final List<String> activityCodes;
  final String adjustKind;
  final int adjustValue;
  const PricingRuleRow({
    required this.id,
    required this.name,
    required this.priority,
    required this.active,
    required this.days,
    required this.startMin,
    required this.endMin,
    required this.holidayMode,
    this.validFrom,
    this.validUntil,
    required this.activityCodes,
    required this.adjustKind,
    required this.adjustValue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['priority'] = Variable<int>(priority);
    map['active'] = Variable<bool>(active);
    {
      map['days'] = Variable<String>(
        $PricingRulesTable.$converterdays.toSql(days),
      );
    }
    map['start_min'] = Variable<int>(startMin);
    map['end_min'] = Variable<int>(endMin);
    map['holiday_mode'] = Variable<String>(holidayMode);
    if (!nullToAbsent || validFrom != null) {
      map['valid_from'] = Variable<String>(validFrom);
    }
    if (!nullToAbsent || validUntil != null) {
      map['valid_until'] = Variable<String>(validUntil);
    }
    {
      map['activity_codes'] = Variable<String>(
        $PricingRulesTable.$converteractivityCodes.toSql(activityCodes),
      );
    }
    map['adjust_kind'] = Variable<String>(adjustKind);
    map['adjust_value'] = Variable<int>(adjustValue);
    return map;
  }

  PricingRulesCompanion toCompanion(bool nullToAbsent) {
    return PricingRulesCompanion(
      id: Value(id),
      name: Value(name),
      priority: Value(priority),
      active: Value(active),
      days: Value(days),
      startMin: Value(startMin),
      endMin: Value(endMin),
      holidayMode: Value(holidayMode),
      validFrom: validFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(validFrom),
      validUntil: validUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(validUntil),
      activityCodes: Value(activityCodes),
      adjustKind: Value(adjustKind),
      adjustValue: Value(adjustValue),
    );
  }

  factory PricingRuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricingRuleRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      priority: serializer.fromJson<int>(json['priority']),
      active: serializer.fromJson<bool>(json['active']),
      days: serializer.fromJson<List<int>>(json['days']),
      startMin: serializer.fromJson<int>(json['startMin']),
      endMin: serializer.fromJson<int>(json['endMin']),
      holidayMode: serializer.fromJson<String>(json['holidayMode']),
      validFrom: serializer.fromJson<String?>(json['validFrom']),
      validUntil: serializer.fromJson<String?>(json['validUntil']),
      activityCodes: serializer.fromJson<List<String>>(json['activityCodes']),
      adjustKind: serializer.fromJson<String>(json['adjustKind']),
      adjustValue: serializer.fromJson<int>(json['adjustValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'priority': serializer.toJson<int>(priority),
      'active': serializer.toJson<bool>(active),
      'days': serializer.toJson<List<int>>(days),
      'startMin': serializer.toJson<int>(startMin),
      'endMin': serializer.toJson<int>(endMin),
      'holidayMode': serializer.toJson<String>(holidayMode),
      'validFrom': serializer.toJson<String?>(validFrom),
      'validUntil': serializer.toJson<String?>(validUntil),
      'activityCodes': serializer.toJson<List<String>>(activityCodes),
      'adjustKind': serializer.toJson<String>(adjustKind),
      'adjustValue': serializer.toJson<int>(adjustValue),
    };
  }

  PricingRuleRow copyWith({
    String? id,
    String? name,
    int? priority,
    bool? active,
    List<int>? days,
    int? startMin,
    int? endMin,
    String? holidayMode,
    Value<String?> validFrom = const Value.absent(),
    Value<String?> validUntil = const Value.absent(),
    List<String>? activityCodes,
    String? adjustKind,
    int? adjustValue,
  }) => PricingRuleRow(
    id: id ?? this.id,
    name: name ?? this.name,
    priority: priority ?? this.priority,
    active: active ?? this.active,
    days: days ?? this.days,
    startMin: startMin ?? this.startMin,
    endMin: endMin ?? this.endMin,
    holidayMode: holidayMode ?? this.holidayMode,
    validFrom: validFrom.present ? validFrom.value : this.validFrom,
    validUntil: validUntil.present ? validUntil.value : this.validUntil,
    activityCodes: activityCodes ?? this.activityCodes,
    adjustKind: adjustKind ?? this.adjustKind,
    adjustValue: adjustValue ?? this.adjustValue,
  );
  PricingRuleRow copyWithCompanion(PricingRulesCompanion data) {
    return PricingRuleRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      priority: data.priority.present ? data.priority.value : this.priority,
      active: data.active.present ? data.active.value : this.active,
      days: data.days.present ? data.days.value : this.days,
      startMin: data.startMin.present ? data.startMin.value : this.startMin,
      endMin: data.endMin.present ? data.endMin.value : this.endMin,
      holidayMode: data.holidayMode.present
          ? data.holidayMode.value
          : this.holidayMode,
      validFrom: data.validFrom.present ? data.validFrom.value : this.validFrom,
      validUntil: data.validUntil.present
          ? data.validUntil.value
          : this.validUntil,
      activityCodes: data.activityCodes.present
          ? data.activityCodes.value
          : this.activityCodes,
      adjustKind: data.adjustKind.present
          ? data.adjustKind.value
          : this.adjustKind,
      adjustValue: data.adjustValue.present
          ? data.adjustValue.value
          : this.adjustValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricingRuleRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('priority: $priority, ')
          ..write('active: $active, ')
          ..write('days: $days, ')
          ..write('startMin: $startMin, ')
          ..write('endMin: $endMin, ')
          ..write('holidayMode: $holidayMode, ')
          ..write('validFrom: $validFrom, ')
          ..write('validUntil: $validUntil, ')
          ..write('activityCodes: $activityCodes, ')
          ..write('adjustKind: $adjustKind, ')
          ..write('adjustValue: $adjustValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    priority,
    active,
    days,
    startMin,
    endMin,
    holidayMode,
    validFrom,
    validUntil,
    activityCodes,
    adjustKind,
    adjustValue,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricingRuleRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.priority == this.priority &&
          other.active == this.active &&
          other.days == this.days &&
          other.startMin == this.startMin &&
          other.endMin == this.endMin &&
          other.holidayMode == this.holidayMode &&
          other.validFrom == this.validFrom &&
          other.validUntil == this.validUntil &&
          other.activityCodes == this.activityCodes &&
          other.adjustKind == this.adjustKind &&
          other.adjustValue == this.adjustValue);
}

class PricingRulesCompanion extends UpdateCompanion<PricingRuleRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> priority;
  final Value<bool> active;
  final Value<List<int>> days;
  final Value<int> startMin;
  final Value<int> endMin;
  final Value<String> holidayMode;
  final Value<String?> validFrom;
  final Value<String?> validUntil;
  final Value<List<String>> activityCodes;
  final Value<String> adjustKind;
  final Value<int> adjustValue;
  final Value<int> rowid;
  const PricingRulesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.priority = const Value.absent(),
    this.active = const Value.absent(),
    this.days = const Value.absent(),
    this.startMin = const Value.absent(),
    this.endMin = const Value.absent(),
    this.holidayMode = const Value.absent(),
    this.validFrom = const Value.absent(),
    this.validUntil = const Value.absent(),
    this.activityCodes = const Value.absent(),
    this.adjustKind = const Value.absent(),
    this.adjustValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PricingRulesCompanion.insert({
    required String id,
    required String name,
    this.priority = const Value.absent(),
    this.active = const Value.absent(),
    required List<int> days,
    required int startMin,
    required int endMin,
    this.holidayMode = const Value.absent(),
    this.validFrom = const Value.absent(),
    this.validUntil = const Value.absent(),
    required List<String> activityCodes,
    required String adjustKind,
    required int adjustValue,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       days = Value(days),
       startMin = Value(startMin),
       endMin = Value(endMin),
       activityCodes = Value(activityCodes),
       adjustKind = Value(adjustKind),
       adjustValue = Value(adjustValue);
  static Insertable<PricingRuleRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? priority,
    Expression<bool>? active,
    Expression<String>? days,
    Expression<int>? startMin,
    Expression<int>? endMin,
    Expression<String>? holidayMode,
    Expression<String>? validFrom,
    Expression<String>? validUntil,
    Expression<String>? activityCodes,
    Expression<String>? adjustKind,
    Expression<int>? adjustValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (priority != null) 'priority': priority,
      if (active != null) 'active': active,
      if (days != null) 'days': days,
      if (startMin != null) 'start_min': startMin,
      if (endMin != null) 'end_min': endMin,
      if (holidayMode != null) 'holiday_mode': holidayMode,
      if (validFrom != null) 'valid_from': validFrom,
      if (validUntil != null) 'valid_until': validUntil,
      if (activityCodes != null) 'activity_codes': activityCodes,
      if (adjustKind != null) 'adjust_kind': adjustKind,
      if (adjustValue != null) 'adjust_value': adjustValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PricingRulesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? priority,
    Value<bool>? active,
    Value<List<int>>? days,
    Value<int>? startMin,
    Value<int>? endMin,
    Value<String>? holidayMode,
    Value<String?>? validFrom,
    Value<String?>? validUntil,
    Value<List<String>>? activityCodes,
    Value<String>? adjustKind,
    Value<int>? adjustValue,
    Value<int>? rowid,
  }) {
    return PricingRulesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      priority: priority ?? this.priority,
      active: active ?? this.active,
      days: days ?? this.days,
      startMin: startMin ?? this.startMin,
      endMin: endMin ?? this.endMin,
      holidayMode: holidayMode ?? this.holidayMode,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      activityCodes: activityCodes ?? this.activityCodes,
      adjustKind: adjustKind ?? this.adjustKind,
      adjustValue: adjustValue ?? this.adjustValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (days.present) {
      map['days'] = Variable<String>(
        $PricingRulesTable.$converterdays.toSql(days.value),
      );
    }
    if (startMin.present) {
      map['start_min'] = Variable<int>(startMin.value);
    }
    if (endMin.present) {
      map['end_min'] = Variable<int>(endMin.value);
    }
    if (holidayMode.present) {
      map['holiday_mode'] = Variable<String>(holidayMode.value);
    }
    if (validFrom.present) {
      map['valid_from'] = Variable<String>(validFrom.value);
    }
    if (validUntil.present) {
      map['valid_until'] = Variable<String>(validUntil.value);
    }
    if (activityCodes.present) {
      map['activity_codes'] = Variable<String>(
        $PricingRulesTable.$converteractivityCodes.toSql(activityCodes.value),
      );
    }
    if (adjustKind.present) {
      map['adjust_kind'] = Variable<String>(adjustKind.value);
    }
    if (adjustValue.present) {
      map['adjust_value'] = Variable<int>(adjustValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PricingRulesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('priority: $priority, ')
          ..write('active: $active, ')
          ..write('days: $days, ')
          ..write('startMin: $startMin, ')
          ..write('endMin: $endMin, ')
          ..write('holidayMode: $holidayMode, ')
          ..write('validFrom: $validFrom, ')
          ..write('validUntil: $validUntil, ')
          ..write('activityCodes: $activityCodes, ')
          ..write('adjustKind: $adjustKind, ')
          ..write('adjustValue: $adjustValue, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookingIdMeta = const VerificationMeta(
    'bookingId',
  );
  @override
  late final GeneratedColumn<String> bookingId = GeneratedColumn<String>(
    'booking_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentStatusMeta = const VerificationMeta(
    'paymentStatus',
  );
  @override
  late final GeneratedColumn<String> paymentStatus = GeneratedColumn<String>(
    'payment_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledEndAtMeta = const VerificationMeta(
    'scheduledEndAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledEndAt =
      GeneratedColumn<DateTime>(
        'scheduled_end_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _actualEndedAtMeta = const VerificationMeta(
    'actualEndedAt',
  );
  @override
  late final GeneratedColumn<DateTime> actualEndedAt =
      GeneratedColumn<DateTime>(
        'actual_ended_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
  pricingSnapshot =
      GeneratedColumn<String>(
        'pricing_snapshot',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Map<String, dynamic>>(
        $SessionsTable.$converterpricingSnapshot,
      );
  static const VerificationMeta _billedAmountPaiseMeta = const VerificationMeta(
    'billedAmountPaise',
  );
  @override
  late final GeneratedColumn<int> billedAmountPaise = GeneratedColumn<int>(
    'billed_amount_paise',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voidReasonMeta = const VerificationMeta(
    'voidReason',
  );
  @override
  late final GeneratedColumn<String> voidReason = GeneratedColumn<String>(
    'void_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookingId,
    customerId,
    status,
    paymentStatus,
    startedAt,
    scheduledEndAt,
    actualEndedAt,
    pricingSnapshot,
    billedAmountPaise,
    voidReason,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('booking_id')) {
      context.handle(
        _bookingIdMeta,
        bookingId.isAcceptableOrUnknown(data['booking_id']!, _bookingIdMeta),
      );
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('payment_status')) {
      context.handle(
        _paymentStatusMeta,
        paymentStatus.isAcceptableOrUnknown(
          data['payment_status']!,
          _paymentStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentStatusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('scheduled_end_at')) {
      context.handle(
        _scheduledEndAtMeta,
        scheduledEndAt.isAcceptableOrUnknown(
          data['scheduled_end_at']!,
          _scheduledEndAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledEndAtMeta);
    }
    if (data.containsKey('actual_ended_at')) {
      context.handle(
        _actualEndedAtMeta,
        actualEndedAt.isAcceptableOrUnknown(
          data['actual_ended_at']!,
          _actualEndedAtMeta,
        ),
      );
    }
    if (data.containsKey('billed_amount_paise')) {
      context.handle(
        _billedAmountPaiseMeta,
        billedAmountPaise.isAcceptableOrUnknown(
          data['billed_amount_paise']!,
          _billedAmountPaiseMeta,
        ),
      );
    }
    if (data.containsKey('void_reason')) {
      context.handle(
        _voidReasonMeta,
        voidReason.isAcceptableOrUnknown(data['void_reason']!, _voidReasonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}booking_id'],
      ),
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      paymentStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      scheduledEndAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_end_at'],
      )!,
      actualEndedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}actual_ended_at'],
      ),
      pricingSnapshot: $SessionsTable.$converterpricingSnapshot.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}pricing_snapshot'],
        )!,
      ),
      billedAmountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}billed_amount_paise'],
      ),
      voidReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}void_reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }

  static TypeConverter<Map<String, dynamic>, String> $converterpricingSnapshot =
      const JsonMapConverter();
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;
  final String? bookingId;
  final String customerId;
  final String status;
  final String paymentStatus;
  final DateTime startedAt;
  final DateTime scheduledEndAt;
  final DateTime? actualEndedAt;
  final Map<String, dynamic> pricingSnapshot;
  final int? billedAmountPaise;
  final String? voidReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SessionRow({
    required this.id,
    this.bookingId,
    required this.customerId,
    required this.status,
    required this.paymentStatus,
    required this.startedAt,
    required this.scheduledEndAt,
    this.actualEndedAt,
    required this.pricingSnapshot,
    this.billedAmountPaise,
    this.voidReason,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || bookingId != null) {
      map['booking_id'] = Variable<String>(bookingId);
    }
    map['customer_id'] = Variable<String>(customerId);
    map['status'] = Variable<String>(status);
    map['payment_status'] = Variable<String>(paymentStatus);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['scheduled_end_at'] = Variable<DateTime>(scheduledEndAt);
    if (!nullToAbsent || actualEndedAt != null) {
      map['actual_ended_at'] = Variable<DateTime>(actualEndedAt);
    }
    {
      map['pricing_snapshot'] = Variable<String>(
        $SessionsTable.$converterpricingSnapshot.toSql(pricingSnapshot),
      );
    }
    if (!nullToAbsent || billedAmountPaise != null) {
      map['billed_amount_paise'] = Variable<int>(billedAmountPaise);
    }
    if (!nullToAbsent || voidReason != null) {
      map['void_reason'] = Variable<String>(voidReason);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      bookingId: bookingId == null && nullToAbsent
          ? const Value.absent()
          : Value(bookingId),
      customerId: Value(customerId),
      status: Value(status),
      paymentStatus: Value(paymentStatus),
      startedAt: Value(startedAt),
      scheduledEndAt: Value(scheduledEndAt),
      actualEndedAt: actualEndedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(actualEndedAt),
      pricingSnapshot: Value(pricingSnapshot),
      billedAmountPaise: billedAmountPaise == null && nullToAbsent
          ? const Value.absent()
          : Value(billedAmountPaise),
      voidReason: voidReason == null && nullToAbsent
          ? const Value.absent()
          : Value(voidReason),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      bookingId: serializer.fromJson<String?>(json['bookingId']),
      customerId: serializer.fromJson<String>(json['customerId']),
      status: serializer.fromJson<String>(json['status']),
      paymentStatus: serializer.fromJson<String>(json['paymentStatus']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      scheduledEndAt: serializer.fromJson<DateTime>(json['scheduledEndAt']),
      actualEndedAt: serializer.fromJson<DateTime?>(json['actualEndedAt']),
      pricingSnapshot: serializer.fromJson<Map<String, dynamic>>(
        json['pricingSnapshot'],
      ),
      billedAmountPaise: serializer.fromJson<int?>(json['billedAmountPaise']),
      voidReason: serializer.fromJson<String?>(json['voidReason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookingId': serializer.toJson<String?>(bookingId),
      'customerId': serializer.toJson<String>(customerId),
      'status': serializer.toJson<String>(status),
      'paymentStatus': serializer.toJson<String>(paymentStatus),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'scheduledEndAt': serializer.toJson<DateTime>(scheduledEndAt),
      'actualEndedAt': serializer.toJson<DateTime?>(actualEndedAt),
      'pricingSnapshot': serializer.toJson<Map<String, dynamic>>(
        pricingSnapshot,
      ),
      'billedAmountPaise': serializer.toJson<int?>(billedAmountPaise),
      'voidReason': serializer.toJson<String?>(voidReason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SessionRow copyWith({
    String? id,
    Value<String?> bookingId = const Value.absent(),
    String? customerId,
    String? status,
    String? paymentStatus,
    DateTime? startedAt,
    DateTime? scheduledEndAt,
    Value<DateTime?> actualEndedAt = const Value.absent(),
    Map<String, dynamic>? pricingSnapshot,
    Value<int?> billedAmountPaise = const Value.absent(),
    Value<String?> voidReason = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SessionRow(
    id: id ?? this.id,
    bookingId: bookingId.present ? bookingId.value : this.bookingId,
    customerId: customerId ?? this.customerId,
    status: status ?? this.status,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    startedAt: startedAt ?? this.startedAt,
    scheduledEndAt: scheduledEndAt ?? this.scheduledEndAt,
    actualEndedAt: actualEndedAt.present
        ? actualEndedAt.value
        : this.actualEndedAt,
    pricingSnapshot: pricingSnapshot ?? this.pricingSnapshot,
    billedAmountPaise: billedAmountPaise.present
        ? billedAmountPaise.value
        : this.billedAmountPaise,
    voidReason: voidReason.present ? voidReason.value : this.voidReason,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      bookingId: data.bookingId.present ? data.bookingId.value : this.bookingId,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      status: data.status.present ? data.status.value : this.status,
      paymentStatus: data.paymentStatus.present
          ? data.paymentStatus.value
          : this.paymentStatus,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      scheduledEndAt: data.scheduledEndAt.present
          ? data.scheduledEndAt.value
          : this.scheduledEndAt,
      actualEndedAt: data.actualEndedAt.present
          ? data.actualEndedAt.value
          : this.actualEndedAt,
      pricingSnapshot: data.pricingSnapshot.present
          ? data.pricingSnapshot.value
          : this.pricingSnapshot,
      billedAmountPaise: data.billedAmountPaise.present
          ? data.billedAmountPaise.value
          : this.billedAmountPaise,
      voidReason: data.voidReason.present
          ? data.voidReason.value
          : this.voidReason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('bookingId: $bookingId, ')
          ..write('customerId: $customerId, ')
          ..write('status: $status, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('startedAt: $startedAt, ')
          ..write('scheduledEndAt: $scheduledEndAt, ')
          ..write('actualEndedAt: $actualEndedAt, ')
          ..write('pricingSnapshot: $pricingSnapshot, ')
          ..write('billedAmountPaise: $billedAmountPaise, ')
          ..write('voidReason: $voidReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookingId,
    customerId,
    status,
    paymentStatus,
    startedAt,
    scheduledEndAt,
    actualEndedAt,
    pricingSnapshot,
    billedAmountPaise,
    voidReason,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.bookingId == this.bookingId &&
          other.customerId == this.customerId &&
          other.status == this.status &&
          other.paymentStatus == this.paymentStatus &&
          other.startedAt == this.startedAt &&
          other.scheduledEndAt == this.scheduledEndAt &&
          other.actualEndedAt == this.actualEndedAt &&
          other.pricingSnapshot == this.pricingSnapshot &&
          other.billedAmountPaise == this.billedAmountPaise &&
          other.voidReason == this.voidReason &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<String?> bookingId;
  final Value<String> customerId;
  final Value<String> status;
  final Value<String> paymentStatus;
  final Value<DateTime> startedAt;
  final Value<DateTime> scheduledEndAt;
  final Value<DateTime?> actualEndedAt;
  final Value<Map<String, dynamic>> pricingSnapshot;
  final Value<int?> billedAmountPaise;
  final Value<String?> voidReason;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.bookingId = const Value.absent(),
    this.customerId = const Value.absent(),
    this.status = const Value.absent(),
    this.paymentStatus = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.scheduledEndAt = const Value.absent(),
    this.actualEndedAt = const Value.absent(),
    this.pricingSnapshot = const Value.absent(),
    this.billedAmountPaise = const Value.absent(),
    this.voidReason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    this.bookingId = const Value.absent(),
    required String customerId,
    required String status,
    required String paymentStatus,
    required DateTime startedAt,
    required DateTime scheduledEndAt,
    this.actualEndedAt = const Value.absent(),
    required Map<String, dynamic> pricingSnapshot,
    this.billedAmountPaise = const Value.absent(),
    this.voidReason = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       customerId = Value(customerId),
       status = Value(status),
       paymentStatus = Value(paymentStatus),
       startedAt = Value(startedAt),
       scheduledEndAt = Value(scheduledEndAt),
       pricingSnapshot = Value(pricingSnapshot),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<String>? bookingId,
    Expression<String>? customerId,
    Expression<String>? status,
    Expression<String>? paymentStatus,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? scheduledEndAt,
    Expression<DateTime>? actualEndedAt,
    Expression<String>? pricingSnapshot,
    Expression<int>? billedAmountPaise,
    Expression<String>? voidReason,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookingId != null) 'booking_id': bookingId,
      if (customerId != null) 'customer_id': customerId,
      if (status != null) 'status': status,
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (startedAt != null) 'started_at': startedAt,
      if (scheduledEndAt != null) 'scheduled_end_at': scheduledEndAt,
      if (actualEndedAt != null) 'actual_ended_at': actualEndedAt,
      if (pricingSnapshot != null) 'pricing_snapshot': pricingSnapshot,
      if (billedAmountPaise != null) 'billed_amount_paise': billedAmountPaise,
      if (voidReason != null) 'void_reason': voidReason,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? bookingId,
    Value<String>? customerId,
    Value<String>? status,
    Value<String>? paymentStatus,
    Value<DateTime>? startedAt,
    Value<DateTime>? scheduledEndAt,
    Value<DateTime?>? actualEndedAt,
    Value<Map<String, dynamic>>? pricingSnapshot,
    Value<int?>? billedAmountPaise,
    Value<String?>? voidReason,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      startedAt: startedAt ?? this.startedAt,
      scheduledEndAt: scheduledEndAt ?? this.scheduledEndAt,
      actualEndedAt: actualEndedAt ?? this.actualEndedAt,
      pricingSnapshot: pricingSnapshot ?? this.pricingSnapshot,
      billedAmountPaise: billedAmountPaise ?? this.billedAmountPaise,
      voidReason: voidReason ?? this.voidReason,
      createdAt: createdAt ?? this.createdAt,
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
    if (bookingId.present) {
      map['booking_id'] = Variable<String>(bookingId.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (paymentStatus.present) {
      map['payment_status'] = Variable<String>(paymentStatus.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (scheduledEndAt.present) {
      map['scheduled_end_at'] = Variable<DateTime>(scheduledEndAt.value);
    }
    if (actualEndedAt.present) {
      map['actual_ended_at'] = Variable<DateTime>(actualEndedAt.value);
    }
    if (pricingSnapshot.present) {
      map['pricing_snapshot'] = Variable<String>(
        $SessionsTable.$converterpricingSnapshot.toSql(pricingSnapshot.value),
      );
    }
    if (billedAmountPaise.present) {
      map['billed_amount_paise'] = Variable<int>(billedAmountPaise.value);
    }
    if (voidReason.present) {
      map['void_reason'] = Variable<String>(voidReason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('bookingId: $bookingId, ')
          ..write('customerId: $customerId, ')
          ..write('status: $status, ')
          ..write('paymentStatus: $paymentStatus, ')
          ..write('startedAt: $startedAt, ')
          ..write('scheduledEndAt: $scheduledEndAt, ')
          ..write('actualEndedAt: $actualEndedAt, ')
          ..write('pricingSnapshot: $pricingSnapshot, ')
          ..write('billedAmountPaise: $billedAmountPaise, ')
          ..write('voidReason: $voidReason, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionSegmentsTable extends SessionSegments
    with TableInfo<$SessionSegmentsTable, SessionSegmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _indexMeta = const VerificationMeta('index');
  @override
  late final GeneratedColumn<int> index = GeneratedColumn<int>(
    'index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityCodeMeta = const VerificationMeta(
    'activityCode',
  );
  @override
  late final GeneratedColumn<String> activityCode = GeneratedColumn<String>(
    'activity_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _controllerCountMeta = const VerificationMeta(
    'controllerCount',
  );
  @override
  late final GeneratedColumn<int> controllerCount = GeneratedColumn<int>(
    'controller_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    index,
    resourceId,
    activityCode,
    gameId,
    controllerCount,
    startedAt,
    endedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionSegmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('index')) {
      context.handle(
        _indexMeta,
        index.isAcceptableOrUnknown(data['index']!, _indexMeta),
      );
    } else if (isInserting) {
      context.missing(_indexMeta);
    }
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_resourceIdMeta);
    }
    if (data.containsKey('activity_code')) {
      context.handle(
        _activityCodeMeta,
        activityCode.isAcceptableOrUnknown(
          data['activity_code']!,
          _activityCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityCodeMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    }
    if (data.containsKey('controller_count')) {
      context.handle(
        _controllerCountMeta,
        controllerCount.isAcceptableOrUnknown(
          data['controller_count']!,
          _controllerCountMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionSegmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionSegmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      index: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}index'],
      )!,
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      )!,
      activityCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_code'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      ),
      controllerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}controller_count'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SessionSegmentsTable createAlias(String alias) {
    return $SessionSegmentsTable(attachedDatabase, alias);
  }
}

class SessionSegmentRow extends DataClass
    implements Insertable<SessionSegmentRow> {
  final String id;
  final String sessionId;
  final int index;
  final String resourceId;
  final String activityCode;
  final String? gameId;
  final int? controllerCount;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  const SessionSegmentRow({
    required this.id,
    required this.sessionId,
    required this.index,
    required this.resourceId,
    required this.activityCode,
    this.gameId,
    this.controllerCount,
    required this.startedAt,
    this.endedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['index'] = Variable<int>(index);
    map['resource_id'] = Variable<String>(resourceId);
    map['activity_code'] = Variable<String>(activityCode);
    if (!nullToAbsent || gameId != null) {
      map['game_id'] = Variable<String>(gameId);
    }
    if (!nullToAbsent || controllerCount != null) {
      map['controller_count'] = Variable<int>(controllerCount);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SessionSegmentsCompanion toCompanion(bool nullToAbsent) {
    return SessionSegmentsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      index: Value(index),
      resourceId: Value(resourceId),
      activityCode: Value(activityCode),
      gameId: gameId == null && nullToAbsent
          ? const Value.absent()
          : Value(gameId),
      controllerCount: controllerCount == null && nullToAbsent
          ? const Value.absent()
          : Value(controllerCount),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      createdAt: Value(createdAt),
    );
  }

  factory SessionSegmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionSegmentRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      index: serializer.fromJson<int>(json['index']),
      resourceId: serializer.fromJson<String>(json['resourceId']),
      activityCode: serializer.fromJson<String>(json['activityCode']),
      gameId: serializer.fromJson<String?>(json['gameId']),
      controllerCount: serializer.fromJson<int?>(json['controllerCount']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'index': serializer.toJson<int>(index),
      'resourceId': serializer.toJson<String>(resourceId),
      'activityCode': serializer.toJson<String>(activityCode),
      'gameId': serializer.toJson<String?>(gameId),
      'controllerCount': serializer.toJson<int?>(controllerCount),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SessionSegmentRow copyWith({
    String? id,
    String? sessionId,
    int? index,
    String? resourceId,
    String? activityCode,
    Value<String?> gameId = const Value.absent(),
    Value<int?> controllerCount = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    DateTime? createdAt,
  }) => SessionSegmentRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    index: index ?? this.index,
    resourceId: resourceId ?? this.resourceId,
    activityCode: activityCode ?? this.activityCode,
    gameId: gameId.present ? gameId.value : this.gameId,
    controllerCount: controllerCount.present
        ? controllerCount.value
        : this.controllerCount,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  SessionSegmentRow copyWithCompanion(SessionSegmentsCompanion data) {
    return SessionSegmentRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      index: data.index.present ? data.index.value : this.index,
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
      activityCode: data.activityCode.present
          ? data.activityCode.value
          : this.activityCode,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      controllerCount: data.controllerCount.present
          ? data.controllerCount.value
          : this.controllerCount,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionSegmentRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('index: $index, ')
          ..write('resourceId: $resourceId, ')
          ..write('activityCode: $activityCode, ')
          ..write('gameId: $gameId, ')
          ..write('controllerCount: $controllerCount, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    index,
    resourceId,
    activityCode,
    gameId,
    controllerCount,
    startedAt,
    endedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionSegmentRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.index == this.index &&
          other.resourceId == this.resourceId &&
          other.activityCode == this.activityCode &&
          other.gameId == this.gameId &&
          other.controllerCount == this.controllerCount &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.createdAt == this.createdAt);
}

class SessionSegmentsCompanion extends UpdateCompanion<SessionSegmentRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> index;
  final Value<String> resourceId;
  final Value<String> activityCode;
  final Value<String?> gameId;
  final Value<int?> controllerCount;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SessionSegmentsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.index = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.activityCode = const Value.absent(),
    this.gameId = const Value.absent(),
    this.controllerCount = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionSegmentsCompanion.insert({
    required String id,
    required String sessionId,
    required int index,
    required String resourceId,
    required String activityCode,
    this.gameId = const Value.absent(),
    this.controllerCount = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       index = Value(index),
       resourceId = Value(resourceId),
       activityCode = Value(activityCode),
       startedAt = Value(startedAt),
       createdAt = Value(createdAt);
  static Insertable<SessionSegmentRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? index,
    Expression<String>? resourceId,
    Expression<String>? activityCode,
    Expression<String>? gameId,
    Expression<int>? controllerCount,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (index != null) 'index': index,
      if (resourceId != null) 'resource_id': resourceId,
      if (activityCode != null) 'activity_code': activityCode,
      if (gameId != null) 'game_id': gameId,
      if (controllerCount != null) 'controller_count': controllerCount,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? index,
    Value<String>? resourceId,
    Value<String>? activityCode,
    Value<String?>? gameId,
    Value<int?>? controllerCount,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SessionSegmentsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      index: index ?? this.index,
      resourceId: resourceId ?? this.resourceId,
      activityCode: activityCode ?? this.activityCode,
      gameId: gameId ?? this.gameId,
      controllerCount: controllerCount ?? this.controllerCount,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (index.present) {
      map['index'] = Variable<int>(index.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (activityCode.present) {
      map['activity_code'] = Variable<String>(activityCode.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (controllerCount.present) {
      map['controller_count'] = Variable<int>(controllerCount.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('index: $index, ')
          ..write('resourceId: $resourceId, ')
          ..write('activityCode: $activityCode, ')
          ..write('gameId: $gameId, ')
          ..write('controllerCount: $controllerCount, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionExtensionsTable extends SessionExtensions
    with TableInfo<$SessionExtensionsTable, SessionExtensionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionExtensionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedMinutesMeta = const VerificationMeta(
    'addedMinutes',
  );
  @override
  late final GeneratedColumn<int> addedMinutes = GeneratedColumn<int>(
    'added_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _oldEndAtMeta = const VerificationMeta(
    'oldEndAt',
  );
  @override
  late final GeneratedColumn<DateTime> oldEndAt = GeneratedColumn<DateTime>(
    'old_end_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _newEndAtMeta = const VerificationMeta(
    'newEndAt',
  );
  @override
  late final GeneratedColumn<DateTime> newEndAt = GeneratedColumn<DateTime>(
    'new_end_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAmountPaiseMeta = const VerificationMeta(
    'addedAmountPaise',
  );
  @override
  late final GeneratedColumn<int> addedAmountPaise = GeneratedColumn<int>(
    'added_amount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    addedMinutes,
    oldEndAt,
    newEndAt,
    addedAmountPaise,
    reason,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_extensions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionExtensionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('added_minutes')) {
      context.handle(
        _addedMinutesMeta,
        addedMinutes.isAcceptableOrUnknown(
          data['added_minutes']!,
          _addedMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addedMinutesMeta);
    }
    if (data.containsKey('old_end_at')) {
      context.handle(
        _oldEndAtMeta,
        oldEndAt.isAcceptableOrUnknown(data['old_end_at']!, _oldEndAtMeta),
      );
    } else if (isInserting) {
      context.missing(_oldEndAtMeta);
    }
    if (data.containsKey('new_end_at')) {
      context.handle(
        _newEndAtMeta,
        newEndAt.isAcceptableOrUnknown(data['new_end_at']!, _newEndAtMeta),
      );
    } else if (isInserting) {
      context.missing(_newEndAtMeta);
    }
    if (data.containsKey('added_amount_paise')) {
      context.handle(
        _addedAmountPaiseMeta,
        addedAmountPaise.isAcceptableOrUnknown(
          data['added_amount_paise']!,
          _addedAmountPaiseMeta,
        ),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionExtensionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionExtensionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      addedMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_minutes'],
      )!,
      oldEndAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}old_end_at'],
      )!,
      newEndAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}new_end_at'],
      )!,
      addedAmountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_amount_paise'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SessionExtensionsTable createAlias(String alias) {
    return $SessionExtensionsTable(attachedDatabase, alias);
  }
}

class SessionExtensionRow extends DataClass
    implements Insertable<SessionExtensionRow> {
  final String id;
  final String sessionId;
  final int addedMinutes;
  final DateTime oldEndAt;
  final DateTime newEndAt;
  final int addedAmountPaise;
  final String? reason;
  final DateTime createdAt;
  const SessionExtensionRow({
    required this.id,
    required this.sessionId,
    required this.addedMinutes,
    required this.oldEndAt,
    required this.newEndAt,
    required this.addedAmountPaise,
    this.reason,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['added_minutes'] = Variable<int>(addedMinutes);
    map['old_end_at'] = Variable<DateTime>(oldEndAt);
    map['new_end_at'] = Variable<DateTime>(newEndAt);
    map['added_amount_paise'] = Variable<int>(addedAmountPaise);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SessionExtensionsCompanion toCompanion(bool nullToAbsent) {
    return SessionExtensionsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      addedMinutes: Value(addedMinutes),
      oldEndAt: Value(oldEndAt),
      newEndAt: Value(newEndAt),
      addedAmountPaise: Value(addedAmountPaise),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      createdAt: Value(createdAt),
    );
  }

  factory SessionExtensionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionExtensionRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      addedMinutes: serializer.fromJson<int>(json['addedMinutes']),
      oldEndAt: serializer.fromJson<DateTime>(json['oldEndAt']),
      newEndAt: serializer.fromJson<DateTime>(json['newEndAt']),
      addedAmountPaise: serializer.fromJson<int>(json['addedAmountPaise']),
      reason: serializer.fromJson<String?>(json['reason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'addedMinutes': serializer.toJson<int>(addedMinutes),
      'oldEndAt': serializer.toJson<DateTime>(oldEndAt),
      'newEndAt': serializer.toJson<DateTime>(newEndAt),
      'addedAmountPaise': serializer.toJson<int>(addedAmountPaise),
      'reason': serializer.toJson<String?>(reason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SessionExtensionRow copyWith({
    String? id,
    String? sessionId,
    int? addedMinutes,
    DateTime? oldEndAt,
    DateTime? newEndAt,
    int? addedAmountPaise,
    Value<String?> reason = const Value.absent(),
    DateTime? createdAt,
  }) => SessionExtensionRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    addedMinutes: addedMinutes ?? this.addedMinutes,
    oldEndAt: oldEndAt ?? this.oldEndAt,
    newEndAt: newEndAt ?? this.newEndAt,
    addedAmountPaise: addedAmountPaise ?? this.addedAmountPaise,
    reason: reason.present ? reason.value : this.reason,
    createdAt: createdAt ?? this.createdAt,
  );
  SessionExtensionRow copyWithCompanion(SessionExtensionsCompanion data) {
    return SessionExtensionRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      addedMinutes: data.addedMinutes.present
          ? data.addedMinutes.value
          : this.addedMinutes,
      oldEndAt: data.oldEndAt.present ? data.oldEndAt.value : this.oldEndAt,
      newEndAt: data.newEndAt.present ? data.newEndAt.value : this.newEndAt,
      addedAmountPaise: data.addedAmountPaise.present
          ? data.addedAmountPaise.value
          : this.addedAmountPaise,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionExtensionRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('addedMinutes: $addedMinutes, ')
          ..write('oldEndAt: $oldEndAt, ')
          ..write('newEndAt: $newEndAt, ')
          ..write('addedAmountPaise: $addedAmountPaise, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    addedMinutes,
    oldEndAt,
    newEndAt,
    addedAmountPaise,
    reason,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionExtensionRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.addedMinutes == this.addedMinutes &&
          other.oldEndAt == this.oldEndAt &&
          other.newEndAt == this.newEndAt &&
          other.addedAmountPaise == this.addedAmountPaise &&
          other.reason == this.reason &&
          other.createdAt == this.createdAt);
}

class SessionExtensionsCompanion extends UpdateCompanion<SessionExtensionRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> addedMinutes;
  final Value<DateTime> oldEndAt;
  final Value<DateTime> newEndAt;
  final Value<int> addedAmountPaise;
  final Value<String?> reason;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SessionExtensionsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.addedMinutes = const Value.absent(),
    this.oldEndAt = const Value.absent(),
    this.newEndAt = const Value.absent(),
    this.addedAmountPaise = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionExtensionsCompanion.insert({
    required String id,
    required String sessionId,
    required int addedMinutes,
    required DateTime oldEndAt,
    required DateTime newEndAt,
    this.addedAmountPaise = const Value.absent(),
    this.reason = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       addedMinutes = Value(addedMinutes),
       oldEndAt = Value(oldEndAt),
       newEndAt = Value(newEndAt),
       createdAt = Value(createdAt);
  static Insertable<SessionExtensionRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? addedMinutes,
    Expression<DateTime>? oldEndAt,
    Expression<DateTime>? newEndAt,
    Expression<int>? addedAmountPaise,
    Expression<String>? reason,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (addedMinutes != null) 'added_minutes': addedMinutes,
      if (oldEndAt != null) 'old_end_at': oldEndAt,
      if (newEndAt != null) 'new_end_at': newEndAt,
      if (addedAmountPaise != null) 'added_amount_paise': addedAmountPaise,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionExtensionsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? addedMinutes,
    Value<DateTime>? oldEndAt,
    Value<DateTime>? newEndAt,
    Value<int>? addedAmountPaise,
    Value<String?>? reason,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SessionExtensionsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      addedMinutes: addedMinutes ?? this.addedMinutes,
      oldEndAt: oldEndAt ?? this.oldEndAt,
      newEndAt: newEndAt ?? this.newEndAt,
      addedAmountPaise: addedAmountPaise ?? this.addedAmountPaise,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (addedMinutes.present) {
      map['added_minutes'] = Variable<int>(addedMinutes.value);
    }
    if (oldEndAt.present) {
      map['old_end_at'] = Variable<DateTime>(oldEndAt.value);
    }
    if (newEndAt.present) {
      map['new_end_at'] = Variable<DateTime>(newEndAt.value);
    }
    if (addedAmountPaise.present) {
      map['added_amount_paise'] = Variable<int>(addedAmountPaise.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionExtensionsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('addedMinutes: $addedMinutes, ')
          ..write('oldEndAt: $oldEndAt, ')
          ..write('newEndAt: $newEndAt, ')
          ..write('addedAmountPaise: $addedAmountPaise, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionChargesTable extends SessionCharges
    with TableInfo<$SessionChargesTable, SessionChargeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionChargesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<String> segmentId = GeneratedColumn<String>(
    'segment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _segmentIndexMeta = const VerificationMeta(
    'segmentIndex',
  );
  @override
  late final GeneratedColumn<int> segmentIndex = GeneratedColumn<int>(
    'segment_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bandCodeMeta = const VerificationMeta(
    'bandCode',
  );
  @override
  late final GeneratedColumn<String> bandCode = GeneratedColumn<String>(
    'band_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityCodeMeta = const VerificationMeta(
    'activityCode',
  );
  @override
  late final GeneratedColumn<String> activityCode = GeneratedColumn<String>(
    'activity_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _controllerCountMeta = const VerificationMeta(
    'controllerCount',
  );
  @override
  late final GeneratedColumn<int> controllerCount = GeneratedColumn<int>(
    'controller_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _segmentStartMeta = const VerificationMeta(
    'segmentStart',
  );
  @override
  late final GeneratedColumn<DateTime> segmentStart = GeneratedColumn<DateTime>(
    'segment_start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _segmentEndMeta = const VerificationMeta(
    'segmentEnd',
  );
  @override
  late final GeneratedColumn<DateTime> segmentEnd = GeneratedColumn<DateTime>(
    'segment_end',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playedMinutesMeta = const VerificationMeta(
    'playedMinutes',
  );
  @override
  late final GeneratedColumn<int> playedMinutes = GeneratedColumn<int>(
    'played_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _billedMinutesMeta = const VerificationMeta(
    'billedMinutes',
  );
  @override
  late final GeneratedColumn<int> billedMinutes = GeneratedColumn<int>(
    'billed_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMinutesMeta = const VerificationMeta(
    'unitMinutes',
  );
  @override
  late final GeneratedColumn<int> unitMinutes = GeneratedColumn<int>(
    'unit_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPricePaiseMeta = const VerificationMeta(
    'unitPricePaise',
  );
  @override
  late final GeneratedColumn<int> unitPricePaise = GeneratedColumn<int>(
    'unit_price_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountPaiseMeta = const VerificationMeta(
    'amountPaise',
  );
  @override
  late final GeneratedColumn<int> amountPaise = GeneratedColumn<int>(
    'amount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    segmentId,
    segmentIndex,
    bandCode,
    activityCode,
    resourceId,
    controllerCount,
    segmentStart,
    segmentEnd,
    playedMinutes,
    billedMinutes,
    unitMinutes,
    unitPricePaise,
    amountPaise,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_charges';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionChargeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    }
    if (data.containsKey('segment_index')) {
      context.handle(
        _segmentIndexMeta,
        segmentIndex.isAcceptableOrUnknown(
          data['segment_index']!,
          _segmentIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_segmentIndexMeta);
    }
    if (data.containsKey('band_code')) {
      context.handle(
        _bandCodeMeta,
        bandCode.isAcceptableOrUnknown(data['band_code']!, _bandCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_bandCodeMeta);
    }
    if (data.containsKey('activity_code')) {
      context.handle(
        _activityCodeMeta,
        activityCode.isAcceptableOrUnknown(
          data['activity_code']!,
          _activityCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityCodeMeta);
    }
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    }
    if (data.containsKey('controller_count')) {
      context.handle(
        _controllerCountMeta,
        controllerCount.isAcceptableOrUnknown(
          data['controller_count']!,
          _controllerCountMeta,
        ),
      );
    }
    if (data.containsKey('segment_start')) {
      context.handle(
        _segmentStartMeta,
        segmentStart.isAcceptableOrUnknown(
          data['segment_start']!,
          _segmentStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_segmentStartMeta);
    }
    if (data.containsKey('segment_end')) {
      context.handle(
        _segmentEndMeta,
        segmentEnd.isAcceptableOrUnknown(data['segment_end']!, _segmentEndMeta),
      );
    } else if (isInserting) {
      context.missing(_segmentEndMeta);
    }
    if (data.containsKey('played_minutes')) {
      context.handle(
        _playedMinutesMeta,
        playedMinutes.isAcceptableOrUnknown(
          data['played_minutes']!,
          _playedMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playedMinutesMeta);
    }
    if (data.containsKey('billed_minutes')) {
      context.handle(
        _billedMinutesMeta,
        billedMinutes.isAcceptableOrUnknown(
          data['billed_minutes']!,
          _billedMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_billedMinutesMeta);
    }
    if (data.containsKey('unit_minutes')) {
      context.handle(
        _unitMinutesMeta,
        unitMinutes.isAcceptableOrUnknown(
          data['unit_minutes']!,
          _unitMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitMinutesMeta);
    }
    if (data.containsKey('unit_price_paise')) {
      context.handle(
        _unitPricePaiseMeta,
        unitPricePaise.isAcceptableOrUnknown(
          data['unit_price_paise']!,
          _unitPricePaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unitPricePaiseMeta);
    }
    if (data.containsKey('amount_paise')) {
      context.handle(
        _amountPaiseMeta,
        amountPaise.isAcceptableOrUnknown(
          data['amount_paise']!,
          _amountPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPaiseMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionChargeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionChargeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_id'],
      ),
      segmentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_index'],
      )!,
      bandCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}band_code'],
      )!,
      activityCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_code'],
      )!,
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      ),
      controllerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}controller_count'],
      ),
      segmentStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}segment_start'],
      )!,
      segmentEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}segment_end'],
      )!,
      playedMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}played_minutes'],
      )!,
      billedMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}billed_minutes'],
      )!,
      unitMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_minutes'],
      )!,
      unitPricePaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_paise'],
      )!,
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
    );
  }

  @override
  $SessionChargesTable createAlias(String alias) {
    return $SessionChargesTable(attachedDatabase, alias);
  }
}

class SessionChargeRow extends DataClass
    implements Insertable<SessionChargeRow> {
  final String id;
  final String sessionId;
  final String? segmentId;
  final int segmentIndex;
  final String bandCode;
  final String activityCode;
  final String? resourceId;
  final int? controllerCount;
  final DateTime segmentStart;
  final DateTime segmentEnd;
  final int playedMinutes;
  final int billedMinutes;
  final int unitMinutes;
  final int unitPricePaise;
  final int amountPaise;
  const SessionChargeRow({
    required this.id,
    required this.sessionId,
    this.segmentId,
    required this.segmentIndex,
    required this.bandCode,
    required this.activityCode,
    this.resourceId,
    this.controllerCount,
    required this.segmentStart,
    required this.segmentEnd,
    required this.playedMinutes,
    required this.billedMinutes,
    required this.unitMinutes,
    required this.unitPricePaise,
    required this.amountPaise,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || segmentId != null) {
      map['segment_id'] = Variable<String>(segmentId);
    }
    map['segment_index'] = Variable<int>(segmentIndex);
    map['band_code'] = Variable<String>(bandCode);
    map['activity_code'] = Variable<String>(activityCode);
    if (!nullToAbsent || resourceId != null) {
      map['resource_id'] = Variable<String>(resourceId);
    }
    if (!nullToAbsent || controllerCount != null) {
      map['controller_count'] = Variable<int>(controllerCount);
    }
    map['segment_start'] = Variable<DateTime>(segmentStart);
    map['segment_end'] = Variable<DateTime>(segmentEnd);
    map['played_minutes'] = Variable<int>(playedMinutes);
    map['billed_minutes'] = Variable<int>(billedMinutes);
    map['unit_minutes'] = Variable<int>(unitMinutes);
    map['unit_price_paise'] = Variable<int>(unitPricePaise);
    map['amount_paise'] = Variable<int>(amountPaise);
    return map;
  }

  SessionChargesCompanion toCompanion(bool nullToAbsent) {
    return SessionChargesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      segmentId: segmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(segmentId),
      segmentIndex: Value(segmentIndex),
      bandCode: Value(bandCode),
      activityCode: Value(activityCode),
      resourceId: resourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(resourceId),
      controllerCount: controllerCount == null && nullToAbsent
          ? const Value.absent()
          : Value(controllerCount),
      segmentStart: Value(segmentStart),
      segmentEnd: Value(segmentEnd),
      playedMinutes: Value(playedMinutes),
      billedMinutes: Value(billedMinutes),
      unitMinutes: Value(unitMinutes),
      unitPricePaise: Value(unitPricePaise),
      amountPaise: Value(amountPaise),
    );
  }

  factory SessionChargeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionChargeRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      segmentId: serializer.fromJson<String?>(json['segmentId']),
      segmentIndex: serializer.fromJson<int>(json['segmentIndex']),
      bandCode: serializer.fromJson<String>(json['bandCode']),
      activityCode: serializer.fromJson<String>(json['activityCode']),
      resourceId: serializer.fromJson<String?>(json['resourceId']),
      controllerCount: serializer.fromJson<int?>(json['controllerCount']),
      segmentStart: serializer.fromJson<DateTime>(json['segmentStart']),
      segmentEnd: serializer.fromJson<DateTime>(json['segmentEnd']),
      playedMinutes: serializer.fromJson<int>(json['playedMinutes']),
      billedMinutes: serializer.fromJson<int>(json['billedMinutes']),
      unitMinutes: serializer.fromJson<int>(json['unitMinutes']),
      unitPricePaise: serializer.fromJson<int>(json['unitPricePaise']),
      amountPaise: serializer.fromJson<int>(json['amountPaise']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'segmentId': serializer.toJson<String?>(segmentId),
      'segmentIndex': serializer.toJson<int>(segmentIndex),
      'bandCode': serializer.toJson<String>(bandCode),
      'activityCode': serializer.toJson<String>(activityCode),
      'resourceId': serializer.toJson<String?>(resourceId),
      'controllerCount': serializer.toJson<int?>(controllerCount),
      'segmentStart': serializer.toJson<DateTime>(segmentStart),
      'segmentEnd': serializer.toJson<DateTime>(segmentEnd),
      'playedMinutes': serializer.toJson<int>(playedMinutes),
      'billedMinutes': serializer.toJson<int>(billedMinutes),
      'unitMinutes': serializer.toJson<int>(unitMinutes),
      'unitPricePaise': serializer.toJson<int>(unitPricePaise),
      'amountPaise': serializer.toJson<int>(amountPaise),
    };
  }

  SessionChargeRow copyWith({
    String? id,
    String? sessionId,
    Value<String?> segmentId = const Value.absent(),
    int? segmentIndex,
    String? bandCode,
    String? activityCode,
    Value<String?> resourceId = const Value.absent(),
    Value<int?> controllerCount = const Value.absent(),
    DateTime? segmentStart,
    DateTime? segmentEnd,
    int? playedMinutes,
    int? billedMinutes,
    int? unitMinutes,
    int? unitPricePaise,
    int? amountPaise,
  }) => SessionChargeRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    segmentId: segmentId.present ? segmentId.value : this.segmentId,
    segmentIndex: segmentIndex ?? this.segmentIndex,
    bandCode: bandCode ?? this.bandCode,
    activityCode: activityCode ?? this.activityCode,
    resourceId: resourceId.present ? resourceId.value : this.resourceId,
    controllerCount: controllerCount.present
        ? controllerCount.value
        : this.controllerCount,
    segmentStart: segmentStart ?? this.segmentStart,
    segmentEnd: segmentEnd ?? this.segmentEnd,
    playedMinutes: playedMinutes ?? this.playedMinutes,
    billedMinutes: billedMinutes ?? this.billedMinutes,
    unitMinutes: unitMinutes ?? this.unitMinutes,
    unitPricePaise: unitPricePaise ?? this.unitPricePaise,
    amountPaise: amountPaise ?? this.amountPaise,
  );
  SessionChargeRow copyWithCompanion(SessionChargesCompanion data) {
    return SessionChargeRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      segmentIndex: data.segmentIndex.present
          ? data.segmentIndex.value
          : this.segmentIndex,
      bandCode: data.bandCode.present ? data.bandCode.value : this.bandCode,
      activityCode: data.activityCode.present
          ? data.activityCode.value
          : this.activityCode,
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
      controllerCount: data.controllerCount.present
          ? data.controllerCount.value
          : this.controllerCount,
      segmentStart: data.segmentStart.present
          ? data.segmentStart.value
          : this.segmentStart,
      segmentEnd: data.segmentEnd.present
          ? data.segmentEnd.value
          : this.segmentEnd,
      playedMinutes: data.playedMinutes.present
          ? data.playedMinutes.value
          : this.playedMinutes,
      billedMinutes: data.billedMinutes.present
          ? data.billedMinutes.value
          : this.billedMinutes,
      unitMinutes: data.unitMinutes.present
          ? data.unitMinutes.value
          : this.unitMinutes,
      unitPricePaise: data.unitPricePaise.present
          ? data.unitPricePaise.value
          : this.unitPricePaise,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionChargeRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('segmentId: $segmentId, ')
          ..write('segmentIndex: $segmentIndex, ')
          ..write('bandCode: $bandCode, ')
          ..write('activityCode: $activityCode, ')
          ..write('resourceId: $resourceId, ')
          ..write('controllerCount: $controllerCount, ')
          ..write('segmentStart: $segmentStart, ')
          ..write('segmentEnd: $segmentEnd, ')
          ..write('playedMinutes: $playedMinutes, ')
          ..write('billedMinutes: $billedMinutes, ')
          ..write('unitMinutes: $unitMinutes, ')
          ..write('unitPricePaise: $unitPricePaise, ')
          ..write('amountPaise: $amountPaise')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    segmentId,
    segmentIndex,
    bandCode,
    activityCode,
    resourceId,
    controllerCount,
    segmentStart,
    segmentEnd,
    playedMinutes,
    billedMinutes,
    unitMinutes,
    unitPricePaise,
    amountPaise,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionChargeRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.segmentId == this.segmentId &&
          other.segmentIndex == this.segmentIndex &&
          other.bandCode == this.bandCode &&
          other.activityCode == this.activityCode &&
          other.resourceId == this.resourceId &&
          other.controllerCount == this.controllerCount &&
          other.segmentStart == this.segmentStart &&
          other.segmentEnd == this.segmentEnd &&
          other.playedMinutes == this.playedMinutes &&
          other.billedMinutes == this.billedMinutes &&
          other.unitMinutes == this.unitMinutes &&
          other.unitPricePaise == this.unitPricePaise &&
          other.amountPaise == this.amountPaise);
}

class SessionChargesCompanion extends UpdateCompanion<SessionChargeRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String?> segmentId;
  final Value<int> segmentIndex;
  final Value<String> bandCode;
  final Value<String> activityCode;
  final Value<String?> resourceId;
  final Value<int?> controllerCount;
  final Value<DateTime> segmentStart;
  final Value<DateTime> segmentEnd;
  final Value<int> playedMinutes;
  final Value<int> billedMinutes;
  final Value<int> unitMinutes;
  final Value<int> unitPricePaise;
  final Value<int> amountPaise;
  final Value<int> rowid;
  const SessionChargesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.segmentId = const Value.absent(),
    this.segmentIndex = const Value.absent(),
    this.bandCode = const Value.absent(),
    this.activityCode = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.controllerCount = const Value.absent(),
    this.segmentStart = const Value.absent(),
    this.segmentEnd = const Value.absent(),
    this.playedMinutes = const Value.absent(),
    this.billedMinutes = const Value.absent(),
    this.unitMinutes = const Value.absent(),
    this.unitPricePaise = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionChargesCompanion.insert({
    required String id,
    required String sessionId,
    this.segmentId = const Value.absent(),
    required int segmentIndex,
    required String bandCode,
    required String activityCode,
    this.resourceId = const Value.absent(),
    this.controllerCount = const Value.absent(),
    required DateTime segmentStart,
    required DateTime segmentEnd,
    required int playedMinutes,
    required int billedMinutes,
    required int unitMinutes,
    required int unitPricePaise,
    required int amountPaise,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       segmentIndex = Value(segmentIndex),
       bandCode = Value(bandCode),
       activityCode = Value(activityCode),
       segmentStart = Value(segmentStart),
       segmentEnd = Value(segmentEnd),
       playedMinutes = Value(playedMinutes),
       billedMinutes = Value(billedMinutes),
       unitMinutes = Value(unitMinutes),
       unitPricePaise = Value(unitPricePaise),
       amountPaise = Value(amountPaise);
  static Insertable<SessionChargeRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? segmentId,
    Expression<int>? segmentIndex,
    Expression<String>? bandCode,
    Expression<String>? activityCode,
    Expression<String>? resourceId,
    Expression<int>? controllerCount,
    Expression<DateTime>? segmentStart,
    Expression<DateTime>? segmentEnd,
    Expression<int>? playedMinutes,
    Expression<int>? billedMinutes,
    Expression<int>? unitMinutes,
    Expression<int>? unitPricePaise,
    Expression<int>? amountPaise,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (segmentId != null) 'segment_id': segmentId,
      if (segmentIndex != null) 'segment_index': segmentIndex,
      if (bandCode != null) 'band_code': bandCode,
      if (activityCode != null) 'activity_code': activityCode,
      if (resourceId != null) 'resource_id': resourceId,
      if (controllerCount != null) 'controller_count': controllerCount,
      if (segmentStart != null) 'segment_start': segmentStart,
      if (segmentEnd != null) 'segment_end': segmentEnd,
      if (playedMinutes != null) 'played_minutes': playedMinutes,
      if (billedMinutes != null) 'billed_minutes': billedMinutes,
      if (unitMinutes != null) 'unit_minutes': unitMinutes,
      if (unitPricePaise != null) 'unit_price_paise': unitPricePaise,
      if (amountPaise != null) 'amount_paise': amountPaise,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionChargesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String?>? segmentId,
    Value<int>? segmentIndex,
    Value<String>? bandCode,
    Value<String>? activityCode,
    Value<String?>? resourceId,
    Value<int?>? controllerCount,
    Value<DateTime>? segmentStart,
    Value<DateTime>? segmentEnd,
    Value<int>? playedMinutes,
    Value<int>? billedMinutes,
    Value<int>? unitMinutes,
    Value<int>? unitPricePaise,
    Value<int>? amountPaise,
    Value<int>? rowid,
  }) {
    return SessionChargesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      segmentId: segmentId ?? this.segmentId,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      bandCode: bandCode ?? this.bandCode,
      activityCode: activityCode ?? this.activityCode,
      resourceId: resourceId ?? this.resourceId,
      controllerCount: controllerCount ?? this.controllerCount,
      segmentStart: segmentStart ?? this.segmentStart,
      segmentEnd: segmentEnd ?? this.segmentEnd,
      playedMinutes: playedMinutes ?? this.playedMinutes,
      billedMinutes: billedMinutes ?? this.billedMinutes,
      unitMinutes: unitMinutes ?? this.unitMinutes,
      unitPricePaise: unitPricePaise ?? this.unitPricePaise,
      amountPaise: amountPaise ?? this.amountPaise,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<String>(segmentId.value);
    }
    if (segmentIndex.present) {
      map['segment_index'] = Variable<int>(segmentIndex.value);
    }
    if (bandCode.present) {
      map['band_code'] = Variable<String>(bandCode.value);
    }
    if (activityCode.present) {
      map['activity_code'] = Variable<String>(activityCode.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (controllerCount.present) {
      map['controller_count'] = Variable<int>(controllerCount.value);
    }
    if (segmentStart.present) {
      map['segment_start'] = Variable<DateTime>(segmentStart.value);
    }
    if (segmentEnd.present) {
      map['segment_end'] = Variable<DateTime>(segmentEnd.value);
    }
    if (playedMinutes.present) {
      map['played_minutes'] = Variable<int>(playedMinutes.value);
    }
    if (billedMinutes.present) {
      map['billed_minutes'] = Variable<int>(billedMinutes.value);
    }
    if (unitMinutes.present) {
      map['unit_minutes'] = Variable<int>(unitMinutes.value);
    }
    if (unitPricePaise.present) {
      map['unit_price_paise'] = Variable<int>(unitPricePaise.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionChargesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('segmentId: $segmentId, ')
          ..write('segmentIndex: $segmentIndex, ')
          ..write('bandCode: $bandCode, ')
          ..write('activityCode: $activityCode, ')
          ..write('resourceId: $resourceId, ')
          ..write('controllerCount: $controllerCount, ')
          ..write('segmentStart: $segmentStart, ')
          ..write('segmentEnd: $segmentEnd, ')
          ..write('playedMinutes: $playedMinutes, ')
          ..write('billedMinutes: $billedMinutes, ')
          ..write('unitMinutes: $unitMinutes, ')
          ..write('unitPricePaise: $unitPricePaise, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PaymentsTable extends Payments
    with TableInfo<$PaymentsTable, PaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountPaiseMeta = const VerificationMeta(
    'amountPaise',
  );
  @override
  late final GeneratedColumn<int> amountPaise = GeneratedColumn<int>(
    'amount_paise',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isRefundMeta = const VerificationMeta(
    'isRefund',
  );
  @override
  late final GeneratedColumn<bool> isRefund = GeneratedColumn<bool>(
    'is_refund',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_refund" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    amountPaise,
    method,
    isRefund,
    note,
    reason,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PaymentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('amount_paise')) {
      context.handle(
        _amountPaiseMeta,
        amountPaise.isAcceptableOrUnknown(
          data['amount_paise']!,
          _amountPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPaiseMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('is_refund')) {
      context.handle(
        _isRefundMeta,
        isRefund.isAcceptableOrUnknown(data['is_refund']!, _isRefundMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      isRefund: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_refund'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PaymentsTable createAlias(String alias) {
    return $PaymentsTable(attachedDatabase, alias);
  }
}

class PaymentRow extends DataClass implements Insertable<PaymentRow> {
  final String id;
  final String sessionId;
  final int amountPaise;
  final String method;
  final bool isRefund;
  final String? note;
  final String? reason;
  final DateTime createdAt;
  const PaymentRow({
    required this.id,
    required this.sessionId,
    required this.amountPaise,
    required this.method,
    required this.isRefund,
    this.note,
    this.reason,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['amount_paise'] = Variable<int>(amountPaise);
    map['method'] = Variable<String>(method);
    map['is_refund'] = Variable<bool>(isRefund);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      amountPaise: Value(amountPaise),
      method: Value(method),
      isRefund: Value(isRefund),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      createdAt: Value(createdAt),
    );
  }

  factory PaymentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      amountPaise: serializer.fromJson<int>(json['amountPaise']),
      method: serializer.fromJson<String>(json['method']),
      isRefund: serializer.fromJson<bool>(json['isRefund']),
      note: serializer.fromJson<String?>(json['note']),
      reason: serializer.fromJson<String?>(json['reason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'amountPaise': serializer.toJson<int>(amountPaise),
      'method': serializer.toJson<String>(method),
      'isRefund': serializer.toJson<bool>(isRefund),
      'note': serializer.toJson<String?>(note),
      'reason': serializer.toJson<String?>(reason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PaymentRow copyWith({
    String? id,
    String? sessionId,
    int? amountPaise,
    String? method,
    bool? isRefund,
    Value<String?> note = const Value.absent(),
    Value<String?> reason = const Value.absent(),
    DateTime? createdAt,
  }) => PaymentRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    amountPaise: amountPaise ?? this.amountPaise,
    method: method ?? this.method,
    isRefund: isRefund ?? this.isRefund,
    note: note.present ? note.value : this.note,
    reason: reason.present ? reason.value : this.reason,
    createdAt: createdAt ?? this.createdAt,
  );
  PaymentRow copyWithCompanion(PaymentsCompanion data) {
    return PaymentRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
      method: data.method.present ? data.method.value : this.method,
      isRefund: data.isRefund.present ? data.isRefund.value : this.isRefund,
      note: data.note.present ? data.note.value : this.note,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('method: $method, ')
          ..write('isRefund: $isRefund, ')
          ..write('note: $note, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    amountPaise,
    method,
    isRefund,
    note,
    reason,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.amountPaise == this.amountPaise &&
          other.method == this.method &&
          other.isRefund == this.isRefund &&
          other.note == this.note &&
          other.reason == this.reason &&
          other.createdAt == this.createdAt);
}

class PaymentsCompanion extends UpdateCompanion<PaymentRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<int> amountPaise;
  final Value<String> method;
  final Value<bool> isRefund;
  final Value<String?> note;
  final Value<String?> reason;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PaymentsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.method = const Value.absent(),
    this.isRefund = const Value.absent(),
    this.note = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentsCompanion.insert({
    required String id,
    required String sessionId,
    required int amountPaise,
    required String method,
    this.isRefund = const Value.absent(),
    this.note = const Value.absent(),
    this.reason = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       amountPaise = Value(amountPaise),
       method = Value(method),
       createdAt = Value(createdAt);
  static Insertable<PaymentRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<int>? amountPaise,
    Expression<String>? method,
    Expression<bool>? isRefund,
    Expression<String>? note,
    Expression<String>? reason,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (amountPaise != null) 'amount_paise': amountPaise,
      if (method != null) 'method': method,
      if (isRefund != null) 'is_refund': isRefund,
      if (note != null) 'note': note,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<int>? amountPaise,
    Value<String>? method,
    Value<bool>? isRefund,
    Value<String?>? note,
    Value<String?>? reason,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PaymentsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      amountPaise: amountPaise ?? this.amountPaise,
      method: method ?? this.method,
      isRefund: isRefund ?? this.isRefund,
      note: note ?? this.note,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (isRefund.present) {
      map['is_refund'] = Variable<bool>(isRefund.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('method: $method, ')
          ..write('isRefund: $isRefund, ')
          ..write('note: $note, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookingsTable extends Bookings
    with TableInfo<$BookingsTable, BookingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activityCodeMeta = const VerificationMeta(
    'activityCode',
  );
  @override
  late final GeneratedColumn<String> activityCode = GeneratedColumn<String>(
    'activity_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resourceIdMeta = const VerificationMeta(
    'resourceId',
  );
  @override
  late final GeneratedColumn<String> resourceId = GeneratedColumn<String>(
    'resource_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledStartMeta = const VerificationMeta(
    'scheduledStart',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledStart =
      GeneratedColumn<DateTime>(
        'scheduled_start',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _scheduledEndMeta = const VerificationMeta(
    'scheduledEnd',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledEnd = GeneratedColumn<DateTime>(
    'scheduled_end',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playersRequiredMeta = const VerificationMeta(
    'playersRequired',
  );
  @override
  late final GeneratedColumn<int> playersRequired = GeneratedColumn<int>(
    'players_required',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _controllerRequirementMeta =
      const VerificationMeta('controllerRequirement');
  @override
  late final GeneratedColumn<int> controllerRequirement = GeneratedColumn<int>(
    'controller_requirement',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partyNameMeta = const VerificationMeta(
    'partyName',
  );
  @override
  late final GeneratedColumn<String> partyName = GeneratedColumn<String>(
    'party_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderStatusMeta = const VerificationMeta(
    'reminderStatus',
  );
  @override
  late final GeneratedColumn<String> reminderStatus = GeneratedColumn<String>(
    'reminder_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('scheduled'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    activityCode,
    gameId,
    resourceId,
    scheduledStart,
    scheduledEnd,
    playersRequired,
    controllerRequirement,
    status,
    partyName,
    phone,
    notes,
    reminderStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookings';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('activity_code')) {
      context.handle(
        _activityCodeMeta,
        activityCode.isAcceptableOrUnknown(
          data['activity_code']!,
          _activityCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityCodeMeta);
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    }
    if (data.containsKey('resource_id')) {
      context.handle(
        _resourceIdMeta,
        resourceId.isAcceptableOrUnknown(data['resource_id']!, _resourceIdMeta),
      );
    }
    if (data.containsKey('scheduled_start')) {
      context.handle(
        _scheduledStartMeta,
        scheduledStart.isAcceptableOrUnknown(
          data['scheduled_start']!,
          _scheduledStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledStartMeta);
    }
    if (data.containsKey('scheduled_end')) {
      context.handle(
        _scheduledEndMeta,
        scheduledEnd.isAcceptableOrUnknown(
          data['scheduled_end']!,
          _scheduledEndMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledEndMeta);
    }
    if (data.containsKey('players_required')) {
      context.handle(
        _playersRequiredMeta,
        playersRequired.isAcceptableOrUnknown(
          data['players_required']!,
          _playersRequiredMeta,
        ),
      );
    }
    if (data.containsKey('controller_requirement')) {
      context.handle(
        _controllerRequirementMeta,
        controllerRequirement.isAcceptableOrUnknown(
          data['controller_requirement']!,
          _controllerRequirementMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('party_name')) {
      context.handle(
        _partyNameMeta,
        partyName.isAcceptableOrUnknown(data['party_name']!, _partyNameMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('reminder_status')) {
      context.handle(
        _reminderStatusMeta,
        reminderStatus.isAcceptableOrUnknown(
          data['reminder_status']!,
          _reminderStatusMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
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
  BookingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      activityCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_code'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      ),
      resourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resource_id'],
      ),
      scheduledStart: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_start'],
      )!,
      scheduledEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_end'],
      )!,
      playersRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}players_required'],
      ),
      controllerRequirement: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}controller_requirement'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      partyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}party_name'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      reminderStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BookingsTable createAlias(String alias) {
    return $BookingsTable(attachedDatabase, alias);
  }
}

class BookingRow extends DataClass implements Insertable<BookingRow> {
  final String id;
  final String? customerId;
  final String activityCode;
  final String? gameId;
  final String? resourceId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final int? playersRequired;
  final int? controllerRequirement;
  final String status;

  /// Walk-in party details when no customer record exists yet (spec §18).
  final String? partyName;
  final String? phone;
  final String? notes;

  /// Whether a device reminder is currently scheduled for this booking.
  final String reminderStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BookingRow({
    required this.id,
    this.customerId,
    required this.activityCode,
    this.gameId,
    this.resourceId,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.playersRequired,
    this.controllerRequirement,
    required this.status,
    this.partyName,
    this.phone,
    this.notes,
    required this.reminderStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    map['activity_code'] = Variable<String>(activityCode);
    if (!nullToAbsent || gameId != null) {
      map['game_id'] = Variable<String>(gameId);
    }
    if (!nullToAbsent || resourceId != null) {
      map['resource_id'] = Variable<String>(resourceId);
    }
    map['scheduled_start'] = Variable<DateTime>(scheduledStart);
    map['scheduled_end'] = Variable<DateTime>(scheduledEnd);
    if (!nullToAbsent || playersRequired != null) {
      map['players_required'] = Variable<int>(playersRequired);
    }
    if (!nullToAbsent || controllerRequirement != null) {
      map['controller_requirement'] = Variable<int>(controllerRequirement);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || partyName != null) {
      map['party_name'] = Variable<String>(partyName);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['reminder_status'] = Variable<String>(reminderStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookingsCompanion toCompanion(bool nullToAbsent) {
    return BookingsCompanion(
      id: Value(id),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      activityCode: Value(activityCode),
      gameId: gameId == null && nullToAbsent
          ? const Value.absent()
          : Value(gameId),
      resourceId: resourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(resourceId),
      scheduledStart: Value(scheduledStart),
      scheduledEnd: Value(scheduledEnd),
      playersRequired: playersRequired == null && nullToAbsent
          ? const Value.absent()
          : Value(playersRequired),
      controllerRequirement: controllerRequirement == null && nullToAbsent
          ? const Value.absent()
          : Value(controllerRequirement),
      status: Value(status),
      partyName: partyName == null && nullToAbsent
          ? const Value.absent()
          : Value(partyName),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      reminderStatus: Value(reminderStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookingRow(
      id: serializer.fromJson<String>(json['id']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      activityCode: serializer.fromJson<String>(json['activityCode']),
      gameId: serializer.fromJson<String?>(json['gameId']),
      resourceId: serializer.fromJson<String?>(json['resourceId']),
      scheduledStart: serializer.fromJson<DateTime>(json['scheduledStart']),
      scheduledEnd: serializer.fromJson<DateTime>(json['scheduledEnd']),
      playersRequired: serializer.fromJson<int?>(json['playersRequired']),
      controllerRequirement: serializer.fromJson<int?>(
        json['controllerRequirement'],
      ),
      status: serializer.fromJson<String>(json['status']),
      partyName: serializer.fromJson<String?>(json['partyName']),
      phone: serializer.fromJson<String?>(json['phone']),
      notes: serializer.fromJson<String?>(json['notes']),
      reminderStatus: serializer.fromJson<String>(json['reminderStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'customerId': serializer.toJson<String?>(customerId),
      'activityCode': serializer.toJson<String>(activityCode),
      'gameId': serializer.toJson<String?>(gameId),
      'resourceId': serializer.toJson<String?>(resourceId),
      'scheduledStart': serializer.toJson<DateTime>(scheduledStart),
      'scheduledEnd': serializer.toJson<DateTime>(scheduledEnd),
      'playersRequired': serializer.toJson<int?>(playersRequired),
      'controllerRequirement': serializer.toJson<int?>(controllerRequirement),
      'status': serializer.toJson<String>(status),
      'partyName': serializer.toJson<String?>(partyName),
      'phone': serializer.toJson<String?>(phone),
      'notes': serializer.toJson<String?>(notes),
      'reminderStatus': serializer.toJson<String>(reminderStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookingRow copyWith({
    String? id,
    Value<String?> customerId = const Value.absent(),
    String? activityCode,
    Value<String?> gameId = const Value.absent(),
    Value<String?> resourceId = const Value.absent(),
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    Value<int?> playersRequired = const Value.absent(),
    Value<int?> controllerRequirement = const Value.absent(),
    String? status,
    Value<String?> partyName = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? reminderStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BookingRow(
    id: id ?? this.id,
    customerId: customerId.present ? customerId.value : this.customerId,
    activityCode: activityCode ?? this.activityCode,
    gameId: gameId.present ? gameId.value : this.gameId,
    resourceId: resourceId.present ? resourceId.value : this.resourceId,
    scheduledStart: scheduledStart ?? this.scheduledStart,
    scheduledEnd: scheduledEnd ?? this.scheduledEnd,
    playersRequired: playersRequired.present
        ? playersRequired.value
        : this.playersRequired,
    controllerRequirement: controllerRequirement.present
        ? controllerRequirement.value
        : this.controllerRequirement,
    status: status ?? this.status,
    partyName: partyName.present ? partyName.value : this.partyName,
    phone: phone.present ? phone.value : this.phone,
    notes: notes.present ? notes.value : this.notes,
    reminderStatus: reminderStatus ?? this.reminderStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookingRow copyWithCompanion(BookingsCompanion data) {
    return BookingRow(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      activityCode: data.activityCode.present
          ? data.activityCode.value
          : this.activityCode,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      resourceId: data.resourceId.present
          ? data.resourceId.value
          : this.resourceId,
      scheduledStart: data.scheduledStart.present
          ? data.scheduledStart.value
          : this.scheduledStart,
      scheduledEnd: data.scheduledEnd.present
          ? data.scheduledEnd.value
          : this.scheduledEnd,
      playersRequired: data.playersRequired.present
          ? data.playersRequired.value
          : this.playersRequired,
      controllerRequirement: data.controllerRequirement.present
          ? data.controllerRequirement.value
          : this.controllerRequirement,
      status: data.status.present ? data.status.value : this.status,
      partyName: data.partyName.present ? data.partyName.value : this.partyName,
      phone: data.phone.present ? data.phone.value : this.phone,
      notes: data.notes.present ? data.notes.value : this.notes,
      reminderStatus: data.reminderStatus.present
          ? data.reminderStatus.value
          : this.reminderStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookingRow(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('activityCode: $activityCode, ')
          ..write('gameId: $gameId, ')
          ..write('resourceId: $resourceId, ')
          ..write('scheduledStart: $scheduledStart, ')
          ..write('scheduledEnd: $scheduledEnd, ')
          ..write('playersRequired: $playersRequired, ')
          ..write('controllerRequirement: $controllerRequirement, ')
          ..write('status: $status, ')
          ..write('partyName: $partyName, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('reminderStatus: $reminderStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    customerId,
    activityCode,
    gameId,
    resourceId,
    scheduledStart,
    scheduledEnd,
    playersRequired,
    controllerRequirement,
    status,
    partyName,
    phone,
    notes,
    reminderStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookingRow &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.activityCode == this.activityCode &&
          other.gameId == this.gameId &&
          other.resourceId == this.resourceId &&
          other.scheduledStart == this.scheduledStart &&
          other.scheduledEnd == this.scheduledEnd &&
          other.playersRequired == this.playersRequired &&
          other.controllerRequirement == this.controllerRequirement &&
          other.status == this.status &&
          other.partyName == this.partyName &&
          other.phone == this.phone &&
          other.notes == this.notes &&
          other.reminderStatus == this.reminderStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BookingsCompanion extends UpdateCompanion<BookingRow> {
  final Value<String> id;
  final Value<String?> customerId;
  final Value<String> activityCode;
  final Value<String?> gameId;
  final Value<String?> resourceId;
  final Value<DateTime> scheduledStart;
  final Value<DateTime> scheduledEnd;
  final Value<int?> playersRequired;
  final Value<int?> controllerRequirement;
  final Value<String> status;
  final Value<String?> partyName;
  final Value<String?> phone;
  final Value<String?> notes;
  final Value<String> reminderStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BookingsCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.activityCode = const Value.absent(),
    this.gameId = const Value.absent(),
    this.resourceId = const Value.absent(),
    this.scheduledStart = const Value.absent(),
    this.scheduledEnd = const Value.absent(),
    this.playersRequired = const Value.absent(),
    this.controllerRequirement = const Value.absent(),
    this.status = const Value.absent(),
    this.partyName = const Value.absent(),
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    this.reminderStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookingsCompanion.insert({
    required String id,
    this.customerId = const Value.absent(),
    required String activityCode,
    this.gameId = const Value.absent(),
    this.resourceId = const Value.absent(),
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
    this.playersRequired = const Value.absent(),
    this.controllerRequirement = const Value.absent(),
    required String status,
    this.partyName = const Value.absent(),
    this.phone = const Value.absent(),
    this.notes = const Value.absent(),
    this.reminderStatus = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       activityCode = Value(activityCode),
       scheduledStart = Value(scheduledStart),
       scheduledEnd = Value(scheduledEnd),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookingRow> custom({
    Expression<String>? id,
    Expression<String>? customerId,
    Expression<String>? activityCode,
    Expression<String>? gameId,
    Expression<String>? resourceId,
    Expression<DateTime>? scheduledStart,
    Expression<DateTime>? scheduledEnd,
    Expression<int>? playersRequired,
    Expression<int>? controllerRequirement,
    Expression<String>? status,
    Expression<String>? partyName,
    Expression<String>? phone,
    Expression<String>? notes,
    Expression<String>? reminderStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (activityCode != null) 'activity_code': activityCode,
      if (gameId != null) 'game_id': gameId,
      if (resourceId != null) 'resource_id': resourceId,
      if (scheduledStart != null) 'scheduled_start': scheduledStart,
      if (scheduledEnd != null) 'scheduled_end': scheduledEnd,
      if (playersRequired != null) 'players_required': playersRequired,
      if (controllerRequirement != null)
        'controller_requirement': controllerRequirement,
      if (status != null) 'status': status,
      if (partyName != null) 'party_name': partyName,
      if (phone != null) 'phone': phone,
      if (notes != null) 'notes': notes,
      if (reminderStatus != null) 'reminder_status': reminderStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookingsCompanion copyWith({
    Value<String>? id,
    Value<String?>? customerId,
    Value<String>? activityCode,
    Value<String?>? gameId,
    Value<String?>? resourceId,
    Value<DateTime>? scheduledStart,
    Value<DateTime>? scheduledEnd,
    Value<int?>? playersRequired,
    Value<int?>? controllerRequirement,
    Value<String>? status,
    Value<String?>? partyName,
    Value<String?>? phone,
    Value<String?>? notes,
    Value<String>? reminderStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BookingsCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      activityCode: activityCode ?? this.activityCode,
      gameId: gameId ?? this.gameId,
      resourceId: resourceId ?? this.resourceId,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      playersRequired: playersRequired ?? this.playersRequired,
      controllerRequirement:
          controllerRequirement ?? this.controllerRequirement,
      status: status ?? this.status,
      partyName: partyName ?? this.partyName,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      reminderStatus: reminderStatus ?? this.reminderStatus,
      createdAt: createdAt ?? this.createdAt,
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
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (activityCode.present) {
      map['activity_code'] = Variable<String>(activityCode.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (resourceId.present) {
      map['resource_id'] = Variable<String>(resourceId.value);
    }
    if (scheduledStart.present) {
      map['scheduled_start'] = Variable<DateTime>(scheduledStart.value);
    }
    if (scheduledEnd.present) {
      map['scheduled_end'] = Variable<DateTime>(scheduledEnd.value);
    }
    if (playersRequired.present) {
      map['players_required'] = Variable<int>(playersRequired.value);
    }
    if (controllerRequirement.present) {
      map['controller_requirement'] = Variable<int>(
        controllerRequirement.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (partyName.present) {
      map['party_name'] = Variable<String>(partyName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (reminderStatus.present) {
      map['reminder_status'] = Variable<String>(reminderStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookingsCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('activityCode: $activityCode, ')
          ..write('gameId: $gameId, ')
          ..write('resourceId: $resourceId, ')
          ..write('scheduledStart: $scheduledStart, ')
          ..write('scheduledEnd: $scheduledEnd, ')
          ..write('playersRequired: $playersRequired, ')
          ..write('controllerRequirement: $controllerRequirement, ')
          ..write('status: $status, ')
          ..write('partyName: $partyName, ')
          ..write('phone: $phone, ')
          ..write('notes: $notes, ')
          ..write('reminderStatus: $reminderStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, UserRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> perms =
      GeneratedColumn<String>(
        'perms',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<String>>($UsersTable.$converterperms);
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pinSaltMeta = const VerificationMeta(
    'pinSalt',
  );
  @override
  late final GeneratedColumn<String> pinSalt = GeneratedColumn<String>(
    'pin_salt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pinIterationsMeta = const VerificationMeta(
    'pinIterations',
  );
  @override
  late final GeneratedColumn<int> pinIterations = GeneratedColumn<int>(
    'pin_iterations',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failedAttemptsMeta = const VerificationMeta(
    'failedAttempts',
  );
  @override
  late final GeneratedColumn<int> failedAttempts = GeneratedColumn<int>(
    'failed_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lockedUntilAtMeta = const VerificationMeta(
    'lockedUntilAt',
  );
  @override
  late final GeneratedColumn<DateTime> lockedUntilAt =
      GeneratedColumn<DateTime>(
        'locked_until_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    perms,
    active,
    sortOrder,
    pinSalt,
    pinHash,
    pinIterations,
    failedAttempts,
    lockedUntilAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('pin_salt')) {
      context.handle(
        _pinSaltMeta,
        pinSalt.isAcceptableOrUnknown(data['pin_salt']!, _pinSaltMeta),
      );
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    }
    if (data.containsKey('pin_iterations')) {
      context.handle(
        _pinIterationsMeta,
        pinIterations.isAcceptableOrUnknown(
          data['pin_iterations']!,
          _pinIterationsMeta,
        ),
      );
    }
    if (data.containsKey('failed_attempts')) {
      context.handle(
        _failedAttemptsMeta,
        failedAttempts.isAcceptableOrUnknown(
          data['failed_attempts']!,
          _failedAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('locked_until_at')) {
      context.handle(
        _lockedUntilAtMeta,
        lockedUntilAt.isAcceptableOrUnknown(
          data['locked_until_at']!,
          _lockedUntilAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      perms: $UsersTable.$converterperms.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}perms'],
        )!,
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      pinSalt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_salt'],
      ),
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      ),
      pinIterations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pin_iterations'],
      ),
      failedAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed_attempts'],
      )!,
      lockedUntilAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}locked_until_at'],
      ),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterperms =
      const StringListConverter();
}

class UserRow extends DataClass implements Insertable<UserRow> {
  final String id;
  final String name;
  final List<String> perms;
  final bool active;
  final int sortOrder;

  /// Base64 salt / PBKDF2 hash / cost. Null only for an account whose PIN has
  /// never been set, which cannot sign in.
  final String? pinSalt;
  final String? pinHash;
  final int? pinIterations;

  /// Consecutive wrong PINs, and the instant the account unlocks. Persisted, so
  /// force-quitting the app does not reset the lockout.
  final int failedAttempts;
  final DateTime? lockedUntilAt;
  const UserRow({
    required this.id,
    required this.name,
    required this.perms,
    required this.active,
    required this.sortOrder,
    this.pinSalt,
    this.pinHash,
    this.pinIterations,
    required this.failedAttempts,
    this.lockedUntilAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    {
      map['perms'] = Variable<String>($UsersTable.$converterperms.toSql(perms));
    }
    map['active'] = Variable<bool>(active);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || pinSalt != null) {
      map['pin_salt'] = Variable<String>(pinSalt);
    }
    if (!nullToAbsent || pinHash != null) {
      map['pin_hash'] = Variable<String>(pinHash);
    }
    if (!nullToAbsent || pinIterations != null) {
      map['pin_iterations'] = Variable<int>(pinIterations);
    }
    map['failed_attempts'] = Variable<int>(failedAttempts);
    if (!nullToAbsent || lockedUntilAt != null) {
      map['locked_until_at'] = Variable<DateTime>(lockedUntilAt);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      name: Value(name),
      perms: Value(perms),
      active: Value(active),
      sortOrder: Value(sortOrder),
      pinSalt: pinSalt == null && nullToAbsent
          ? const Value.absent()
          : Value(pinSalt),
      pinHash: pinHash == null && nullToAbsent
          ? const Value.absent()
          : Value(pinHash),
      pinIterations: pinIterations == null && nullToAbsent
          ? const Value.absent()
          : Value(pinIterations),
      failedAttempts: Value(failedAttempts),
      lockedUntilAt: lockedUntilAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lockedUntilAt),
    );
  }

  factory UserRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      perms: serializer.fromJson<List<String>>(json['perms']),
      active: serializer.fromJson<bool>(json['active']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      pinSalt: serializer.fromJson<String?>(json['pinSalt']),
      pinHash: serializer.fromJson<String?>(json['pinHash']),
      pinIterations: serializer.fromJson<int?>(json['pinIterations']),
      failedAttempts: serializer.fromJson<int>(json['failedAttempts']),
      lockedUntilAt: serializer.fromJson<DateTime?>(json['lockedUntilAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'perms': serializer.toJson<List<String>>(perms),
      'active': serializer.toJson<bool>(active),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'pinSalt': serializer.toJson<String?>(pinSalt),
      'pinHash': serializer.toJson<String?>(pinHash),
      'pinIterations': serializer.toJson<int?>(pinIterations),
      'failedAttempts': serializer.toJson<int>(failedAttempts),
      'lockedUntilAt': serializer.toJson<DateTime?>(lockedUntilAt),
    };
  }

  UserRow copyWith({
    String? id,
    String? name,
    List<String>? perms,
    bool? active,
    int? sortOrder,
    Value<String?> pinSalt = const Value.absent(),
    Value<String?> pinHash = const Value.absent(),
    Value<int?> pinIterations = const Value.absent(),
    int? failedAttempts,
    Value<DateTime?> lockedUntilAt = const Value.absent(),
  }) => UserRow(
    id: id ?? this.id,
    name: name ?? this.name,
    perms: perms ?? this.perms,
    active: active ?? this.active,
    sortOrder: sortOrder ?? this.sortOrder,
    pinSalt: pinSalt.present ? pinSalt.value : this.pinSalt,
    pinHash: pinHash.present ? pinHash.value : this.pinHash,
    pinIterations: pinIterations.present
        ? pinIterations.value
        : this.pinIterations,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntilAt: lockedUntilAt.present
        ? lockedUntilAt.value
        : this.lockedUntilAt,
  );
  UserRow copyWithCompanion(UsersCompanion data) {
    return UserRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      perms: data.perms.present ? data.perms.value : this.perms,
      active: data.active.present ? data.active.value : this.active,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      pinSalt: data.pinSalt.present ? data.pinSalt.value : this.pinSalt,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      pinIterations: data.pinIterations.present
          ? data.pinIterations.value
          : this.pinIterations,
      failedAttempts: data.failedAttempts.present
          ? data.failedAttempts.value
          : this.failedAttempts,
      lockedUntilAt: data.lockedUntilAt.present
          ? data.lockedUntilAt.value
          : this.lockedUntilAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('perms: $perms, ')
          ..write('active: $active, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('pinSalt: $pinSalt, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinIterations: $pinIterations, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('lockedUntilAt: $lockedUntilAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    perms,
    active,
    sortOrder,
    pinSalt,
    pinHash,
    pinIterations,
    failedAttempts,
    lockedUntilAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.perms == this.perms &&
          other.active == this.active &&
          other.sortOrder == this.sortOrder &&
          other.pinSalt == this.pinSalt &&
          other.pinHash == this.pinHash &&
          other.pinIterations == this.pinIterations &&
          other.failedAttempts == this.failedAttempts &&
          other.lockedUntilAt == this.lockedUntilAt);
}

class UsersCompanion extends UpdateCompanion<UserRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<List<String>> perms;
  final Value<bool> active;
  final Value<int> sortOrder;
  final Value<String?> pinSalt;
  final Value<String?> pinHash;
  final Value<int?> pinIterations;
  final Value<int> failedAttempts;
  final Value<DateTime?> lockedUntilAt;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.perms = const Value.absent(),
    this.active = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.pinSalt = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.pinIterations = const Value.absent(),
    this.failedAttempts = const Value.absent(),
    this.lockedUntilAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    required String name,
    required List<String> perms,
    this.active = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.pinSalt = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.pinIterations = const Value.absent(),
    this.failedAttempts = const Value.absent(),
    this.lockedUntilAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       perms = Value(perms);
  static Insertable<UserRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? perms,
    Expression<bool>? active,
    Expression<int>? sortOrder,
    Expression<String>? pinSalt,
    Expression<String>? pinHash,
    Expression<int>? pinIterations,
    Expression<int>? failedAttempts,
    Expression<DateTime>? lockedUntilAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (perms != null) 'perms': perms,
      if (active != null) 'active': active,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (pinSalt != null) 'pin_salt': pinSalt,
      if (pinHash != null) 'pin_hash': pinHash,
      if (pinIterations != null) 'pin_iterations': pinIterations,
      if (failedAttempts != null) 'failed_attempts': failedAttempts,
      if (lockedUntilAt != null) 'locked_until_at': lockedUntilAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<List<String>>? perms,
    Value<bool>? active,
    Value<int>? sortOrder,
    Value<String?>? pinSalt,
    Value<String?>? pinHash,
    Value<int?>? pinIterations,
    Value<int>? failedAttempts,
    Value<DateTime?>? lockedUntilAt,
    Value<int>? rowid,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      perms: perms ?? this.perms,
      active: active ?? this.active,
      sortOrder: sortOrder ?? this.sortOrder,
      pinSalt: pinSalt ?? this.pinSalt,
      pinHash: pinHash ?? this.pinHash,
      pinIterations: pinIterations ?? this.pinIterations,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntilAt: lockedUntilAt ?? this.lockedUntilAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (perms.present) {
      map['perms'] = Variable<String>(
        $UsersTable.$converterperms.toSql(perms.value),
      );
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (pinSalt.present) {
      map['pin_salt'] = Variable<String>(pinSalt.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (pinIterations.present) {
      map['pin_iterations'] = Variable<int>(pinIterations.value);
    }
    if (failedAttempts.present) {
      map['failed_attempts'] = Variable<int>(failedAttempts.value);
    }
    if (lockedUntilAt.present) {
      map['locked_until_at'] = Variable<DateTime>(lockedUntilAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('perms: $perms, ')
          ..write('active: $active, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('pinSalt: $pinSalt, ')
          ..write('pinHash: $pinHash, ')
          ..write('pinIterations: $pinIterations, ')
          ..write('failedAttempts: $failedAttempts, ')
          ..write('lockedUntilAt: $lockedUntilAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _opIdMeta = const VerificationMeta('opId');
  @override
  late final GeneratedColumn<String> opId = GeneratedColumn<String>(
    'op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorDetailMeta = const VerificationMeta(
    'errorDetail',
  );
  @override
  late final GeneratedColumn<String> errorDetail = GeneratedColumn<String>(
    'error_detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _needsRefetchMeta = const VerificationMeta(
    'needsRefetch',
  );
  @override
  late final GeneratedColumn<bool> needsRefetch = GeneratedColumn<bool>(
    'needs_refetch',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_refetch" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAttemptAtMeta = const VerificationMeta(
    'lastAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>(
        'last_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    opId,
    kind,
    entityType,
    entityId,
    payload,
    status,
    attempts,
    errorCode,
    errorDetail,
    result,
    needsRefetch,
    actorId,
    createdAt,
    lastAttemptAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('op_id')) {
      context.handle(
        _opIdMeta,
        opId.isAcceptableOrUnknown(data['op_id']!, _opIdMeta),
      );
    } else if (isInserting) {
      context.missing(_opIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_detail')) {
      context.handle(
        _errorDetailMeta,
        errorDetail.isAcceptableOrUnknown(
          data['error_detail']!,
          _errorDetailMeta,
        ),
      );
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    if (data.containsKey('needs_refetch')) {
      context.handle(
        _needsRefetchMeta,
        needsRefetch.isAcceptableOrUnknown(
          data['needs_refetch']!,
          _needsRefetchMeta,
        ),
      );
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
        _lastAttemptAtMeta,
        lastAttemptAt.isAcceptableOrUnknown(
          data['last_attempt_at']!,
          _lastAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  SyncOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      opId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_detail'],
      ),
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      ),
      needsRefetch: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_refetch'],
      )!,
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt_at'],
      ),
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxRow extends DataClass implements Insertable<SyncOutboxRow> {
  /// Push order. The server applies a device's ops in exactly this order.
  final int seq;

  /// Generated on this device; the server's idempotency key.
  final String opId;
  final String kind;

  /// What the op is about, for rollback after a rejection:
  /// session | controller | customer | booking | catalog | staff.
  final String entityType;
  final String entityId;
  final String payload;

  /// pending → applied | rejected. A rejected op stays visible until resolved.
  final String status;
  final int attempts;
  final String? errorCode;
  final String? errorDetail;
  final String? result;

  /// The device must refetch [entityType]/[entityId] from the server: its local
  /// copy was rolled forward by an op the server refused or adjusted.
  final bool needsRefetch;

  /// Who did it on this device, for the conflicts list.
  final String? actorId;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final DateTime? resolvedAt;
  const SyncOutboxRow({
    required this.seq,
    required this.opId,
    required this.kind,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.status,
    required this.attempts,
    this.errorCode,
    this.errorDetail,
    this.result,
    required this.needsRefetch,
    this.actorId,
    required this.createdAt,
    this.lastAttemptAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['op_id'] = Variable<String>(opId);
    map['kind'] = Variable<String>(kind);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['payload'] = Variable<String>(payload);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorDetail != null) {
      map['error_detail'] = Variable<String>(errorDetail);
    }
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    map['needs_refetch'] = Variable<bool>(needsRefetch);
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<String>(actorId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      seq: Value(seq),
      opId: Value(opId),
      kind: Value(kind),
      entityType: Value(entityType),
      entityId: Value(entityId),
      payload: Value(payload),
      status: Value(status),
      attempts: Value(attempts),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorDetail: errorDetail == null && nullToAbsent
          ? const Value.absent()
          : Value(errorDetail),
      result: result == null && nullToAbsent
          ? const Value.absent()
          : Value(result),
      needsRefetch: Value(needsRefetch),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      createdAt: Value(createdAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory SyncOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxRow(
      seq: serializer.fromJson<int>(json['seq']),
      opId: serializer.fromJson<String>(json['opId']),
      kind: serializer.fromJson<String>(json['kind']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorDetail: serializer.fromJson<String?>(json['errorDetail']),
      result: serializer.fromJson<String?>(json['result']),
      needsRefetch: serializer.fromJson<bool>(json['needsRefetch']),
      actorId: serializer.fromJson<String?>(json['actorId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'opId': serializer.toJson<String>(opId),
      'kind': serializer.toJson<String>(kind),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'payload': serializer.toJson<String>(payload),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorDetail': serializer.toJson<String?>(errorDetail),
      'result': serializer.toJson<String?>(result),
      'needsRefetch': serializer.toJson<bool>(needsRefetch),
      'actorId': serializer.toJson<String?>(actorId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  SyncOutboxRow copyWith({
    int? seq,
    String? opId,
    String? kind,
    String? entityType,
    String? entityId,
    String? payload,
    String? status,
    int? attempts,
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorDetail = const Value.absent(),
    Value<String?> result = const Value.absent(),
    bool? needsRefetch,
    Value<String?> actorId = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> lastAttemptAt = const Value.absent(),
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => SyncOutboxRow(
    seq: seq ?? this.seq,
    opId: opId ?? this.opId,
    kind: kind ?? this.kind,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    payload: payload ?? this.payload,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorDetail: errorDetail.present ? errorDetail.value : this.errorDetail,
    result: result.present ? result.value : this.result,
    needsRefetch: needsRefetch ?? this.needsRefetch,
    actorId: actorId.present ? actorId.value : this.actorId,
    createdAt: createdAt ?? this.createdAt,
    lastAttemptAt: lastAttemptAt.present
        ? lastAttemptAt.value
        : this.lastAttemptAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  SyncOutboxRow copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      opId: data.opId.present ? data.opId.value : this.opId,
      kind: data.kind.present ? data.kind.value : this.kind,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorDetail: data.errorDetail.present
          ? data.errorDetail.value
          : this.errorDetail,
      result: data.result.present ? data.result.value : this.result,
      needsRefetch: data.needsRefetch.present
          ? data.needsRefetch.value
          : this.needsRefetch,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxRow(')
          ..write('seq: $seq, ')
          ..write('opId: $opId, ')
          ..write('kind: $kind, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorDetail: $errorDetail, ')
          ..write('result: $result, ')
          ..write('needsRefetch: $needsRefetch, ')
          ..write('actorId: $actorId, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    opId,
    kind,
    entityType,
    entityId,
    payload,
    status,
    attempts,
    errorCode,
    errorDetail,
    result,
    needsRefetch,
    actorId,
    createdAt,
    lastAttemptAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxRow &&
          other.seq == this.seq &&
          other.opId == this.opId &&
          other.kind == this.kind &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.errorCode == this.errorCode &&
          other.errorDetail == this.errorDetail &&
          other.result == this.result &&
          other.needsRefetch == this.needsRefetch &&
          other.actorId == this.actorId &&
          other.createdAt == this.createdAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.resolvedAt == this.resolvedAt);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxRow> {
  final Value<int> seq;
  final Value<String> opId;
  final Value<String> kind;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> payload;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> errorCode;
  final Value<String?> errorDetail;
  final Value<String?> result;
  final Value<bool> needsRefetch;
  final Value<String?> actorId;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<DateTime?> resolvedAt;
  const SyncOutboxCompanion({
    this.seq = const Value.absent(),
    this.opId = const Value.absent(),
    this.kind = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorDetail = const Value.absent(),
    this.result = const Value.absent(),
    this.needsRefetch = const Value.absent(),
    this.actorId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String opId,
    required String kind,
    required String entityType,
    required String entityId,
    required String payload,
    required String status,
    this.attempts = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorDetail = const Value.absent(),
    this.result = const Value.absent(),
    this.needsRefetch = const Value.absent(),
    this.actorId = const Value.absent(),
    required DateTime createdAt,
    this.lastAttemptAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
  }) : opId = Value(opId),
       kind = Value(kind),
       entityType = Value(entityType),
       entityId = Value(entityId),
       payload = Value(payload),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<SyncOutboxRow> custom({
    Expression<int>? seq,
    Expression<String>? opId,
    Expression<String>? kind,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? errorCode,
    Expression<String>? errorDetail,
    Expression<String>? result,
    Expression<bool>? needsRefetch,
    Expression<String>? actorId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<DateTime>? resolvedAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (opId != null) 'op_id': opId,
      if (kind != null) 'kind': kind,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (errorCode != null) 'error_code': errorCode,
      if (errorDetail != null) 'error_detail': errorDetail,
      if (result != null) 'result': result,
      if (needsRefetch != null) 'needs_refetch': needsRefetch,
      if (actorId != null) 'actor_id': actorId,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? opId,
    Value<String>? kind,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? payload,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? errorCode,
    Value<String?>? errorDetail,
    Value<String?>? result,
    Value<bool>? needsRefetch,
    Value<String?>? actorId,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastAttemptAt,
    Value<DateTime?>? resolvedAt,
  }) {
    return SyncOutboxCompanion(
      seq: seq ?? this.seq,
      opId: opId ?? this.opId,
      kind: kind ?? this.kind,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      errorCode: errorCode ?? this.errorCode,
      errorDetail: errorDetail ?? this.errorDetail,
      result: result ?? this.result,
      needsRefetch: needsRefetch ?? this.needsRefetch,
      actorId: actorId ?? this.actorId,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (opId.present) {
      map['op_id'] = Variable<String>(opId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorDetail.present) {
      map['error_detail'] = Variable<String>(errorDetail.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (needsRefetch.present) {
      map['needs_refetch'] = Variable<bool>(needsRefetch.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('opId: $opId, ')
          ..write('kind: $kind, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorDetail: $errorDetail, ')
          ..write('result: $result, ')
          ..write('needsRefetch: $needsRefetch, ')
          ..write('actorId: $actorId, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaRow extends DataClass implements Insertable<SyncMetaRow> {
  final String key;
  final String value;
  const SyncMetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetaRow copyWith({String? key, String? value}) =>
      SyncMetaRow(key: key ?? this.key, value: value ?? this.value);
  SyncMetaRow copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncVersionsTable extends SyncVersions
    with TableInfo<$SyncVersionsTable, SyncVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entity, rowId, version];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncVersionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, rowId};
  @override
  SyncVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncVersionRow(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $SyncVersionsTable createAlias(String alias) {
    return $SyncVersionsTable(attachedDatabase, alias);
  }
}

class SyncVersionRow extends DataClass implements Insertable<SyncVersionRow> {
  final String entity;
  final String rowId;
  final String version;
  const SyncVersionRow({
    required this.entity,
    required this.rowId,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['row_id'] = Variable<String>(rowId);
    map['version'] = Variable<String>(version);
    return map;
  }

  SyncVersionsCompanion toCompanion(bool nullToAbsent) {
    return SyncVersionsCompanion(
      entity: Value(entity),
      rowId: Value(rowId),
      version: Value(version),
    );
  }

  factory SyncVersionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncVersionRow(
      entity: serializer.fromJson<String>(json['entity']),
      rowId: serializer.fromJson<String>(json['rowId']),
      version: serializer.fromJson<String>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'rowId': serializer.toJson<String>(rowId),
      'version': serializer.toJson<String>(version),
    };
  }

  SyncVersionRow copyWith({String? entity, String? rowId, String? version}) =>
      SyncVersionRow(
        entity: entity ?? this.entity,
        rowId: rowId ?? this.rowId,
        version: version ?? this.version,
      );
  SyncVersionRow copyWithCompanion(SyncVersionsCompanion data) {
    return SyncVersionRow(
      entity: data.entity.present ? data.entity.value : this.entity,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncVersionRow(')
          ..write('entity: $entity, ')
          ..write('rowId: $rowId, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, rowId, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncVersionRow &&
          other.entity == this.entity &&
          other.rowId == this.rowId &&
          other.version == this.version);
}

class SyncVersionsCompanion extends UpdateCompanion<SyncVersionRow> {
  final Value<String> entity;
  final Value<String> rowId;
  final Value<String> version;
  final Value<int> rowid;
  const SyncVersionsCompanion({
    this.entity = const Value.absent(),
    this.rowId = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncVersionsCompanion.insert({
    required String entity,
    required String rowId,
    required String version,
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       rowId = Value(rowId),
       version = Value(version);
  static Insertable<SyncVersionRow> custom({
    Expression<String>? entity,
    Expression<String>? rowId,
    Expression<String>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (rowId != null) 'row_id': rowId,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncVersionsCompanion copyWith({
    Value<String>? entity,
    Value<String>? rowId,
    Value<String>? version,
    Value<int>? rowid,
  }) {
    return SyncVersionsCompanion(
      entity: entity ?? this.entity,
      rowId: rowId ?? this.rowId,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncVersionsCompanion(')
          ..write('entity: $entity, ')
          ..write('rowId: $rowId, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CustomersTable customers = $CustomersTable(this);
  late final $ActivitiesTable activities = $ActivitiesTable(this);
  late final $ResourcesTable resources = $ResourcesTable(this);
  late final $ResourceActivitiesTable resourceActivities =
      $ResourceActivitiesTable(this);
  late final $ControllersTable controllers = $ControllersTable(this);
  late final $ControllerAllocationsTable controllerAllocations =
      $ControllerAllocationsTable(this);
  late final $ControllerMovesTable controllerMoves = $ControllerMovesTable(
    this,
  );
  late final $GameCategoriesTable gameCategories = $GameCategoriesTable(this);
  late final $GamesTable games = $GamesTable(this);
  late final $GameResourcesTable gameResources = $GameResourcesTable(this);
  late final $GameControlsTable gameControls = $GameControlsTable(this);
  late final $RatesTable rates = $RatesTable(this);
  late final $BillingPoliciesTable billingPolicies = $BillingPoliciesTable(
    this,
  );
  late final $HolidaysTable holidays = $HolidaysTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $PricingRulesTable pricingRules = $PricingRulesTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SessionSegmentsTable sessionSegments = $SessionSegmentsTable(
    this,
  );
  late final $SessionExtensionsTable sessionExtensions =
      $SessionExtensionsTable(this);
  late final $SessionChargesTable sessionCharges = $SessionChargesTable(this);
  late final $PaymentsTable payments = $PaymentsTable(this);
  late final $BookingsTable bookings = $BookingsTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final $SyncVersionsTable syncVersions = $SyncVersionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    customers,
    activities,
    resources,
    resourceActivities,
    controllers,
    controllerAllocations,
    controllerMoves,
    gameCategories,
    games,
    gameResources,
    gameControls,
    rates,
    billingPolicies,
    holidays,
    settings,
    pricingRules,
    sessions,
    sessionSegments,
    sessionExtensions,
    sessionCharges,
    payments,
    bookings,
    users,
    syncOutbox,
    syncMeta,
    syncVersions,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$CustomersTableCreateCompanionBuilder = CustomersCompanion Function({
  required String id,
  required String name,
  Value<String?> phone,
  Value<String?> notes,
  Value<DateTime?> lastVisitAt,
  Value<bool> isGuest,
  Value<int?> birthYear,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CustomersTableUpdateCompanionBuilder = CustomersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> phone,
  Value<String?> notes,
  Value<DateTime?> lastVisitAt,
  Value<bool> isGuest,
  Value<int?> birthYear,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CustomersTableFilterComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastVisitAt => $composableBuilder(
    column: $table.lastVisitAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isGuest => $composableBuilder(
    column: $table.isGuest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastVisitAt => $composableBuilder(
    column: $table.lastVisitAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isGuest => $composableBuilder(
    column: $table.isGuest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthYear => $composableBuilder(
    column: $table.birthYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CustomersTable> {
  $$CustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get lastVisitAt => $composableBuilder(
    column: $table.lastVisitAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isGuest =>
      $composableBuilder(column: $table.isGuest, builder: (column) => column);

  GeneratedColumn<int> get birthYear =>
      $composableBuilder(column: $table.birthYear, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CustomersTable,
          CustomerRow,
          $$CustomersTableFilterComposer,
          $$CustomersTableOrderingComposer,
          $$CustomersTableAnnotationComposer,
          $$CustomersTableCreateCompanionBuilder,
          $$CustomersTableUpdateCompanionBuilder,
          (
            CustomerRow,
            BaseReferences<_$AppDatabase, $CustomersTable, CustomerRow>,
          ),
          CustomerRow,
          PrefetchHooks Function()
        > {
  $$CustomersTableTableManager(_$AppDatabase db, $CustomersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> lastVisitAt = const Value.absent(),
                Value<bool> isGuest = const Value.absent(),
                Value<int?> birthYear = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion(
                id: id,
                name: name,
                phone: phone,
                notes: notes,
                lastVisitAt: lastVisitAt,
                isGuest: isGuest,
                birthYear: birthYear,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> lastVisitAt = const Value.absent(),
                Value<bool> isGuest = const Value.absent(),
                Value<int?> birthYear = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CustomersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                notes: notes,
                lastVisitAt: lastVisitAt,
                isGuest: isGuest,
                birthYear: birthYear,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomersTable, CustomerRow>(table),
                  BaseReferences<_$AppDatabase, $CustomersTable, CustomerRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CustomersTable,
      CustomerRow,
      $$CustomersTableFilterComposer,
      $$CustomersTableOrderingComposer,
      $$CustomersTableAnnotationComposer,
      $$CustomersTableCreateCompanionBuilder,
      $$CustomersTableUpdateCompanionBuilder,
      (
        CustomerRow,
        BaseReferences<_$AppDatabase, $CustomersTable, CustomerRow>,
      ),
      CustomerRow,
      PrefetchHooks Function()
    >;
typedef $$ActivitiesTableCreateCompanionBuilder = ActivitiesCompanion Function({
  required String id,
  required String code,
  required String name,
  required bool usesControllers,
  required bool usesGames,
  required String durationModel,
  Value<bool> legacyHappyHourEligible,
  Value<int> sortOrder,
  Value<bool> active,
  Value<int> overtimeGraceMinutes,
  Value<int> rowid,
});
typedef $$ActivitiesTableUpdateCompanionBuilder = ActivitiesCompanion Function({
  Value<String> id,
  Value<String> code,
  Value<String> name,
  Value<bool> usesControllers,
  Value<bool> usesGames,
  Value<String> durationModel,
  Value<bool> legacyHappyHourEligible,
  Value<int> sortOrder,
  Value<bool> active,
  Value<int> overtimeGraceMinutes,
  Value<int> rowid,
});

class $$ActivitiesTableFilterComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableFilterComposer({
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

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get usesControllers => $composableBuilder(
    column: $table.usesControllers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get usesGames => $composableBuilder(
    column: $table.usesGames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get durationModel => $composableBuilder(
    column: $table.durationModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get legacyHappyHourEligible => $composableBuilder(
    column: $table.legacyHappyHourEligible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overtimeGraceMinutes => $composableBuilder(
    column: $table.overtimeGraceMinutes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableOrderingComposer({
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

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get usesControllers => $composableBuilder(
    column: $table.usesControllers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get usesGames => $composableBuilder(
    column: $table.usesGames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get durationModel => $composableBuilder(
    column: $table.durationModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get legacyHappyHourEligible => $composableBuilder(
    column: $table.legacyHappyHourEligible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overtimeGraceMinutes => $composableBuilder(
    column: $table.overtimeGraceMinutes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivitiesTable> {
  $$ActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get usesControllers => $composableBuilder(
    column: $table.usesControllers,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get usesGames =>
      $composableBuilder(column: $table.usesGames, builder: (column) => column);

  GeneratedColumn<String> get durationModel => $composableBuilder(
    column: $table.durationModel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get legacyHappyHourEligible => $composableBuilder(
    column: $table.legacyHappyHourEligible,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get overtimeGraceMinutes => $composableBuilder(
    column: $table.overtimeGraceMinutes,
    builder: (column) => column,
  );
}

class $$ActivitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivitiesTable,
          ActivityRow,
          $$ActivitiesTableFilterComposer,
          $$ActivitiesTableOrderingComposer,
          $$ActivitiesTableAnnotationComposer,
          $$ActivitiesTableCreateCompanionBuilder,
          $$ActivitiesTableUpdateCompanionBuilder,
          (
            ActivityRow,
            BaseReferences<_$AppDatabase, $ActivitiesTable, ActivityRow>,
          ),
          ActivityRow,
          PrefetchHooks Function()
        > {
  $$ActivitiesTableTableManager(_$AppDatabase db, $ActivitiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> usesControllers = const Value.absent(),
                Value<bool> usesGames = const Value.absent(),
                Value<String> durationModel = const Value.absent(),
                Value<bool> legacyHappyHourEligible = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> overtimeGraceMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivitiesCompanion(
                id: id,
                code: code,
                name: name,
                usesControllers: usesControllers,
                usesGames: usesGames,
                durationModel: durationModel,
                legacyHappyHourEligible: legacyHappyHourEligible,
                sortOrder: sortOrder,
                active: active,
                overtimeGraceMinutes: overtimeGraceMinutes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                required bool usesControllers,
                required bool usesGames,
                required String durationModel,
                Value<bool> legacyHappyHourEligible = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> overtimeGraceMinutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivitiesCompanion.insert(
                id: id,
                code: code,
                name: name,
                usesControllers: usesControllers,
                usesGames: usesGames,
                durationModel: durationModel,
                legacyHappyHourEligible: legacyHappyHourEligible,
                sortOrder: sortOrder,
                active: active,
                overtimeGraceMinutes: overtimeGraceMinutes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActivitiesTable, ActivityRow>(table),
                  BaseReferences<_$AppDatabase, $ActivitiesTable, ActivityRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivitiesTable,
      ActivityRow,
      $$ActivitiesTableFilterComposer,
      $$ActivitiesTableOrderingComposer,
      $$ActivitiesTableAnnotationComposer,
      $$ActivitiesTableCreateCompanionBuilder,
      $$ActivitiesTableUpdateCompanionBuilder,
      (
        ActivityRow,
        BaseReferences<_$AppDatabase, $ActivitiesTable, ActivityRow>,
      ),
      ActivityRow,
      PrefetchHooks Function()
    >;
typedef $$ResourcesTableCreateCompanionBuilder = ResourcesCompanion Function({
  required String id,
  required String name,
  required String kind,
  Value<String> status,
  Value<int> sortOrder,
  Value<String?> currentMode,
  Value<int> rowid,
});
typedef $$ResourcesTableUpdateCompanionBuilder = ResourcesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> kind,
  Value<String> status,
  Value<int> sortOrder,
  Value<String?> currentMode,
  Value<int> rowid,
});

class $$ResourcesTableFilterComposer
    extends Composer<_$AppDatabase, $ResourcesTable> {
  $$ResourcesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentMode => $composableBuilder(
    column: $table.currentMode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $ResourcesTable> {
  $$ResourcesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentMode => $composableBuilder(
    column: $table.currentMode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResourcesTable> {
  $$ResourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get currentMode => $composableBuilder(
    column: $table.currentMode,
    builder: (column) => column,
  );
}

class $$ResourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResourcesTable,
          ResourceRow,
          $$ResourcesTableFilterComposer,
          $$ResourcesTableOrderingComposer,
          $$ResourcesTableAnnotationComposer,
          $$ResourcesTableCreateCompanionBuilder,
          $$ResourcesTableUpdateCompanionBuilder,
          (
            ResourceRow,
            BaseReferences<_$AppDatabase, $ResourcesTable, ResourceRow>,
          ),
          ResourceRow,
          PrefetchHooks Function()
        > {
  $$ResourcesTableTableManager(_$AppDatabase db, $ResourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> currentMode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResourcesCompanion(
                id: id,
                name: name,
                kind: kind,
                status: status,
                sortOrder: sortOrder,
                currentMode: currentMode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String kind,
                Value<String> status = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> currentMode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResourcesCompanion.insert(
                id: id,
                name: name,
                kind: kind,
                status: status,
                sortOrder: sortOrder,
                currentMode: currentMode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResourcesTable, ResourceRow>(table),
                  BaseReferences<_$AppDatabase, $ResourcesTable, ResourceRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResourcesTable,
      ResourceRow,
      $$ResourcesTableFilterComposer,
      $$ResourcesTableOrderingComposer,
      $$ResourcesTableAnnotationComposer,
      $$ResourcesTableCreateCompanionBuilder,
      $$ResourcesTableUpdateCompanionBuilder,
      (
        ResourceRow,
        BaseReferences<_$AppDatabase, $ResourcesTable, ResourceRow>,
      ),
      ResourceRow,
      PrefetchHooks Function()
    >;
typedef $$ResourceActivitiesTableCreateCompanionBuilder =
    ResourceActivitiesCompanion Function({
      required String resourceId,
      required String activityCode,
      Value<int> rowid,
    });
typedef $$ResourceActivitiesTableUpdateCompanionBuilder =
    ResourceActivitiesCompanion Function({
      Value<String> resourceId,
      Value<String> activityCode,
      Value<int> rowid,
    });

class $$ResourceActivitiesTableFilterComposer
    extends Composer<_$AppDatabase, $ResourceActivitiesTable> {
  $$ResourceActivitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResourceActivitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $ResourceActivitiesTable> {
  $$ResourceActivitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResourceActivitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResourceActivitiesTable> {
  $$ResourceActivitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => column,
  );
}

class $$ResourceActivitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResourceActivitiesTable,
          ResourceActivityRow,
          $$ResourceActivitiesTableFilterComposer,
          $$ResourceActivitiesTableOrderingComposer,
          $$ResourceActivitiesTableAnnotationComposer,
          $$ResourceActivitiesTableCreateCompanionBuilder,
          $$ResourceActivitiesTableUpdateCompanionBuilder,
          (
            ResourceActivityRow,
            BaseReferences<
              _$AppDatabase,
              $ResourceActivitiesTable,
              ResourceActivityRow
            >,
          ),
          ResourceActivityRow,
          PrefetchHooks Function()
        > {
  $$ResourceActivitiesTableTableManager(
    _$AppDatabase db,
    $ResourceActivitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResourceActivitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResourceActivitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResourceActivitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> resourceId = const Value.absent(),
                Value<String> activityCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResourceActivitiesCompanion(
                resourceId: resourceId,
                activityCode: activityCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String resourceId,
                required String activityCode,
                Value<int> rowid = const Value.absent(),
              }) => ResourceActivitiesCompanion.insert(
                resourceId: resourceId,
                activityCode: activityCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResourceActivitiesTable, ResourceActivityRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ResourceActivitiesTable,
                    ResourceActivityRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResourceActivitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResourceActivitiesTable,
      ResourceActivityRow,
      $$ResourceActivitiesTableFilterComposer,
      $$ResourceActivitiesTableOrderingComposer,
      $$ResourceActivitiesTableAnnotationComposer,
      $$ResourceActivitiesTableCreateCompanionBuilder,
      $$ResourceActivitiesTableUpdateCompanionBuilder,
      (
        ResourceActivityRow,
        BaseReferences<
          _$AppDatabase,
          $ResourceActivitiesTable,
          ResourceActivityRow
        >,
      ),
      ResourceActivityRow,
      PrefetchHooks Function()
    >;
typedef $$ControllersTableCreateCompanionBuilder =
    ControllersCompanion Function({
      required String id,
      required String label,
      required String homeResourceId,
      required String currentResourceId,
      Value<String> status,
      Value<String?> notes,
      Value<String?> loanReturnTo,
      Value<String?> loanSessionRef,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ControllersTableUpdateCompanionBuilder =
    ControllersCompanion Function({
      Value<String> id,
      Value<String> label,
      Value<String> homeResourceId,
      Value<String> currentResourceId,
      Value<String> status,
      Value<String?> notes,
      Value<String?> loanReturnTo,
      Value<String?> loanSessionRef,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ControllersTableFilterComposer
    extends Composer<_$AppDatabase, $ControllersTable> {
  $$ControllersTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homeResourceId => $composableBuilder(
    column: $table.homeResourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentResourceId => $composableBuilder(
    column: $table.currentResourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loanReturnTo => $composableBuilder(
    column: $table.loanReturnTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loanSessionRef => $composableBuilder(
    column: $table.loanSessionRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ControllersTableOrderingComposer
    extends Composer<_$AppDatabase, $ControllersTable> {
  $$ControllersTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homeResourceId => $composableBuilder(
    column: $table.homeResourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentResourceId => $composableBuilder(
    column: $table.currentResourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loanReturnTo => $composableBuilder(
    column: $table.loanReturnTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loanSessionRef => $composableBuilder(
    column: $table.loanSessionRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ControllersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ControllersTable> {
  $$ControllersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get homeResourceId => $composableBuilder(
    column: $table.homeResourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentResourceId => $composableBuilder(
    column: $table.currentResourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get loanReturnTo => $composableBuilder(
    column: $table.loanReturnTo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get loanSessionRef => $composableBuilder(
    column: $table.loanSessionRef,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ControllersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ControllersTable,
          ControllerRow,
          $$ControllersTableFilterComposer,
          $$ControllersTableOrderingComposer,
          $$ControllersTableAnnotationComposer,
          $$ControllersTableCreateCompanionBuilder,
          $$ControllersTableUpdateCompanionBuilder,
          (
            ControllerRow,
            BaseReferences<_$AppDatabase, $ControllersTable, ControllerRow>,
          ),
          ControllerRow,
          PrefetchHooks Function()
        > {
  $$ControllersTableTableManager(_$AppDatabase db, $ControllersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ControllersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ControllersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ControllersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> homeResourceId = const Value.absent(),
                Value<String> currentResourceId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> loanReturnTo = const Value.absent(),
                Value<String?> loanSessionRef = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ControllersCompanion(
                id: id,
                label: label,
                homeResourceId: homeResourceId,
                currentResourceId: currentResourceId,
                status: status,
                notes: notes,
                loanReturnTo: loanReturnTo,
                loanSessionRef: loanSessionRef,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String label,
                required String homeResourceId,
                required String currentResourceId,
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> loanReturnTo = const Value.absent(),
                Value<String?> loanSessionRef = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ControllersCompanion.insert(
                id: id,
                label: label,
                homeResourceId: homeResourceId,
                currentResourceId: currentResourceId,
                status: status,
                notes: notes,
                loanReturnTo: loanReturnTo,
                loanSessionRef: loanSessionRef,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ControllersTable, ControllerRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ControllersTable,
                    ControllerRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ControllersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ControllersTable,
      ControllerRow,
      $$ControllersTableFilterComposer,
      $$ControllersTableOrderingComposer,
      $$ControllersTableAnnotationComposer,
      $$ControllersTableCreateCompanionBuilder,
      $$ControllersTableUpdateCompanionBuilder,
      (
        ControllerRow,
        BaseReferences<_$AppDatabase, $ControllersTable, ControllerRow>,
      ),
      ControllerRow,
      PrefetchHooks Function()
    >;
typedef $$ControllerAllocationsTableCreateCompanionBuilder =
    ControllerAllocationsCompanion Function({
      required String id,
      required String controllerId,
      required String scope,
      Value<String?> sessionId,
      Value<String?> segmentId,
      required String resourceId,
      required String activityCode,
      Value<String?> gameId,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<String?> requestId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ControllerAllocationsTableUpdateCompanionBuilder =
    ControllerAllocationsCompanion Function({
      Value<String> id,
      Value<String> controllerId,
      Value<String> scope,
      Value<String?> sessionId,
      Value<String?> segmentId,
      Value<String> resourceId,
      Value<String> activityCode,
      Value<String?> gameId,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<String?> requestId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ControllerAllocationsTableFilterComposer
    extends Composer<_$AppDatabase, $ControllerAllocationsTable> {
  $$ControllerAllocationsTableFilterComposer({
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

  ColumnFilters<String> get controllerId => $composableBuilder(
    column: $table.controllerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ControllerAllocationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ControllerAllocationsTable> {
  $$ControllerAllocationsTableOrderingComposer({
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

  ColumnOrderings<String> get controllerId => $composableBuilder(
    column: $table.controllerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ControllerAllocationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ControllerAllocationsTable> {
  $$ControllerAllocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get controllerId => $composableBuilder(
    column: $table.controllerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => column);

  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ControllerAllocationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ControllerAllocationsTable,
          ControllerAllocationRow,
          $$ControllerAllocationsTableFilterComposer,
          $$ControllerAllocationsTableOrderingComposer,
          $$ControllerAllocationsTableAnnotationComposer,
          $$ControllerAllocationsTableCreateCompanionBuilder,
          $$ControllerAllocationsTableUpdateCompanionBuilder,
          (
            ControllerAllocationRow,
            BaseReferences<
              _$AppDatabase,
              $ControllerAllocationsTable,
              ControllerAllocationRow
            >,
          ),
          ControllerAllocationRow,
          PrefetchHooks Function()
        > {
  $$ControllerAllocationsTableTableManager(
    _$AppDatabase db,
    $ControllerAllocationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ControllerAllocationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ControllerAllocationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ControllerAllocationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> controllerId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<String?> segmentId = const Value.absent(),
                Value<String> resourceId = const Value.absent(),
                Value<String> activityCode = const Value.absent(),
                Value<String?> gameId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ControllerAllocationsCompanion(
                id: id,
                controllerId: controllerId,
                scope: scope,
                sessionId: sessionId,
                segmentId: segmentId,
                resourceId: resourceId,
                activityCode: activityCode,
                gameId: gameId,
                startedAt: startedAt,
                endedAt: endedAt,
                requestId: requestId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String controllerId,
                required String scope,
                Value<String?> sessionId = const Value.absent(),
                Value<String?> segmentId = const Value.absent(),
                required String resourceId,
                required String activityCode,
                Value<String?> gameId = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> requestId = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ControllerAllocationsCompanion.insert(
                id: id,
                controllerId: controllerId,
                scope: scope,
                sessionId: sessionId,
                segmentId: segmentId,
                resourceId: resourceId,
                activityCode: activityCode,
                gameId: gameId,
                startedAt: startedAt,
                endedAt: endedAt,
                requestId: requestId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ControllerAllocationsTable,
                    ControllerAllocationRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ControllerAllocationsTable,
                    ControllerAllocationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ControllerAllocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ControllerAllocationsTable,
      ControllerAllocationRow,
      $$ControllerAllocationsTableFilterComposer,
      $$ControllerAllocationsTableOrderingComposer,
      $$ControllerAllocationsTableAnnotationComposer,
      $$ControllerAllocationsTableCreateCompanionBuilder,
      $$ControllerAllocationsTableUpdateCompanionBuilder,
      (
        ControllerAllocationRow,
        BaseReferences<
          _$AppDatabase,
          $ControllerAllocationsTable,
          ControllerAllocationRow
        >,
      ),
      ControllerAllocationRow,
      PrefetchHooks Function()
    >;
typedef $$ControllerMovesTableCreateCompanionBuilder =
    ControllerMovesCompanion Function({
      required String id,
      required String controllerId,
      required String fromResourceId,
      required String toResourceId,
      required String kind,
      Value<String?> sessionRef,
      required DateTime movedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ControllerMovesTableUpdateCompanionBuilder =
    ControllerMovesCompanion Function({
      Value<String> id,
      Value<String> controllerId,
      Value<String> fromResourceId,
      Value<String> toResourceId,
      Value<String> kind,
      Value<String?> sessionRef,
      Value<DateTime> movedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ControllerMovesTableFilterComposer
    extends Composer<_$AppDatabase, $ControllerMovesTable> {
  $$ControllerMovesTableFilterComposer({
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

  ColumnFilters<String> get controllerId => $composableBuilder(
    column: $table.controllerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromResourceId => $composableBuilder(
    column: $table.fromResourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toResourceId => $composableBuilder(
    column: $table.toResourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionRef => $composableBuilder(
    column: $table.sessionRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get movedAt => $composableBuilder(
    column: $table.movedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ControllerMovesTableOrderingComposer
    extends Composer<_$AppDatabase, $ControllerMovesTable> {
  $$ControllerMovesTableOrderingComposer({
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

  ColumnOrderings<String> get controllerId => $composableBuilder(
    column: $table.controllerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromResourceId => $composableBuilder(
    column: $table.fromResourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toResourceId => $composableBuilder(
    column: $table.toResourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionRef => $composableBuilder(
    column: $table.sessionRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get movedAt => $composableBuilder(
    column: $table.movedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ControllerMovesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ControllerMovesTable> {
  $$ControllerMovesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get controllerId => $composableBuilder(
    column: $table.controllerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fromResourceId => $composableBuilder(
    column: $table.fromResourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toResourceId => $composableBuilder(
    column: $table.toResourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get sessionRef => $composableBuilder(
    column: $table.sessionRef,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get movedAt =>
      $composableBuilder(column: $table.movedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ControllerMovesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ControllerMovesTable,
          ControllerMoveRow,
          $$ControllerMovesTableFilterComposer,
          $$ControllerMovesTableOrderingComposer,
          $$ControllerMovesTableAnnotationComposer,
          $$ControllerMovesTableCreateCompanionBuilder,
          $$ControllerMovesTableUpdateCompanionBuilder,
          (
            ControllerMoveRow,
            BaseReferences<
              _$AppDatabase,
              $ControllerMovesTable,
              ControllerMoveRow
            >,
          ),
          ControllerMoveRow,
          PrefetchHooks Function()
        > {
  $$ControllerMovesTableTableManager(
    _$AppDatabase db,
    $ControllerMovesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ControllerMovesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ControllerMovesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ControllerMovesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> controllerId = const Value.absent(),
                Value<String> fromResourceId = const Value.absent(),
                Value<String> toResourceId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> sessionRef = const Value.absent(),
                Value<DateTime> movedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ControllerMovesCompanion(
                id: id,
                controllerId: controllerId,
                fromResourceId: fromResourceId,
                toResourceId: toResourceId,
                kind: kind,
                sessionRef: sessionRef,
                movedAt: movedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String controllerId,
                required String fromResourceId,
                required String toResourceId,
                required String kind,
                Value<String?> sessionRef = const Value.absent(),
                required DateTime movedAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ControllerMovesCompanion.insert(
                id: id,
                controllerId: controllerId,
                fromResourceId: fromResourceId,
                toResourceId: toResourceId,
                kind: kind,
                sessionRef: sessionRef,
                movedAt: movedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ControllerMovesTable, ControllerMoveRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ControllerMovesTable,
                    ControllerMoveRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ControllerMovesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ControllerMovesTable,
      ControllerMoveRow,
      $$ControllerMovesTableFilterComposer,
      $$ControllerMovesTableOrderingComposer,
      $$ControllerMovesTableAnnotationComposer,
      $$ControllerMovesTableCreateCompanionBuilder,
      $$ControllerMovesTableUpdateCompanionBuilder,
      (
        ControllerMoveRow,
        BaseReferences<_$AppDatabase, $ControllerMovesTable, ControllerMoveRow>,
      ),
      ControllerMoveRow,
      PrefetchHooks Function()
    >;
typedef $$GameCategoriesTableCreateCompanionBuilder =
    GameCategoriesCompanion Function({
      required String id,
      required String name,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$GameCategoriesTableUpdateCompanionBuilder =
    GameCategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$GameCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $GameCategoriesTable> {
  $$GameCategoriesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GameCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $GameCategoriesTable> {
  $$GameCategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameCategoriesTable> {
  $$GameCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$GameCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameCategoriesTable,
          GameCategoryRow,
          $$GameCategoriesTableFilterComposer,
          $$GameCategoriesTableOrderingComposer,
          $$GameCategoriesTableAnnotationComposer,
          $$GameCategoriesTableCreateCompanionBuilder,
          $$GameCategoriesTableUpdateCompanionBuilder,
          (
            GameCategoryRow,
            BaseReferences<
              _$AppDatabase,
              $GameCategoriesTable,
              GameCategoryRow
            >,
          ),
          GameCategoryRow,
          PrefetchHooks Function()
        > {
  $$GameCategoriesTableTableManager(
    _$AppDatabase db,
    $GameCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameCategoriesCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameCategoriesCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GameCategoriesTable, GameCategoryRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $GameCategoriesTable,
                    GameCategoryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GameCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameCategoriesTable,
      GameCategoryRow,
      $$GameCategoriesTableFilterComposer,
      $$GameCategoriesTableOrderingComposer,
      $$GameCategoriesTableAnnotationComposer,
      $$GameCategoriesTableCreateCompanionBuilder,
      $$GameCategoriesTableUpdateCompanionBuilder,
      (
        GameCategoryRow,
        BaseReferences<_$AppDatabase, $GameCategoriesTable, GameCategoryRow>,
      ),
      GameCategoryRow,
      PrefetchHooks Function()
    >;
typedef $$GamesTableCreateCompanionBuilder = GamesCompanion Function({
  required String id,
  required String name,
  required List<String> aliases,
  Value<String?> categoryId,
  required List<String> platforms,
  Value<List<String>> playModes,
  Value<int> maxLocalPlayers,
  Value<bool> active,
  Value<DateTime?> lastPlayedAt,
  Value<int> rowid,
});
typedef $$GamesTableUpdateCompanionBuilder = GamesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<List<String>> aliases,
  Value<String?> categoryId,
  Value<List<String>> platforms,
  Value<List<String>> playModes,
  Value<int> maxLocalPlayers,
  Value<bool> active,
  Value<DateTime?> lastPlayedAt,
  Value<int> rowid,
});

class $$GamesTableFilterComposer extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get platforms => $composableBuilder(
    column: $table.platforms,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get playModes => $composableBuilder(
    column: $table.playModes,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get maxLocalPlayers => $composableBuilder(
    column: $table.maxLocalPlayers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GamesTableOrderingComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platforms => $composableBuilder(
    column: $table.platforms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playModes => $composableBuilder(
    column: $table.playModes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxLocalPlayers => $composableBuilder(
    column: $table.maxLocalPlayers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GamesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get aliases =>
      $composableBuilder(column: $table.aliases, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get platforms =>
      $composableBuilder(column: $table.platforms, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get playModes =>
      $composableBuilder(column: $table.playModes, builder: (column) => column);

  GeneratedColumn<int> get maxLocalPlayers => $composableBuilder(
    column: $table.maxLocalPlayers,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );
}

class $$GamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GamesTable,
          GameRow,
          $$GamesTableFilterComposer,
          $$GamesTableOrderingComposer,
          $$GamesTableAnnotationComposer,
          $$GamesTableCreateCompanionBuilder,
          $$GamesTableUpdateCompanionBuilder,
          (GameRow, BaseReferences<_$AppDatabase, $GamesTable, GameRow>),
          GameRow,
          PrefetchHooks Function()
        > {
  $$GamesTableTableManager(_$AppDatabase db, $GamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<List<String>> aliases = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<List<String>> platforms = const Value.absent(),
                Value<List<String>> playModes = const Value.absent(),
                Value<int> maxLocalPlayers = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GamesCompanion(
                id: id,
                name: name,
                aliases: aliases,
                categoryId: categoryId,
                platforms: platforms,
                playModes: playModes,
                maxLocalPlayers: maxLocalPlayers,
                active: active,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required List<String> aliases,
                Value<String?> categoryId = const Value.absent(),
                required List<String> platforms,
                Value<List<String>> playModes = const Value.absent(),
                Value<int> maxLocalPlayers = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GamesCompanion.insert(
                id: id,
                name: name,
                aliases: aliases,
                categoryId: categoryId,
                platforms: platforms,
                playModes: playModes,
                maxLocalPlayers: maxLocalPlayers,
                active: active,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GamesTable, GameRow>(table),
                  BaseReferences<_$AppDatabase, $GamesTable, GameRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GamesTable,
      GameRow,
      $$GamesTableFilterComposer,
      $$GamesTableOrderingComposer,
      $$GamesTableAnnotationComposer,
      $$GamesTableCreateCompanionBuilder,
      $$GamesTableUpdateCompanionBuilder,
      (GameRow, BaseReferences<_$AppDatabase, $GamesTable, GameRow>),
      GameRow,
      PrefetchHooks Function()
    >;
typedef $$GameResourcesTableCreateCompanionBuilder =
    GameResourcesCompanion Function({
      required String gameId,
      required String resourceId,
      required String status,
      Value<String?> notes,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$GameResourcesTableUpdateCompanionBuilder =
    GameResourcesCompanion Function({
      Value<String> gameId,
      Value<String> resourceId,
      Value<String> status,
      Value<String?> notes,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$GameResourcesTableFilterComposer
    extends Composer<_$AppDatabase, $GameResourcesTable> {
  $$GameResourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GameResourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $GameResourcesTable> {
  $$GameResourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameResourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameResourcesTable> {
  $$GameResourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GameResourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameResourcesTable,
          GameResourceRow,
          $$GameResourcesTableFilterComposer,
          $$GameResourcesTableOrderingComposer,
          $$GameResourcesTableAnnotationComposer,
          $$GameResourcesTableCreateCompanionBuilder,
          $$GameResourcesTableUpdateCompanionBuilder,
          (
            GameResourceRow,
            BaseReferences<_$AppDatabase, $GameResourcesTable, GameResourceRow>,
          ),
          GameResourceRow,
          PrefetchHooks Function()
        > {
  $$GameResourcesTableTableManager(_$AppDatabase db, $GameResourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameResourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameResourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameResourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> gameId = const Value.absent(),
                Value<String> resourceId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameResourcesCompanion(
                gameId: gameId,
                resourceId: resourceId,
                status: status,
                notes: notes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String gameId,
                required String resourceId,
                required String status,
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameResourcesCompanion.insert(
                gameId: gameId,
                resourceId: resourceId,
                status: status,
                notes: notes,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GameResourcesTable, GameResourceRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $GameResourcesTable,
                    GameResourceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GameResourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameResourcesTable,
      GameResourceRow,
      $$GameResourcesTableFilterComposer,
      $$GameResourcesTableOrderingComposer,
      $$GameResourcesTableAnnotationComposer,
      $$GameResourcesTableCreateCompanionBuilder,
      $$GameResourcesTableUpdateCompanionBuilder,
      (
        GameResourceRow,
        BaseReferences<_$AppDatabase, $GameResourcesTable, GameResourceRow>,
      ),
      GameResourceRow,
      PrefetchHooks Function()
    >;
typedef $$GameControlsTableCreateCompanionBuilder =
    GameControlsCompanion Function({
      required String id,
      required String gameId,
      required String section,
      required String action,
      required List<String> buttons,
      Value<String?> explanation,
      Value<String?> notes,
      Value<String?> imageUrl,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$GameControlsTableUpdateCompanionBuilder =
    GameControlsCompanion Function({
      Value<String> id,
      Value<String> gameId,
      Value<String> section,
      Value<String> action,
      Value<List<String>> buttons,
      Value<String?> explanation,
      Value<String?> notes,
      Value<String?> imageUrl,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$GameControlsTableFilterComposer
    extends Composer<_$AppDatabase, $GameControlsTable> {
  $$GameControlsTableFilterComposer({
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

  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get buttons => $composableBuilder(
    column: $table.buttons,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GameControlsTableOrderingComposer
    extends Composer<_$AppDatabase, $GameControlsTable> {
  $$GameControlsTableOrderingComposer({
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

  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get buttons => $composableBuilder(
    column: $table.buttons,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameControlsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameControlsTable> {
  $$GameControlsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get buttons =>
      $composableBuilder(column: $table.buttons, builder: (column) => column);

  GeneratedColumn<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$GameControlsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameControlsTable,
          GameControlRow,
          $$GameControlsTableFilterComposer,
          $$GameControlsTableOrderingComposer,
          $$GameControlsTableAnnotationComposer,
          $$GameControlsTableCreateCompanionBuilder,
          $$GameControlsTableUpdateCompanionBuilder,
          (
            GameControlRow,
            BaseReferences<_$AppDatabase, $GameControlsTable, GameControlRow>,
          ),
          GameControlRow,
          PrefetchHooks Function()
        > {
  $$GameControlsTableTableManager(_$AppDatabase db, $GameControlsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameControlsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameControlsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameControlsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> gameId = const Value.absent(),
                Value<String> section = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<List<String>> buttons = const Value.absent(),
                Value<String?> explanation = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameControlsCompanion(
                id: id,
                gameId: gameId,
                section: section,
                action: action,
                buttons: buttons,
                explanation: explanation,
                notes: notes,
                imageUrl: imageUrl,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String gameId,
                required String section,
                required String action,
                required List<String> buttons,
                Value<String?> explanation = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameControlsCompanion.insert(
                id: id,
                gameId: gameId,
                section: section,
                action: action,
                buttons: buttons,
                explanation: explanation,
                notes: notes,
                imageUrl: imageUrl,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GameControlsTable, GameControlRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $GameControlsTable,
                    GameControlRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GameControlsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameControlsTable,
      GameControlRow,
      $$GameControlsTableFilterComposer,
      $$GameControlsTableOrderingComposer,
      $$GameControlsTableAnnotationComposer,
      $$GameControlsTableCreateCompanionBuilder,
      $$GameControlsTableUpdateCompanionBuilder,
      (
        GameControlRow,
        BaseReferences<_$AppDatabase, $GameControlsTable, GameControlRow>,
      ),
      GameControlRow,
      PrefetchHooks Function()
    >;
typedef $$RatesTableCreateCompanionBuilder = RatesCompanion Function({
  required String id,
  required String activityCode,
  required String band,
  Value<int?> controllerCount,
  required int unitMinutes,
  required int pricePaise,
  Value<int> rowid,
});
typedef $$RatesTableUpdateCompanionBuilder = RatesCompanion Function({
  Value<String> id,
  Value<String> activityCode,
  Value<String> band,
  Value<int?> controllerCount,
  Value<int> unitMinutes,
  Value<int> pricePaise,
  Value<int> rowid,
});

class $$RatesTableFilterComposer extends Composer<_$AppDatabase, $RatesTable> {
  $$RatesTableFilterComposer({
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

  ColumnFilters<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get band => $composableBuilder(
    column: $table.band,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get controllerCount => $composableBuilder(
    column: $table.controllerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitMinutes => $composableBuilder(
    column: $table.unitMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pricePaise => $composableBuilder(
    column: $table.pricePaise,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RatesTableOrderingComposer
    extends Composer<_$AppDatabase, $RatesTable> {
  $$RatesTableOrderingComposer({
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

  ColumnOrderings<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get band => $composableBuilder(
    column: $table.band,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get controllerCount => $composableBuilder(
    column: $table.controllerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitMinutes => $composableBuilder(
    column: $table.unitMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pricePaise => $composableBuilder(
    column: $table.pricePaise,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RatesTable> {
  $$RatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get band =>
      $composableBuilder(column: $table.band, builder: (column) => column);

  GeneratedColumn<int> get controllerCount => $composableBuilder(
    column: $table.controllerCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitMinutes => $composableBuilder(
    column: $table.unitMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pricePaise => $composableBuilder(
    column: $table.pricePaise,
    builder: (column) => column,
  );
}

class $$RatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RatesTable,
          RateRow,
          $$RatesTableFilterComposer,
          $$RatesTableOrderingComposer,
          $$RatesTableAnnotationComposer,
          $$RatesTableCreateCompanionBuilder,
          $$RatesTableUpdateCompanionBuilder,
          (RateRow, BaseReferences<_$AppDatabase, $RatesTable, RateRow>),
          RateRow,
          PrefetchHooks Function()
        > {
  $$RatesTableTableManager(_$AppDatabase db, $RatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> activityCode = const Value.absent(),
                Value<String> band = const Value.absent(),
                Value<int?> controllerCount = const Value.absent(),
                Value<int> unitMinutes = const Value.absent(),
                Value<int> pricePaise = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RatesCompanion(
                id: id,
                activityCode: activityCode,
                band: band,
                controllerCount: controllerCount,
                unitMinutes: unitMinutes,
                pricePaise: pricePaise,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String activityCode,
                required String band,
                Value<int?> controllerCount = const Value.absent(),
                required int unitMinutes,
                required int pricePaise,
                Value<int> rowid = const Value.absent(),
              }) => RatesCompanion.insert(
                id: id,
                activityCode: activityCode,
                band: band,
                controllerCount: controllerCount,
                unitMinutes: unitMinutes,
                pricePaise: pricePaise,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RatesTable, RateRow>(table),
                  BaseReferences<_$AppDatabase, $RatesTable, RateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RatesTable,
      RateRow,
      $$RatesTableFilterComposer,
      $$RatesTableOrderingComposer,
      $$RatesTableAnnotationComposer,
      $$RatesTableCreateCompanionBuilder,
      $$RatesTableUpdateCompanionBuilder,
      (RateRow, BaseReferences<_$AppDatabase, $RatesTable, RateRow>),
      RateRow,
      PrefetchHooks Function()
    >;
typedef $$BillingPoliciesTableCreateCompanionBuilder =
    BillingPoliciesCompanion Function({
      required String id,
      required String json,
      Value<int> rowid,
    });
typedef $$BillingPoliciesTableUpdateCompanionBuilder =
    BillingPoliciesCompanion Function({
      Value<String> id,
      Value<String> json,
      Value<int> rowid,
    });

class $$BillingPoliciesTableFilterComposer
    extends Composer<_$AppDatabase, $BillingPoliciesTable> {
  $$BillingPoliciesTableFilterComposer({
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

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BillingPoliciesTableOrderingComposer
    extends Composer<_$AppDatabase, $BillingPoliciesTable> {
  $$BillingPoliciesTableOrderingComposer({
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

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BillingPoliciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BillingPoliciesTable> {
  $$BillingPoliciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$BillingPoliciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BillingPoliciesTable,
          BillingPolicyRow,
          $$BillingPoliciesTableFilterComposer,
          $$BillingPoliciesTableOrderingComposer,
          $$BillingPoliciesTableAnnotationComposer,
          $$BillingPoliciesTableCreateCompanionBuilder,
          $$BillingPoliciesTableUpdateCompanionBuilder,
          (
            BillingPolicyRow,
            BaseReferences<
              _$AppDatabase,
              $BillingPoliciesTable,
              BillingPolicyRow
            >,
          ),
          BillingPolicyRow,
          PrefetchHooks Function()
        > {
  $$BillingPoliciesTableTableManager(
    _$AppDatabase db,
    $BillingPoliciesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillingPoliciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillingPoliciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillingPoliciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => BillingPoliciesCompanion(id: id, json: json, rowid: rowid),
          createCompanionCallback:
              ({
                required String id,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => BillingPoliciesCompanion.insert(
                id: id,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BillingPoliciesTable, BillingPolicyRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BillingPoliciesTable,
                    BillingPolicyRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BillingPoliciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BillingPoliciesTable,
      BillingPolicyRow,
      $$BillingPoliciesTableFilterComposer,
      $$BillingPoliciesTableOrderingComposer,
      $$BillingPoliciesTableAnnotationComposer,
      $$BillingPoliciesTableCreateCompanionBuilder,
      $$BillingPoliciesTableUpdateCompanionBuilder,
      (
        BillingPolicyRow,
        BaseReferences<_$AppDatabase, $BillingPoliciesTable, BillingPolicyRow>,
      ),
      BillingPolicyRow,
      PrefetchHooks Function()
    >;
typedef $$HolidaysTableCreateCompanionBuilder = HolidaysCompanion Function({
  required String day,
  required String name,
  Value<bool> closed,
  Value<int> rowid,
});
typedef $$HolidaysTableUpdateCompanionBuilder = HolidaysCompanion Function({
  Value<String> day,
  Value<String> name,
  Value<bool> closed,
  Value<int> rowid,
});

class $$HolidaysTableFilterComposer
    extends Composer<_$AppDatabase, $HolidaysTable> {
  $$HolidaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get closed => $composableBuilder(
    column: $table.closed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HolidaysTableOrderingComposer
    extends Composer<_$AppDatabase, $HolidaysTable> {
  $$HolidaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get closed => $composableBuilder(
    column: $table.closed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HolidaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $HolidaysTable> {
  $$HolidaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get closed =>
      $composableBuilder(column: $table.closed, builder: (column) => column);
}

class $$HolidaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HolidaysTable,
          HolidayRow,
          $$HolidaysTableFilterComposer,
          $$HolidaysTableOrderingComposer,
          $$HolidaysTableAnnotationComposer,
          $$HolidaysTableCreateCompanionBuilder,
          $$HolidaysTableUpdateCompanionBuilder,
          (
            HolidayRow,
            BaseReferences<_$AppDatabase, $HolidaysTable, HolidayRow>,
          ),
          HolidayRow,
          PrefetchHooks Function()
        > {
  $$HolidaysTableTableManager(_$AppDatabase db, $HolidaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HolidaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HolidaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HolidaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> closed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HolidaysCompanion(
                day: day,
                name: name,
                closed: closed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                required String name,
                Value<bool> closed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HolidaysCompanion.insert(
                day: day,
                name: name,
                closed: closed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HolidaysTable, HolidayRow>(table),
                  BaseReferences<_$AppDatabase, $HolidaysTable, HolidayRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HolidaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HolidaysTable,
      HolidayRow,
      $$HolidaysTableFilterComposer,
      $$HolidaysTableOrderingComposer,
      $$HolidaysTableAnnotationComposer,
      $$HolidaysTableCreateCompanionBuilder,
      $$HolidaysTableUpdateCompanionBuilder,
      (HolidayRow, BaseReferences<_$AppDatabase, $HolidaysTable, HolidayRow>),
      HolidayRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String json,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> json,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, json: json, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String json,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, json: json, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$PricingRulesTableCreateCompanionBuilder =
    PricingRulesCompanion Function({
      required String id,
      required String name,
      Value<int> priority,
      Value<bool> active,
      required List<int> days,
      required int startMin,
      required int endMin,
      Value<String> holidayMode,
      Value<String?> validFrom,
      Value<String?> validUntil,
      required List<String> activityCodes,
      required String adjustKind,
      required int adjustValue,
      Value<int> rowid,
    });
typedef $$PricingRulesTableUpdateCompanionBuilder =
    PricingRulesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> priority,
      Value<bool> active,
      Value<List<int>> days,
      Value<int> startMin,
      Value<int> endMin,
      Value<String> holidayMode,
      Value<String?> validFrom,
      Value<String?> validUntil,
      Value<List<String>> activityCodes,
      Value<String> adjustKind,
      Value<int> adjustValue,
      Value<int> rowid,
    });

class $$PricingRulesTableFilterComposer
    extends Composer<_$AppDatabase, $PricingRulesTable> {
  $$PricingRulesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<int>, List<int>, String> get days =>
      $composableBuilder(
        column: $table.days,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get startMin => $composableBuilder(
    column: $table.startMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMin => $composableBuilder(
    column: $table.endMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holidayMode => $composableBuilder(
    column: $table.holidayMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get activityCodes => $composableBuilder(
    column: $table.activityCodes,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get adjustKind => $composableBuilder(
    column: $table.adjustKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get adjustValue => $composableBuilder(
    column: $table.adjustValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PricingRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $PricingRulesTable> {
  $$PricingRulesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get days => $composableBuilder(
    column: $table.days,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMin => $composableBuilder(
    column: $table.startMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMin => $composableBuilder(
    column: $table.endMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holidayMode => $composableBuilder(
    column: $table.holidayMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validFrom => $composableBuilder(
    column: $table.validFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityCodes => $composableBuilder(
    column: $table.activityCodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adjustKind => $composableBuilder(
    column: $table.adjustKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get adjustValue => $composableBuilder(
    column: $table.adjustValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PricingRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PricingRulesTable> {
  $$PricingRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>, String> get days =>
      $composableBuilder(column: $table.days, builder: (column) => column);

  GeneratedColumn<int> get startMin =>
      $composableBuilder(column: $table.startMin, builder: (column) => column);

  GeneratedColumn<int> get endMin =>
      $composableBuilder(column: $table.endMin, builder: (column) => column);

  GeneratedColumn<String> get holidayMode => $composableBuilder(
    column: $table.holidayMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get validFrom =>
      $composableBuilder(column: $table.validFrom, builder: (column) => column);

  GeneratedColumn<String> get validUntil => $composableBuilder(
    column: $table.validUntil,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get activityCodes =>
      $composableBuilder(
        column: $table.activityCodes,
        builder: (column) => column,
      );

  GeneratedColumn<String> get adjustKind => $composableBuilder(
    column: $table.adjustKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get adjustValue => $composableBuilder(
    column: $table.adjustValue,
    builder: (column) => column,
  );
}

class $$PricingRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PricingRulesTable,
          PricingRuleRow,
          $$PricingRulesTableFilterComposer,
          $$PricingRulesTableOrderingComposer,
          $$PricingRulesTableAnnotationComposer,
          $$PricingRulesTableCreateCompanionBuilder,
          $$PricingRulesTableUpdateCompanionBuilder,
          (
            PricingRuleRow,
            BaseReferences<_$AppDatabase, $PricingRulesTable, PricingRuleRow>,
          ),
          PricingRuleRow,
          PrefetchHooks Function()
        > {
  $$PricingRulesTableTableManager(_$AppDatabase db, $PricingRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PricingRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PricingRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PricingRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<List<int>> days = const Value.absent(),
                Value<int> startMin = const Value.absent(),
                Value<int> endMin = const Value.absent(),
                Value<String> holidayMode = const Value.absent(),
                Value<String?> validFrom = const Value.absent(),
                Value<String?> validUntil = const Value.absent(),
                Value<List<String>> activityCodes = const Value.absent(),
                Value<String> adjustKind = const Value.absent(),
                Value<int> adjustValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PricingRulesCompanion(
                id: id,
                name: name,
                priority: priority,
                active: active,
                days: days,
                startMin: startMin,
                endMin: endMin,
                holidayMode: holidayMode,
                validFrom: validFrom,
                validUntil: validUntil,
                activityCodes: activityCodes,
                adjustKind: adjustKind,
                adjustValue: adjustValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> priority = const Value.absent(),
                Value<bool> active = const Value.absent(),
                required List<int> days,
                required int startMin,
                required int endMin,
                Value<String> holidayMode = const Value.absent(),
                Value<String?> validFrom = const Value.absent(),
                Value<String?> validUntil = const Value.absent(),
                required List<String> activityCodes,
                required String adjustKind,
                required int adjustValue,
                Value<int> rowid = const Value.absent(),
              }) => PricingRulesCompanion.insert(
                id: id,
                name: name,
                priority: priority,
                active: active,
                days: days,
                startMin: startMin,
                endMin: endMin,
                holidayMode: holidayMode,
                validFrom: validFrom,
                validUntil: validUntil,
                activityCodes: activityCodes,
                adjustKind: adjustKind,
                adjustValue: adjustValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PricingRulesTable, PricingRuleRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PricingRulesTable,
                    PricingRuleRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PricingRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PricingRulesTable,
      PricingRuleRow,
      $$PricingRulesTableFilterComposer,
      $$PricingRulesTableOrderingComposer,
      $$PricingRulesTableAnnotationComposer,
      $$PricingRulesTableCreateCompanionBuilder,
      $$PricingRulesTableUpdateCompanionBuilder,
      (
        PricingRuleRow,
        BaseReferences<_$AppDatabase, $PricingRulesTable, PricingRuleRow>,
      ),
      PricingRuleRow,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  Value<String?> bookingId,
  required String customerId,
  required String status,
  required String paymentStatus,
  required DateTime startedAt,
  required DateTime scheduledEndAt,
  Value<DateTime?> actualEndedAt,
  required Map<String, dynamic> pricingSnapshot,
  Value<int?> billedAmountPaise,
  Value<String?> voidReason,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String?> bookingId,
  Value<String> customerId,
  Value<String> status,
  Value<String> paymentStatus,
  Value<DateTime> startedAt,
  Value<DateTime> scheduledEndAt,
  Value<DateTime?> actualEndedAt,
  Value<Map<String, dynamic>> pricingSnapshot,
  Value<int?> billedAmountPaise,
  Value<String?> voidReason,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
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

  ColumnFilters<String> get bookingId => $composableBuilder(
    column: $table.bookingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledEndAt => $composableBuilder(
    column: $table.scheduledEndAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actualEndedAt => $composableBuilder(
    column: $table.actualEndedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    Map<String, dynamic>,
    Map<String, dynamic>,
    String
  >
  get pricingSnapshot => $composableBuilder(
    column: $table.pricingSnapshot,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get billedAmountPaise => $composableBuilder(
    column: $table.billedAmountPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
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

  ColumnOrderings<String> get bookingId => $composableBuilder(
    column: $table.bookingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledEndAt => $composableBuilder(
    column: $table.scheduledEndAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actualEndedAt => $composableBuilder(
    column: $table.actualEndedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pricingSnapshot => $composableBuilder(
    column: $table.pricingSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get billedAmountPaise => $composableBuilder(
    column: $table.billedAmountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookingId =>
      $composableBuilder(column: $table.bookingId, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get paymentStatus => $composableBuilder(
    column: $table.paymentStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledEndAt => $composableBuilder(
    column: $table.scheduledEndAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get actualEndedAt => $composableBuilder(
    column: $table.actualEndedAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<Map<String, dynamic>, String>
  get pricingSnapshot => $composableBuilder(
    column: $table.pricingSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<int> get billedAmountPaise => $composableBuilder(
    column: $table.billedAmountPaise,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voidReason => $composableBuilder(
    column: $table.voidReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (
            SessionRow,
            BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>,
          ),
          SessionRow,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> bookingId = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> paymentStatus = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> scheduledEndAt = const Value.absent(),
                Value<DateTime?> actualEndedAt = const Value.absent(),
                Value<Map<String, dynamic>> pricingSnapshot =
                    const Value.absent(),
                Value<int?> billedAmountPaise = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                bookingId: bookingId,
                customerId: customerId,
                status: status,
                paymentStatus: paymentStatus,
                startedAt: startedAt,
                scheduledEndAt: scheduledEndAt,
                actualEndedAt: actualEndedAt,
                pricingSnapshot: pricingSnapshot,
                billedAmountPaise: billedAmountPaise,
                voidReason: voidReason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> bookingId = const Value.absent(),
                required String customerId,
                required String status,
                required String paymentStatus,
                required DateTime startedAt,
                required DateTime scheduledEndAt,
                Value<DateTime?> actualEndedAt = const Value.absent(),
                required Map<String, dynamic> pricingSnapshot,
                Value<int?> billedAmountPaise = const Value.absent(),
                Value<String?> voidReason = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                bookingId: bookingId,
                customerId: customerId,
                status: status,
                paymentStatus: paymentStatus,
                startedAt: startedAt,
                scheduledEndAt: scheduledEndAt,
                actualEndedAt: actualEndedAt,
                pricingSnapshot: pricingSnapshot,
                billedAmountPaise: billedAmountPaise,
                voidReason: voidReason,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, SessionRow>(table),
                  BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>),
      SessionRow,
      PrefetchHooks Function()
    >;
typedef $$SessionSegmentsTableCreateCompanionBuilder =
    SessionSegmentsCompanion Function({
      required String id,
      required String sessionId,
      required int index,
      required String resourceId,
      required String activityCode,
      Value<String?> gameId,
      Value<int?> controllerCount,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SessionSegmentsTableUpdateCompanionBuilder =
    SessionSegmentsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> index,
      Value<String> resourceId,
      Value<String> activityCode,
      Value<String?> gameId,
      Value<int?> controllerCount,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SessionSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionSegmentsTable> {
  $$SessionSegmentsTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get controllerCount => $composableBuilder(
    column: $table.controllerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionSegmentsTable> {
  $$SessionSegmentsTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get controllerCount => $composableBuilder(
    column: $table.controllerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionSegmentsTable> {
  $$SessionSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get index =>
      $composableBuilder(column: $table.index, builder: (column) => column);

  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<int> get controllerCount => $composableBuilder(
    column: $table.controllerCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SessionSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionSegmentsTable,
          SessionSegmentRow,
          $$SessionSegmentsTableFilterComposer,
          $$SessionSegmentsTableOrderingComposer,
          $$SessionSegmentsTableAnnotationComposer,
          $$SessionSegmentsTableCreateCompanionBuilder,
          $$SessionSegmentsTableUpdateCompanionBuilder,
          (
            SessionSegmentRow,
            BaseReferences<
              _$AppDatabase,
              $SessionSegmentsTable,
              SessionSegmentRow
            >,
          ),
          SessionSegmentRow,
          PrefetchHooks Function()
        > {
  $$SessionSegmentsTableTableManager(
    _$AppDatabase db,
    $SessionSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> index = const Value.absent(),
                Value<String> resourceId = const Value.absent(),
                Value<String> activityCode = const Value.absent(),
                Value<String?> gameId = const Value.absent(),
                Value<int?> controllerCount = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionSegmentsCompanion(
                id: id,
                sessionId: sessionId,
                index: index,
                resourceId: resourceId,
                activityCode: activityCode,
                gameId: gameId,
                controllerCount: controllerCount,
                startedAt: startedAt,
                endedAt: endedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int index,
                required String resourceId,
                required String activityCode,
                Value<String?> gameId = const Value.absent(),
                Value<int?> controllerCount = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SessionSegmentsCompanion.insert(
                id: id,
                sessionId: sessionId,
                index: index,
                resourceId: resourceId,
                activityCode: activityCode,
                gameId: gameId,
                controllerCount: controllerCount,
                startedAt: startedAt,
                endedAt: endedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionSegmentsTable, SessionSegmentRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SessionSegmentsTable,
                    SessionSegmentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionSegmentsTable,
      SessionSegmentRow,
      $$SessionSegmentsTableFilterComposer,
      $$SessionSegmentsTableOrderingComposer,
      $$SessionSegmentsTableAnnotationComposer,
      $$SessionSegmentsTableCreateCompanionBuilder,
      $$SessionSegmentsTableUpdateCompanionBuilder,
      (
        SessionSegmentRow,
        BaseReferences<_$AppDatabase, $SessionSegmentsTable, SessionSegmentRow>,
      ),
      SessionSegmentRow,
      PrefetchHooks Function()
    >;
typedef $$SessionExtensionsTableCreateCompanionBuilder =
    SessionExtensionsCompanion Function({
      required String id,
      required String sessionId,
      required int addedMinutes,
      required DateTime oldEndAt,
      required DateTime newEndAt,
      Value<int> addedAmountPaise,
      Value<String?> reason,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SessionExtensionsTableUpdateCompanionBuilder =
    SessionExtensionsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<int> addedMinutes,
      Value<DateTime> oldEndAt,
      Value<DateTime> newEndAt,
      Value<int> addedAmountPaise,
      Value<String?> reason,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SessionExtensionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionExtensionsTable> {
  $$SessionExtensionsTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedMinutes => $composableBuilder(
    column: $table.addedMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get oldEndAt => $composableBuilder(
    column: $table.oldEndAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get newEndAt => $composableBuilder(
    column: $table.newEndAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAmountPaise => $composableBuilder(
    column: $table.addedAmountPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionExtensionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionExtensionsTable> {
  $$SessionExtensionsTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedMinutes => $composableBuilder(
    column: $table.addedMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get oldEndAt => $composableBuilder(
    column: $table.oldEndAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get newEndAt => $composableBuilder(
    column: $table.newEndAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAmountPaise => $composableBuilder(
    column: $table.addedAmountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionExtensionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionExtensionsTable> {
  $$SessionExtensionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get addedMinutes => $composableBuilder(
    column: $table.addedMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get oldEndAt =>
      $composableBuilder(column: $table.oldEndAt, builder: (column) => column);

  GeneratedColumn<DateTime> get newEndAt =>
      $composableBuilder(column: $table.newEndAt, builder: (column) => column);

  GeneratedColumn<int> get addedAmountPaise => $composableBuilder(
    column: $table.addedAmountPaise,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SessionExtensionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionExtensionsTable,
          SessionExtensionRow,
          $$SessionExtensionsTableFilterComposer,
          $$SessionExtensionsTableOrderingComposer,
          $$SessionExtensionsTableAnnotationComposer,
          $$SessionExtensionsTableCreateCompanionBuilder,
          $$SessionExtensionsTableUpdateCompanionBuilder,
          (
            SessionExtensionRow,
            BaseReferences<
              _$AppDatabase,
              $SessionExtensionsTable,
              SessionExtensionRow
            >,
          ),
          SessionExtensionRow,
          PrefetchHooks Function()
        > {
  $$SessionExtensionsTableTableManager(
    _$AppDatabase db,
    $SessionExtensionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionExtensionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionExtensionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionExtensionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> addedMinutes = const Value.absent(),
                Value<DateTime> oldEndAt = const Value.absent(),
                Value<DateTime> newEndAt = const Value.absent(),
                Value<int> addedAmountPaise = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionExtensionsCompanion(
                id: id,
                sessionId: sessionId,
                addedMinutes: addedMinutes,
                oldEndAt: oldEndAt,
                newEndAt: newEndAt,
                addedAmountPaise: addedAmountPaise,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int addedMinutes,
                required DateTime oldEndAt,
                required DateTime newEndAt,
                Value<int> addedAmountPaise = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SessionExtensionsCompanion.insert(
                id: id,
                sessionId: sessionId,
                addedMinutes: addedMinutes,
                oldEndAt: oldEndAt,
                newEndAt: newEndAt,
                addedAmountPaise: addedAmountPaise,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionExtensionsTable, SessionExtensionRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $SessionExtensionsTable,
                    SessionExtensionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionExtensionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionExtensionsTable,
      SessionExtensionRow,
      $$SessionExtensionsTableFilterComposer,
      $$SessionExtensionsTableOrderingComposer,
      $$SessionExtensionsTableAnnotationComposer,
      $$SessionExtensionsTableCreateCompanionBuilder,
      $$SessionExtensionsTableUpdateCompanionBuilder,
      (
        SessionExtensionRow,
        BaseReferences<
          _$AppDatabase,
          $SessionExtensionsTable,
          SessionExtensionRow
        >,
      ),
      SessionExtensionRow,
      PrefetchHooks Function()
    >;
typedef $$SessionChargesTableCreateCompanionBuilder =
    SessionChargesCompanion Function({
      required String id,
      required String sessionId,
      Value<String?> segmentId,
      required int segmentIndex,
      required String bandCode,
      required String activityCode,
      Value<String?> resourceId,
      Value<int?> controllerCount,
      required DateTime segmentStart,
      required DateTime segmentEnd,
      required int playedMinutes,
      required int billedMinutes,
      required int unitMinutes,
      required int unitPricePaise,
      required int amountPaise,
      Value<int> rowid,
    });
typedef $$SessionChargesTableUpdateCompanionBuilder =
    SessionChargesCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String?> segmentId,
      Value<int> segmentIndex,
      Value<String> bandCode,
      Value<String> activityCode,
      Value<String?> resourceId,
      Value<int?> controllerCount,
      Value<DateTime> segmentStart,
      Value<DateTime> segmentEnd,
      Value<int> playedMinutes,
      Value<int> billedMinutes,
      Value<int> unitMinutes,
      Value<int> unitPricePaise,
      Value<int> amountPaise,
      Value<int> rowid,
    });

class $$SessionChargesTableFilterComposer
    extends Composer<_$AppDatabase, $SessionChargesTable> {
  $$SessionChargesTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bandCode => $composableBuilder(
    column: $table.bandCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get controllerCount => $composableBuilder(
    column: $table.controllerCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get segmentStart => $composableBuilder(
    column: $table.segmentStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get segmentEnd => $composableBuilder(
    column: $table.segmentEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playedMinutes => $composableBuilder(
    column: $table.playedMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get billedMinutes => $composableBuilder(
    column: $table.billedMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitMinutes => $composableBuilder(
    column: $table.unitMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPricePaise => $composableBuilder(
    column: $table.unitPricePaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionChargesTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionChargesTable> {
  $$SessionChargesTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bandCode => $composableBuilder(
    column: $table.bandCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get controllerCount => $composableBuilder(
    column: $table.controllerCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get segmentStart => $composableBuilder(
    column: $table.segmentStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get segmentEnd => $composableBuilder(
    column: $table.segmentEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playedMinutes => $composableBuilder(
    column: $table.playedMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get billedMinutes => $composableBuilder(
    column: $table.billedMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitMinutes => $composableBuilder(
    column: $table.unitMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPricePaise => $composableBuilder(
    column: $table.unitPricePaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionChargesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionChargesTable> {
  $$SessionChargesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => column);

  GeneratedColumn<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bandCode =>
      $composableBuilder(column: $table.bandCode, builder: (column) => column);

  GeneratedColumn<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get controllerCount => $composableBuilder(
    column: $table.controllerCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get segmentStart => $composableBuilder(
    column: $table.segmentStart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get segmentEnd => $composableBuilder(
    column: $table.segmentEnd,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playedMinutes => $composableBuilder(
    column: $table.playedMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get billedMinutes => $composableBuilder(
    column: $table.billedMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitMinutes => $composableBuilder(
    column: $table.unitMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unitPricePaise => $composableBuilder(
    column: $table.unitPricePaise,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );
}

class $$SessionChargesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionChargesTable,
          SessionChargeRow,
          $$SessionChargesTableFilterComposer,
          $$SessionChargesTableOrderingComposer,
          $$SessionChargesTableAnnotationComposer,
          $$SessionChargesTableCreateCompanionBuilder,
          $$SessionChargesTableUpdateCompanionBuilder,
          (
            SessionChargeRow,
            BaseReferences<
              _$AppDatabase,
              $SessionChargesTable,
              SessionChargeRow
            >,
          ),
          SessionChargeRow,
          PrefetchHooks Function()
        > {
  $$SessionChargesTableTableManager(
    _$AppDatabase db,
    $SessionChargesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionChargesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionChargesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionChargesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String?> segmentId = const Value.absent(),
                Value<int> segmentIndex = const Value.absent(),
                Value<String> bandCode = const Value.absent(),
                Value<String> activityCode = const Value.absent(),
                Value<String?> resourceId = const Value.absent(),
                Value<int?> controllerCount = const Value.absent(),
                Value<DateTime> segmentStart = const Value.absent(),
                Value<DateTime> segmentEnd = const Value.absent(),
                Value<int> playedMinutes = const Value.absent(),
                Value<int> billedMinutes = const Value.absent(),
                Value<int> unitMinutes = const Value.absent(),
                Value<int> unitPricePaise = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionChargesCompanion(
                id: id,
                sessionId: sessionId,
                segmentId: segmentId,
                segmentIndex: segmentIndex,
                bandCode: bandCode,
                activityCode: activityCode,
                resourceId: resourceId,
                controllerCount: controllerCount,
                segmentStart: segmentStart,
                segmentEnd: segmentEnd,
                playedMinutes: playedMinutes,
                billedMinutes: billedMinutes,
                unitMinutes: unitMinutes,
                unitPricePaise: unitPricePaise,
                amountPaise: amountPaise,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                Value<String?> segmentId = const Value.absent(),
                required int segmentIndex,
                required String bandCode,
                required String activityCode,
                Value<String?> resourceId = const Value.absent(),
                Value<int?> controllerCount = const Value.absent(),
                required DateTime segmentStart,
                required DateTime segmentEnd,
                required int playedMinutes,
                required int billedMinutes,
                required int unitMinutes,
                required int unitPricePaise,
                required int amountPaise,
                Value<int> rowid = const Value.absent(),
              }) => SessionChargesCompanion.insert(
                id: id,
                sessionId: sessionId,
                segmentId: segmentId,
                segmentIndex: segmentIndex,
                bandCode: bandCode,
                activityCode: activityCode,
                resourceId: resourceId,
                controllerCount: controllerCount,
                segmentStart: segmentStart,
                segmentEnd: segmentEnd,
                playedMinutes: playedMinutes,
                billedMinutes: billedMinutes,
                unitMinutes: unitMinutes,
                unitPricePaise: unitPricePaise,
                amountPaise: amountPaise,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionChargesTable, SessionChargeRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SessionChargesTable,
                    SessionChargeRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionChargesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionChargesTable,
      SessionChargeRow,
      $$SessionChargesTableFilterComposer,
      $$SessionChargesTableOrderingComposer,
      $$SessionChargesTableAnnotationComposer,
      $$SessionChargesTableCreateCompanionBuilder,
      $$SessionChargesTableUpdateCompanionBuilder,
      (
        SessionChargeRow,
        BaseReferences<_$AppDatabase, $SessionChargesTable, SessionChargeRow>,
      ),
      SessionChargeRow,
      PrefetchHooks Function()
    >;
typedef $$PaymentsTableCreateCompanionBuilder = PaymentsCompanion Function({
  required String id,
  required String sessionId,
  required int amountPaise,
  required String method,
  Value<bool> isRefund,
  Value<String?> note,
  Value<String?> reason,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$PaymentsTableUpdateCompanionBuilder = PaymentsCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<int> amountPaise,
  Value<String> method,
  Value<bool> isRefund,
  Value<String?> note,
  Value<String?> reason,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$PaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableFilterComposer({
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

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRefund => $composableBuilder(
    column: $table.isRefund,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRefund => $composableBuilder(
    column: $table.isRefund,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaymentsTable> {
  $$PaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<bool> get isRefund =>
      $composableBuilder(column: $table.isRefund, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PaymentsTable,
          PaymentRow,
          $$PaymentsTableFilterComposer,
          $$PaymentsTableOrderingComposer,
          $$PaymentsTableAnnotationComposer,
          $$PaymentsTableCreateCompanionBuilder,
          $$PaymentsTableUpdateCompanionBuilder,
          (
            PaymentRow,
            BaseReferences<_$AppDatabase, $PaymentsTable, PaymentRow>,
          ),
          PaymentRow,
          PrefetchHooks Function()
        > {
  $$PaymentsTableTableManager(_$AppDatabase db, $PaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<bool> isRefund = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion(
                id: id,
                sessionId: sessionId,
                amountPaise: amountPaise,
                method: method,
                isRefund: isRefund,
                note: note,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required int amountPaise,
                required String method,
                Value<bool> isRefund = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion.insert(
                id: id,
                sessionId: sessionId,
                amountPaise: amountPaise,
                method: method,
                isRefund: isRefund,
                note: note,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PaymentsTable, PaymentRow>(table),
                  BaseReferences<_$AppDatabase, $PaymentsTable, PaymentRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PaymentsTable,
      PaymentRow,
      $$PaymentsTableFilterComposer,
      $$PaymentsTableOrderingComposer,
      $$PaymentsTableAnnotationComposer,
      $$PaymentsTableCreateCompanionBuilder,
      $$PaymentsTableUpdateCompanionBuilder,
      (PaymentRow, BaseReferences<_$AppDatabase, $PaymentsTable, PaymentRow>),
      PaymentRow,
      PrefetchHooks Function()
    >;
typedef $$BookingsTableCreateCompanionBuilder = BookingsCompanion Function({
  required String id,
  Value<String?> customerId,
  required String activityCode,
  Value<String?> gameId,
  Value<String?> resourceId,
  required DateTime scheduledStart,
  required DateTime scheduledEnd,
  Value<int?> playersRequired,
  Value<int?> controllerRequirement,
  required String status,
  Value<String?> partyName,
  Value<String?> phone,
  Value<String?> notes,
  Value<String> reminderStatus,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$BookingsTableUpdateCompanionBuilder = BookingsCompanion Function({
  Value<String> id,
  Value<String?> customerId,
  Value<String> activityCode,
  Value<String?> gameId,
  Value<String?> resourceId,
  Value<DateTime> scheduledStart,
  Value<DateTime> scheduledEnd,
  Value<int?> playersRequired,
  Value<int?> controllerRequirement,
  Value<String> status,
  Value<String?> partyName,
  Value<String?> phone,
  Value<String?> notes,
  Value<String> reminderStatus,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$BookingsTableFilterComposer
    extends Composer<_$AppDatabase, $BookingsTable> {
  $$BookingsTableFilterComposer({
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

  ColumnFilters<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledStart => $composableBuilder(
    column: $table.scheduledStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledEnd => $composableBuilder(
    column: $table.scheduledEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playersRequired => $composableBuilder(
    column: $table.playersRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get controllerRequirement => $composableBuilder(
    column: $table.controllerRequirement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partyName => $composableBuilder(
    column: $table.partyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderStatus => $composableBuilder(
    column: $table.reminderStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookingsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookingsTable> {
  $$BookingsTableOrderingComposer({
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

  ColumnOrderings<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledStart => $composableBuilder(
    column: $table.scheduledStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledEnd => $composableBuilder(
    column: $table.scheduledEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playersRequired => $composableBuilder(
    column: $table.playersRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get controllerRequirement => $composableBuilder(
    column: $table.controllerRequirement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partyName => $composableBuilder(
    column: $table.partyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderStatus => $composableBuilder(
    column: $table.reminderStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookingsTable> {
  $$BookingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get customerId => $composableBuilder(
    column: $table.customerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityCode => $composableBuilder(
    column: $table.activityCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get resourceId => $composableBuilder(
    column: $table.resourceId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scheduledStart => $composableBuilder(
    column: $table.scheduledStart,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scheduledEnd => $composableBuilder(
    column: $table.scheduledEnd,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playersRequired => $composableBuilder(
    column: $table.playersRequired,
    builder: (column) => column,
  );

  GeneratedColumn<int> get controllerRequirement => $composableBuilder(
    column: $table.controllerRequirement,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get partyName =>
      $composableBuilder(column: $table.partyName, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get reminderStatus => $composableBuilder(
    column: $table.reminderStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookingsTable,
          BookingRow,
          $$BookingsTableFilterComposer,
          $$BookingsTableOrderingComposer,
          $$BookingsTableAnnotationComposer,
          $$BookingsTableCreateCompanionBuilder,
          $$BookingsTableUpdateCompanionBuilder,
          (
            BookingRow,
            BaseReferences<_$AppDatabase, $BookingsTable, BookingRow>,
          ),
          BookingRow,
          PrefetchHooks Function()
        > {
  $$BookingsTableTableManager(_$AppDatabase db, $BookingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String> activityCode = const Value.absent(),
                Value<String?> gameId = const Value.absent(),
                Value<String?> resourceId = const Value.absent(),
                Value<DateTime> scheduledStart = const Value.absent(),
                Value<DateTime> scheduledEnd = const Value.absent(),
                Value<int?> playersRequired = const Value.absent(),
                Value<int?> controllerRequirement = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> partyName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> reminderStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookingsCompanion(
                id: id,
                customerId: customerId,
                activityCode: activityCode,
                gameId: gameId,
                resourceId: resourceId,
                scheduledStart: scheduledStart,
                scheduledEnd: scheduledEnd,
                playersRequired: playersRequired,
                controllerRequirement: controllerRequirement,
                status: status,
                partyName: partyName,
                phone: phone,
                notes: notes,
                reminderStatus: reminderStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> customerId = const Value.absent(),
                required String activityCode,
                Value<String?> gameId = const Value.absent(),
                Value<String?> resourceId = const Value.absent(),
                required DateTime scheduledStart,
                required DateTime scheduledEnd,
                Value<int?> playersRequired = const Value.absent(),
                Value<int?> controllerRequirement = const Value.absent(),
                required String status,
                Value<String?> partyName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> reminderStatus = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BookingsCompanion.insert(
                id: id,
                customerId: customerId,
                activityCode: activityCode,
                gameId: gameId,
                resourceId: resourceId,
                scheduledStart: scheduledStart,
                scheduledEnd: scheduledEnd,
                playersRequired: playersRequired,
                controllerRequirement: controllerRequirement,
                status: status,
                partyName: partyName,
                phone: phone,
                notes: notes,
                reminderStatus: reminderStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookingsTable, BookingRow>(table),
                  BaseReferences<_$AppDatabase, $BookingsTable, BookingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookingsTable,
      BookingRow,
      $$BookingsTableFilterComposer,
      $$BookingsTableOrderingComposer,
      $$BookingsTableAnnotationComposer,
      $$BookingsTableCreateCompanionBuilder,
      $$BookingsTableUpdateCompanionBuilder,
      (BookingRow, BaseReferences<_$AppDatabase, $BookingsTable, BookingRow>),
      BookingRow,
      PrefetchHooks Function()
    >;
typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  required String id,
  required String name,
  required List<String> perms,
  Value<bool> active,
  Value<int> sortOrder,
  Value<String?> pinSalt,
  Value<String?> pinHash,
  Value<int?> pinIterations,
  Value<int> failedAttempts,
  Value<DateTime?> lockedUntilAt,
  Value<int> rowid,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<List<String>> perms,
  Value<bool> active,
  Value<int> sortOrder,
  Value<String?> pinSalt,
  Value<String?> pinHash,
  Value<int?> pinIterations,
  Value<int> failedAttempts,
  Value<DateTime?> lockedUntilAt,
  Value<int> rowid,
});

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get perms => $composableBuilder(
    column: $table.perms,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinSalt => $composableBuilder(
    column: $table.pinSalt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinIterations => $composableBuilder(
    column: $table.pinIterations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lockedUntilAt => $composableBuilder(
    column: $table.lockedUntilAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get perms => $composableBuilder(
    column: $table.perms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinSalt => $composableBuilder(
    column: $table.pinSalt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinIterations => $composableBuilder(
    column: $table.pinIterations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lockedUntilAt => $composableBuilder(
    column: $table.lockedUntilAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get perms =>
      $composableBuilder(column: $table.perms, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get pinSalt =>
      $composableBuilder(column: $table.pinSalt, builder: (column) => column);

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumn<int> get pinIterations => $composableBuilder(
    column: $table.pinIterations,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failedAttempts => $composableBuilder(
    column: $table.failedAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lockedUntilAt => $composableBuilder(
    column: $table.lockedUntilAt,
    builder: (column) => column,
  );
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          UserRow,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (UserRow, BaseReferences<_$AppDatabase, $UsersTable, UserRow>),
          UserRow,
          PrefetchHooks Function()
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<List<String>> perms = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> pinSalt = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<int?> pinIterations = const Value.absent(),
                Value<int> failedAttempts = const Value.absent(),
                Value<DateTime?> lockedUntilAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                name: name,
                perms: perms,
                active: active,
                sortOrder: sortOrder,
                pinSalt: pinSalt,
                pinHash: pinHash,
                pinIterations: pinIterations,
                failedAttempts: failedAttempts,
                lockedUntilAt: lockedUntilAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required List<String> perms,
                Value<bool> active = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> pinSalt = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<int?> pinIterations = const Value.absent(),
                Value<int> failedAttempts = const Value.absent(),
                Value<DateTime?> lockedUntilAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                name: name,
                perms: perms,
                active: active,
                sortOrder: sortOrder,
                pinSalt: pinSalt,
                pinHash: pinHash,
                pinIterations: pinIterations,
                failedAttempts: failedAttempts,
                lockedUntilAt: lockedUntilAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UsersTable, UserRow>(table),
                  BaseReferences<_$AppDatabase, $UsersTable, UserRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      UserRow,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (UserRow, BaseReferences<_$AppDatabase, $UsersTable, UserRow>),
      UserRow,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> seq,
  required String opId,
  required String kind,
  required String entityType,
  required String entityId,
  required String payload,
  required String status,
  Value<int> attempts,
  Value<String?> errorCode,
  Value<String?> errorDetail,
  Value<String?> result,
  Value<bool> needsRefetch,
  Value<String?> actorId,
  required DateTime createdAt,
  Value<DateTime?> lastAttemptAt,
  Value<DateTime?> resolvedAt,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> seq,
  Value<String> opId,
  Value<String> kind,
  Value<String> entityType,
  Value<String> entityId,
  Value<String> payload,
  Value<String> status,
  Value<int> attempts,
  Value<String?> errorCode,
  Value<String?> errorDetail,
  Value<String?> result,
  Value<bool> needsRefetch,
  Value<String?> actorId,
  Value<DateTime> createdAt,
  Value<DateTime?> lastAttemptAt,
  Value<DateTime?> resolvedAt,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsRefetch => $composableBuilder(
    column: $table.needsRefetch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opId => $composableBuilder(
    column: $table.opId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsRefetch => $composableBuilder(
    column: $table.needsRefetch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get opId =>
      $composableBuilder(column: $table.opId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<bool> get needsRefetch => $composableBuilder(
    column: $table.needsRefetch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
    column: $table.lastAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          SyncOutboxRow,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            SyncOutboxRow,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxRow>,
          ),
          SyncOutboxRow,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> opId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorDetail = const Value.absent(),
                Value<String?> result = const Value.absent(),
                Value<bool> needsRefetch = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
              }) => SyncOutboxCompanion(
                seq: seq,
                opId: opId,
                kind: kind,
                entityType: entityType,
                entityId: entityId,
                payload: payload,
                status: status,
                attempts: attempts,
                errorCode: errorCode,
                errorDetail: errorDetail,
                result: result,
                needsRefetch: needsRefetch,
                actorId: actorId,
                createdAt: createdAt,
                lastAttemptAt: lastAttemptAt,
                resolvedAt: resolvedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String opId,
                required String kind,
                required String entityType,
                required String entityId,
                required String payload,
                required String status,
                Value<int> attempts = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorDetail = const Value.absent(),
                Value<String?> result = const Value.absent(),
                Value<bool> needsRefetch = const Value.absent(),
                Value<String?> actorId = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastAttemptAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                seq: seq,
                opId: opId,
                kind: kind,
                entityType: entityType,
                entityId: entityId,
                payload: payload,
                status: status,
                attempts: attempts,
                errorCode: errorCode,
                errorDetail: errorDetail,
                result: result,
                needsRefetch: needsRefetch,
                actorId: actorId,
                createdAt: createdAt,
                lastAttemptAt: lastAttemptAt,
                resolvedAt: resolvedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxTable, SyncOutboxRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncOutboxTable,
                    SyncOutboxRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      SyncOutboxRow,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        SyncOutboxRow,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxRow>,
      ),
      SyncOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaTableCreateCompanionBuilder = SyncMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncMetaTableUpdateCompanionBuilder = SyncMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          SyncMetaRow,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaRow,
            BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaRow>,
          ),
          SyncMetaRow,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncMetaTable, SyncMetaRow>(table),
                  BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      SyncMetaRow,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (SyncMetaRow, BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaRow>),
      SyncMetaRow,
      PrefetchHooks Function()
    >;
typedef $$SyncVersionsTableCreateCompanionBuilder =
    SyncVersionsCompanion Function({
      required String entity,
      required String rowId,
      required String version,
      Value<int> rowid,
    });
typedef $$SyncVersionsTableUpdateCompanionBuilder =
    SyncVersionsCompanion Function({
      Value<String> entity,
      Value<String> rowId,
      Value<String> version,
      Value<int> rowid,
    });

class $$SyncVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncVersionsTable> {
  $$SyncVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncVersionsTable> {
  $$SyncVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncVersionsTable> {
  $$SyncVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$SyncVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncVersionsTable,
          SyncVersionRow,
          $$SyncVersionsTableFilterComposer,
          $$SyncVersionsTableOrderingComposer,
          $$SyncVersionsTableAnnotationComposer,
          $$SyncVersionsTableCreateCompanionBuilder,
          $$SyncVersionsTableUpdateCompanionBuilder,
          (
            SyncVersionRow,
            BaseReferences<_$AppDatabase, $SyncVersionsTable, SyncVersionRow>,
          ),
          SyncVersionRow,
          PrefetchHooks Function()
        > {
  $$SyncVersionsTableTableManager(_$AppDatabase db, $SyncVersionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<String> rowId = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncVersionsCompanion(
                entity: entity,
                rowId: rowId,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                required String rowId,
                required String version,
                Value<int> rowid = const Value.absent(),
              }) => SyncVersionsCompanion.insert(
                entity: entity,
                rowId: rowId,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncVersionsTable, SyncVersionRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncVersionsTable,
                    SyncVersionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncVersionsTable,
      SyncVersionRow,
      $$SyncVersionsTableFilterComposer,
      $$SyncVersionsTableOrderingComposer,
      $$SyncVersionsTableAnnotationComposer,
      $$SyncVersionsTableCreateCompanionBuilder,
      $$SyncVersionsTableUpdateCompanionBuilder,
      (
        SyncVersionRow,
        BaseReferences<_$AppDatabase, $SyncVersionsTable, SyncVersionRow>,
      ),
      SyncVersionRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db, _db.customers);
  $$ActivitiesTableTableManager get activities =>
      $$ActivitiesTableTableManager(_db, _db.activities);
  $$ResourcesTableTableManager get resources =>
      $$ResourcesTableTableManager(_db, _db.resources);
  $$ResourceActivitiesTableTableManager get resourceActivities =>
      $$ResourceActivitiesTableTableManager(_db, _db.resourceActivities);
  $$ControllersTableTableManager get controllers =>
      $$ControllersTableTableManager(_db, _db.controllers);
  $$ControllerAllocationsTableTableManager get controllerAllocations =>
      $$ControllerAllocationsTableTableManager(_db, _db.controllerAllocations);
  $$ControllerMovesTableTableManager get controllerMoves =>
      $$ControllerMovesTableTableManager(_db, _db.controllerMoves);
  $$GameCategoriesTableTableManager get gameCategories =>
      $$GameCategoriesTableTableManager(_db, _db.gameCategories);
  $$GamesTableTableManager get games =>
      $$GamesTableTableManager(_db, _db.games);
  $$GameResourcesTableTableManager get gameResources =>
      $$GameResourcesTableTableManager(_db, _db.gameResources);
  $$GameControlsTableTableManager get gameControls =>
      $$GameControlsTableTableManager(_db, _db.gameControls);
  $$RatesTableTableManager get rates =>
      $$RatesTableTableManager(_db, _db.rates);
  $$BillingPoliciesTableTableManager get billingPolicies =>
      $$BillingPoliciesTableTableManager(_db, _db.billingPolicies);
  $$HolidaysTableTableManager get holidays =>
      $$HolidaysTableTableManager(_db, _db.holidays);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$PricingRulesTableTableManager get pricingRules =>
      $$PricingRulesTableTableManager(_db, _db.pricingRules);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SessionSegmentsTableTableManager get sessionSegments =>
      $$SessionSegmentsTableTableManager(_db, _db.sessionSegments);
  $$SessionExtensionsTableTableManager get sessionExtensions =>
      $$SessionExtensionsTableTableManager(_db, _db.sessionExtensions);
  $$SessionChargesTableTableManager get sessionCharges =>
      $$SessionChargesTableTableManager(_db, _db.sessionCharges);
  $$PaymentsTableTableManager get payments =>
      $$PaymentsTableTableManager(_db, _db.payments);
  $$BookingsTableTableManager get bookings =>
      $$BookingsTableTableManager(_db, _db.bookings);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
  $$SyncVersionsTableTableManager get syncVersions =>
      $$SyncVersionsTableTableManager(_db, _db.syncVersions);
}
