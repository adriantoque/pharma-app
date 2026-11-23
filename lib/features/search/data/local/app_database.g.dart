// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MedicineRowsTable extends MedicineRows
    with TableInfo<$MedicineRowsTable, MedicineRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MedicineRowsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packageTypeMeta = const VerificationMeta(
    'packageType',
  );
  @override
  late final GeneratedColumn<String> packageType = GeneratedColumn<String>(
    'package_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usageIndicationMeta = const VerificationMeta(
    'usageIndication',
  );
  @override
  late final GeneratedColumn<String> usageIndication = GeneratedColumn<String>(
    'usage_indication',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceCentavosMeta = const VerificationMeta(
    'priceCentavos',
  );
  @override
  late final GeneratedColumn<int> priceCentavos = GeneratedColumn<int>(
    'price_centavos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stockMeta = const VerificationMeta('stock');
  @override
  late final GeneratedColumn<int> stock = GeneratedColumn<int>(
    'stock',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aliasesMeta = const VerificationMeta(
    'aliases',
  );
  @override
  late final GeneratedColumn<String> aliases = GeneratedColumn<String>(
    'aliases',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _genericKeyMeta = const VerificationMeta(
    'genericKey',
  );
  @override
  late final GeneratedColumn<String> genericKey = GeneratedColumn<String>(
    'generic_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiryDateMeta = const VerificationMeta(
    'expiryDate',
  );
  @override
  late final GeneratedColumn<String> expiryDate = GeneratedColumn<String>(
    'expiry_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requiresRxMeta = const VerificationMeta(
    'requiresRx',
  );
  @override
  late final GeneratedColumn<bool> requiresRx = GeneratedColumn<bool>(
    'requires_rx',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_rx" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dosageInfoMeta = const VerificationMeta(
    'dosageInfo',
  );
  @override
  late final GeneratedColumn<String> dosageInfo = GeneratedColumn<String>(
    'dosage_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cautionsMeta = const VerificationMeta(
    'cautions',
  );
  @override
  late final GeneratedColumn<String> cautions = GeneratedColumn<String>(
    'cautions',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ageGroupMeta = const VerificationMeta(
    'ageGroup',
  );
  @override
  late final GeneratedColumn<String> ageGroup = GeneratedColumn<String>(
    'age_group',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('both'),
  );
  static const VerificationMeta _ageGuidanceMeta = const VerificationMeta(
    'ageGuidance',
  );
  @override
  late final GeneratedColumn<String> ageGuidance = GeneratedColumn<String>(
    'age_guidance',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    productId,
    packageType,
    usageIndication,
    priceCentavos,
    stock,
    aliases,
    genericKey,
    expiryDate,
    requiresRx,
    category,
    dosageInfo,
    cautions,
    ageGroup,
    ageGuidance,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'medicine_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MedicineRow> instance, {
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
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    }
    if (data.containsKey('package_type')) {
      context.handle(
        _packageTypeMeta,
        packageType.isAcceptableOrUnknown(
          data['package_type']!,
          _packageTypeMeta,
        ),
      );
    }
    if (data.containsKey('usage_indication')) {
      context.handle(
        _usageIndicationMeta,
        usageIndication.isAcceptableOrUnknown(
          data['usage_indication']!,
          _usageIndicationMeta,
        ),
      );
    }
    if (data.containsKey('price_centavos')) {
      context.handle(
        _priceCentavosMeta,
        priceCentavos.isAcceptableOrUnknown(
          data['price_centavos']!,
          _priceCentavosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_priceCentavosMeta);
    }
    if (data.containsKey('stock')) {
      context.handle(
        _stockMeta,
        stock.isAcceptableOrUnknown(data['stock']!, _stockMeta),
      );
    }
    if (data.containsKey('aliases')) {
      context.handle(
        _aliasesMeta,
        aliases.isAcceptableOrUnknown(data['aliases']!, _aliasesMeta),
      );
    }
    if (data.containsKey('generic_key')) {
      context.handle(
        _genericKeyMeta,
        genericKey.isAcceptableOrUnknown(data['generic_key']!, _genericKeyMeta),
      );
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
        _expiryDateMeta,
        expiryDate.isAcceptableOrUnknown(data['expiry_date']!, _expiryDateMeta),
      );
    }
    if (data.containsKey('requires_rx')) {
      context.handle(
        _requiresRxMeta,
        requiresRx.isAcceptableOrUnknown(data['requires_rx']!, _requiresRxMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('dosage_info')) {
      context.handle(
        _dosageInfoMeta,
        dosageInfo.isAcceptableOrUnknown(data['dosage_info']!, _dosageInfoMeta),
      );
    }
    if (data.containsKey('cautions')) {
      context.handle(
        _cautionsMeta,
        cautions.isAcceptableOrUnknown(data['cautions']!, _cautionsMeta),
      );
    }
    if (data.containsKey('age_group')) {
      context.handle(
        _ageGroupMeta,
        ageGroup.isAcceptableOrUnknown(data['age_group']!, _ageGroupMeta),
      );
    }
    if (data.containsKey('age_guidance')) {
      context.handle(
        _ageGuidanceMeta,
        ageGuidance.isAcceptableOrUnknown(
          data['age_guidance']!,
          _ageGuidanceMeta,
        ),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MedicineRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MedicineRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      ),
      packageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}package_type'],
      ),
      usageIndication: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}usage_indication'],
      ),
      priceCentavos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price_centavos'],
      )!,
      stock: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stock'],
      ),
      aliases: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aliases'],
      )!,
      genericKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}generic_key'],
      ),
      expiryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expiry_date'],
      ),
      requiresRx: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_rx'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      dosageInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dosage_info'],
      ),
      cautions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cautions'],
      ),
      ageGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}age_group'],
      )!,
      ageGuidance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}age_guidance'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $MedicineRowsTable createAlias(String alias) {
    return $MedicineRowsTable(attachedDatabase, alias);
  }
}

class MedicineRow extends DataClass implements Insertable<MedicineRow> {
  /// The line's identity: [MedicineModel.documentId], the FNV-1a hash the model
  /// derives from its product id (or name, package and price). Primary key, so
  /// a re-import of the same spreadsheet updates the row in place instead of
  /// duplicating it -- the same rule the Firestore collection follows.
  final String id;
  final String name;
  final String? productId;
  final String? packageType;
  final String? usageIndication;

  /// Centavos, integer, for the same reason [MedicineModel.priceCentavos] is.
  final int priceCentavos;

  /// Units on the shelf, or null when nobody has counted them. Null is a real
  /// state here exactly as it is in the model: a count that failed to parse
  /// must read as uncounted, never as zero.
  final int? stock;

  /// JSON list of alternative spellings.
  final String aliases;
  final String? genericKey;

  /// The shelf expiry as `yyyy-MM-dd`, or null. Deliberately a string, matching
  /// how the Firestore documents and the offline overlay store it: a date with
  /// no time of day must not grow one in a different column type.
  final String? expiryDate;
  final bool requiresRx;
  final String? category;
  final String? dosageInfo;
  final String? cautions;
  final String ageGroup;

  /// JSON object `{kids, teens, adults, seniors}`, or null when not recorded.
  final String? ageGuidance;

  /// Millis since epoch of the last write, for no behaviour -- kept so a future
  /// sync decision ("which row is newer") does not have to invent the column.
  final int? updatedAt;
  const MedicineRow({
    required this.id,
    required this.name,
    this.productId,
    this.packageType,
    this.usageIndication,
    required this.priceCentavos,
    this.stock,
    required this.aliases,
    this.genericKey,
    this.expiryDate,
    required this.requiresRx,
    this.category,
    this.dosageInfo,
    this.cautions,
    required this.ageGroup,
    this.ageGuidance,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    if (!nullToAbsent || packageType != null) {
      map['package_type'] = Variable<String>(packageType);
    }
    if (!nullToAbsent || usageIndication != null) {
      map['usage_indication'] = Variable<String>(usageIndication);
    }
    map['price_centavos'] = Variable<int>(priceCentavos);
    if (!nullToAbsent || stock != null) {
      map['stock'] = Variable<int>(stock);
    }
    map['aliases'] = Variable<String>(aliases);
    if (!nullToAbsent || genericKey != null) {
      map['generic_key'] = Variable<String>(genericKey);
    }
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<String>(expiryDate);
    }
    map['requires_rx'] = Variable<bool>(requiresRx);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || dosageInfo != null) {
      map['dosage_info'] = Variable<String>(dosageInfo);
    }
    if (!nullToAbsent || cautions != null) {
      map['cautions'] = Variable<String>(cautions);
    }
    map['age_group'] = Variable<String>(ageGroup);
    if (!nullToAbsent || ageGuidance != null) {
      map['age_guidance'] = Variable<String>(ageGuidance);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    return map;
  }

  MedicineRowsCompanion toCompanion(bool nullToAbsent) {
    return MedicineRowsCompanion(
      id: Value(id),
      name: Value(name),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      packageType: packageType == null && nullToAbsent
          ? const Value.absent()
          : Value(packageType),
      usageIndication: usageIndication == null && nullToAbsent
          ? const Value.absent()
          : Value(usageIndication),
      priceCentavos: Value(priceCentavos),
      stock: stock == null && nullToAbsent
          ? const Value.absent()
          : Value(stock),
      aliases: Value(aliases),
      genericKey: genericKey == null && nullToAbsent
          ? const Value.absent()
          : Value(genericKey),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      requiresRx: Value(requiresRx),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      dosageInfo: dosageInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(dosageInfo),
      cautions: cautions == null && nullToAbsent
          ? const Value.absent()
          : Value(cautions),
      ageGroup: Value(ageGroup),
      ageGuidance: ageGuidance == null && nullToAbsent
          ? const Value.absent()
          : Value(ageGuidance),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory MedicineRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MedicineRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      productId: serializer.fromJson<String?>(json['productId']),
      packageType: serializer.fromJson<String?>(json['packageType']),
      usageIndication: serializer.fromJson<String?>(json['usageIndication']),
      priceCentavos: serializer.fromJson<int>(json['priceCentavos']),
      stock: serializer.fromJson<int?>(json['stock']),
      aliases: serializer.fromJson<String>(json['aliases']),
      genericKey: serializer.fromJson<String?>(json['genericKey']),
      expiryDate: serializer.fromJson<String?>(json['expiryDate']),
      requiresRx: serializer.fromJson<bool>(json['requiresRx']),
      category: serializer.fromJson<String?>(json['category']),
      dosageInfo: serializer.fromJson<String?>(json['dosageInfo']),
      cautions: serializer.fromJson<String?>(json['cautions']),
      ageGroup: serializer.fromJson<String>(json['ageGroup']),
      ageGuidance: serializer.fromJson<String?>(json['ageGuidance']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'productId': serializer.toJson<String?>(productId),
      'packageType': serializer.toJson<String?>(packageType),
      'usageIndication': serializer.toJson<String?>(usageIndication),
      'priceCentavos': serializer.toJson<int>(priceCentavos),
      'stock': serializer.toJson<int?>(stock),
      'aliases': serializer.toJson<String>(aliases),
      'genericKey': serializer.toJson<String?>(genericKey),
      'expiryDate': serializer.toJson<String?>(expiryDate),
      'requiresRx': serializer.toJson<bool>(requiresRx),
      'category': serializer.toJson<String?>(category),
      'dosageInfo': serializer.toJson<String?>(dosageInfo),
      'cautions': serializer.toJson<String?>(cautions),
      'ageGroup': serializer.toJson<String>(ageGroup),
      'ageGuidance': serializer.toJson<String?>(ageGuidance),
      'updatedAt': serializer.toJson<int?>(updatedAt),
    };
  }

  MedicineRow copyWith({
    String? id,
    String? name,
    Value<String?> productId = const Value.absent(),
    Value<String?> packageType = const Value.absent(),
    Value<String?> usageIndication = const Value.absent(),
    int? priceCentavos,
    Value<int?> stock = const Value.absent(),
    String? aliases,
    Value<String?> genericKey = const Value.absent(),
    Value<String?> expiryDate = const Value.absent(),
    bool? requiresRx,
    Value<String?> category = const Value.absent(),
    Value<String?> dosageInfo = const Value.absent(),
    Value<String?> cautions = const Value.absent(),
    String? ageGroup,
    Value<String?> ageGuidance = const Value.absent(),
    Value<int?> updatedAt = const Value.absent(),
  }) => MedicineRow(
    id: id ?? this.id,
    name: name ?? this.name,
    productId: productId.present ? productId.value : this.productId,
    packageType: packageType.present ? packageType.value : this.packageType,
    usageIndication: usageIndication.present
        ? usageIndication.value
        : this.usageIndication,
    priceCentavos: priceCentavos ?? this.priceCentavos,
    stock: stock.present ? stock.value : this.stock,
    aliases: aliases ?? this.aliases,
    genericKey: genericKey.present ? genericKey.value : this.genericKey,
    expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
    requiresRx: requiresRx ?? this.requiresRx,
    category: category.present ? category.value : this.category,
    dosageInfo: dosageInfo.present ? dosageInfo.value : this.dosageInfo,
    cautions: cautions.present ? cautions.value : this.cautions,
    ageGroup: ageGroup ?? this.ageGroup,
    ageGuidance: ageGuidance.present ? ageGuidance.value : this.ageGuidance,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  MedicineRow copyWithCompanion(MedicineRowsCompanion data) {
    return MedicineRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      productId: data.productId.present ? data.productId.value : this.productId,
      packageType: data.packageType.present
          ? data.packageType.value
          : this.packageType,
      usageIndication: data.usageIndication.present
          ? data.usageIndication.value
          : this.usageIndication,
      priceCentavos: data.priceCentavos.present
          ? data.priceCentavos.value
          : this.priceCentavos,
      stock: data.stock.present ? data.stock.value : this.stock,
      aliases: data.aliases.present ? data.aliases.value : this.aliases,
      genericKey: data.genericKey.present
          ? data.genericKey.value
          : this.genericKey,
      expiryDate: data.expiryDate.present
          ? data.expiryDate.value
          : this.expiryDate,
      requiresRx: data.requiresRx.present
          ? data.requiresRx.value
          : this.requiresRx,
      category: data.category.present ? data.category.value : this.category,
      dosageInfo: data.dosageInfo.present
          ? data.dosageInfo.value
          : this.dosageInfo,
      cautions: data.cautions.present ? data.cautions.value : this.cautions,
      ageGroup: data.ageGroup.present ? data.ageGroup.value : this.ageGroup,
      ageGuidance: data.ageGuidance.present
          ? data.ageGuidance.value
          : this.ageGuidance,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MedicineRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('productId: $productId, ')
          ..write('packageType: $packageType, ')
          ..write('usageIndication: $usageIndication, ')
          ..write('priceCentavos: $priceCentavos, ')
          ..write('stock: $stock, ')
          ..write('aliases: $aliases, ')
          ..write('genericKey: $genericKey, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('requiresRx: $requiresRx, ')
          ..write('category: $category, ')
          ..write('dosageInfo: $dosageInfo, ')
          ..write('cautions: $cautions, ')
          ..write('ageGroup: $ageGroup, ')
          ..write('ageGuidance: $ageGuidance, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    productId,
    packageType,
    usageIndication,
    priceCentavos,
    stock,
    aliases,
    genericKey,
    expiryDate,
    requiresRx,
    category,
    dosageInfo,
    cautions,
    ageGroup,
    ageGuidance,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MedicineRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.productId == this.productId &&
          other.packageType == this.packageType &&
          other.usageIndication == this.usageIndication &&
          other.priceCentavos == this.priceCentavos &&
          other.stock == this.stock &&
          other.aliases == this.aliases &&
          other.genericKey == this.genericKey &&
          other.expiryDate == this.expiryDate &&
          other.requiresRx == this.requiresRx &&
          other.category == this.category &&
          other.dosageInfo == this.dosageInfo &&
          other.cautions == this.cautions &&
          other.ageGroup == this.ageGroup &&
          other.ageGuidance == this.ageGuidance &&
          other.updatedAt == this.updatedAt);
}

class MedicineRowsCompanion extends UpdateCompanion<MedicineRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> productId;
  final Value<String?> packageType;
  final Value<String?> usageIndication;
  final Value<int> priceCentavos;
  final Value<int?> stock;
  final Value<String> aliases;
  final Value<String?> genericKey;
  final Value<String?> expiryDate;
  final Value<bool> requiresRx;
  final Value<String?> category;
  final Value<String?> dosageInfo;
  final Value<String?> cautions;
  final Value<String> ageGroup;
  final Value<String?> ageGuidance;
  final Value<int?> updatedAt;
  final Value<int> rowid;
  const MedicineRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.productId = const Value.absent(),
    this.packageType = const Value.absent(),
    this.usageIndication = const Value.absent(),
    this.priceCentavos = const Value.absent(),
    this.stock = const Value.absent(),
    this.aliases = const Value.absent(),
    this.genericKey = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.requiresRx = const Value.absent(),
    this.category = const Value.absent(),
    this.dosageInfo = const Value.absent(),
    this.cautions = const Value.absent(),
    this.ageGroup = const Value.absent(),
    this.ageGuidance = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MedicineRowsCompanion.insert({
    required String id,
    required String name,
    this.productId = const Value.absent(),
    this.packageType = const Value.absent(),
    this.usageIndication = const Value.absent(),
    required int priceCentavos,
    this.stock = const Value.absent(),
    this.aliases = const Value.absent(),
    this.genericKey = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.requiresRx = const Value.absent(),
    this.category = const Value.absent(),
    this.dosageInfo = const Value.absent(),
    this.cautions = const Value.absent(),
    this.ageGroup = const Value.absent(),
    this.ageGuidance = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       priceCentavos = Value(priceCentavos);
  static Insertable<MedicineRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? productId,
    Expression<String>? packageType,
    Expression<String>? usageIndication,
    Expression<int>? priceCentavos,
    Expression<int>? stock,
    Expression<String>? aliases,
    Expression<String>? genericKey,
    Expression<String>? expiryDate,
    Expression<bool>? requiresRx,
    Expression<String>? category,
    Expression<String>? dosageInfo,
    Expression<String>? cautions,
    Expression<String>? ageGroup,
    Expression<String>? ageGuidance,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (productId != null) 'product_id': productId,
      if (packageType != null) 'package_type': packageType,
      if (usageIndication != null) 'usage_indication': usageIndication,
      if (priceCentavos != null) 'price_centavos': priceCentavos,
      if (stock != null) 'stock': stock,
      if (aliases != null) 'aliases': aliases,
      if (genericKey != null) 'generic_key': genericKey,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (requiresRx != null) 'requires_rx': requiresRx,
      if (category != null) 'category': category,
      if (dosageInfo != null) 'dosage_info': dosageInfo,
      if (cautions != null) 'cautions': cautions,
      if (ageGroup != null) 'age_group': ageGroup,
      if (ageGuidance != null) 'age_guidance': ageGuidance,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MedicineRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? productId,
    Value<String?>? packageType,
    Value<String?>? usageIndication,
    Value<int>? priceCentavos,
    Value<int?>? stock,
    Value<String>? aliases,
    Value<String?>? genericKey,
    Value<String?>? expiryDate,
    Value<bool>? requiresRx,
    Value<String?>? category,
    Value<String?>? dosageInfo,
    Value<String?>? cautions,
    Value<String>? ageGroup,
    Value<String?>? ageGuidance,
    Value<int?>? updatedAt,
    Value<int>? rowid,
  }) {
    return MedicineRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      productId: productId ?? this.productId,
      packageType: packageType ?? this.packageType,
      usageIndication: usageIndication ?? this.usageIndication,
      priceCentavos: priceCentavos ?? this.priceCentavos,
      stock: stock ?? this.stock,
      aliases: aliases ?? this.aliases,
      genericKey: genericKey ?? this.genericKey,
      expiryDate: expiryDate ?? this.expiryDate,
      requiresRx: requiresRx ?? this.requiresRx,
      category: category ?? this.category,
      dosageInfo: dosageInfo ?? this.dosageInfo,
      cautions: cautions ?? this.cautions,
      ageGroup: ageGroup ?? this.ageGroup,
      ageGuidance: ageGuidance ?? this.ageGuidance,
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
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (packageType.present) {
      map['package_type'] = Variable<String>(packageType.value);
    }
    if (usageIndication.present) {
      map['usage_indication'] = Variable<String>(usageIndication.value);
    }
    if (priceCentavos.present) {
      map['price_centavos'] = Variable<int>(priceCentavos.value);
    }
    if (stock.present) {
      map['stock'] = Variable<int>(stock.value);
    }
    if (aliases.present) {
      map['aliases'] = Variable<String>(aliases.value);
    }
    if (genericKey.present) {
      map['generic_key'] = Variable<String>(genericKey.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<String>(expiryDate.value);
    }
    if (requiresRx.present) {
      map['requires_rx'] = Variable<bool>(requiresRx.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (dosageInfo.present) {
      map['dosage_info'] = Variable<String>(dosageInfo.value);
    }
    if (cautions.present) {
      map['cautions'] = Variable<String>(cautions.value);
    }
    if (ageGroup.present) {
      map['age_group'] = Variable<String>(ageGroup.value);
    }
    if (ageGuidance.present) {
      map['age_guidance'] = Variable<String>(ageGuidance.value);
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
    return (StringBuffer('MedicineRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('productId: $productId, ')
          ..write('packageType: $packageType, ')
          ..write('usageIndication: $usageIndication, ')
          ..write('priceCentavos: $priceCentavos, ')
          ..write('stock: $stock, ')
          ..write('aliases: $aliases, ')
          ..write('genericKey: $genericKey, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('requiresRx: $requiresRx, ')
          ..write('category: $category, ')
          ..write('dosageInfo: $dosageInfo, ')
          ..write('cautions: $cautions, ')
          ..write('ageGroup: $ageGroup, ')
          ..write('ageGuidance: $ageGuidance, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MedicineRowsTable medicineRows = $MedicineRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [medicineRows];
}

typedef $$MedicineRowsTableCreateCompanionBuilder =
    MedicineRowsCompanion Function({
      required String id,
      required String name,
      Value<String?> productId,
      Value<String?> packageType,
      Value<String?> usageIndication,
      required int priceCentavos,
      Value<int?> stock,
      Value<String> aliases,
      Value<String?> genericKey,
      Value<String?> expiryDate,
      Value<bool> requiresRx,
      Value<String?> category,
      Value<String?> dosageInfo,
      Value<String?> cautions,
      Value<String> ageGroup,
      Value<String?> ageGuidance,
      Value<int?> updatedAt,
      Value<int> rowid,
    });
typedef $$MedicineRowsTableUpdateCompanionBuilder =
    MedicineRowsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> productId,
      Value<String?> packageType,
      Value<String?> usageIndication,
      Value<int> priceCentavos,
      Value<int?> stock,
      Value<String> aliases,
      Value<String?> genericKey,
      Value<String?> expiryDate,
      Value<bool> requiresRx,
      Value<String?> category,
      Value<String?> dosageInfo,
      Value<String?> cautions,
      Value<String> ageGroup,
      Value<String?> ageGuidance,
      Value<int?> updatedAt,
      Value<int> rowid,
    });

class $$MedicineRowsTableFilterComposer
    extends Composer<_$AppDatabase, $MedicineRowsTable> {
  $$MedicineRowsTableFilterComposer({
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

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get packageType => $composableBuilder(
    column: $table.packageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usageIndication => $composableBuilder(
    column: $table.usageIndication,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priceCentavos => $composableBuilder(
    column: $table.priceCentavos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stock => $composableBuilder(
    column: $table.stock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genericKey => $composableBuilder(
    column: $table.genericKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresRx => $composableBuilder(
    column: $table.requiresRx,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dosageInfo => $composableBuilder(
    column: $table.dosageInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cautions => $composableBuilder(
    column: $table.cautions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ageGroup => $composableBuilder(
    column: $table.ageGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ageGuidance => $composableBuilder(
    column: $table.ageGuidance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MedicineRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $MedicineRowsTable> {
  $$MedicineRowsTableOrderingComposer({
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

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get packageType => $composableBuilder(
    column: $table.packageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usageIndication => $composableBuilder(
    column: $table.usageIndication,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priceCentavos => $composableBuilder(
    column: $table.priceCentavos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stock => $composableBuilder(
    column: $table.stock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliases => $composableBuilder(
    column: $table.aliases,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genericKey => $composableBuilder(
    column: $table.genericKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresRx => $composableBuilder(
    column: $table.requiresRx,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dosageInfo => $composableBuilder(
    column: $table.dosageInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cautions => $composableBuilder(
    column: $table.cautions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ageGroup => $composableBuilder(
    column: $table.ageGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ageGuidance => $composableBuilder(
    column: $table.ageGuidance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MedicineRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MedicineRowsTable> {
  $$MedicineRowsTableAnnotationComposer({
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

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get packageType => $composableBuilder(
    column: $table.packageType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get usageIndication => $composableBuilder(
    column: $table.usageIndication,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priceCentavos => $composableBuilder(
    column: $table.priceCentavos,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stock =>
      $composableBuilder(column: $table.stock, builder: (column) => column);

  GeneratedColumn<String> get aliases =>
      $composableBuilder(column: $table.aliases, builder: (column) => column);

  GeneratedColumn<String> get genericKey => $composableBuilder(
    column: $table.genericKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requiresRx => $composableBuilder(
    column: $table.requiresRx,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get dosageInfo => $composableBuilder(
    column: $table.dosageInfo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cautions =>
      $composableBuilder(column: $table.cautions, builder: (column) => column);

  GeneratedColumn<String> get ageGroup =>
      $composableBuilder(column: $table.ageGroup, builder: (column) => column);

  GeneratedColumn<String> get ageGuidance => $composableBuilder(
    column: $table.ageGuidance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MedicineRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MedicineRowsTable,
          MedicineRow,
          $$MedicineRowsTableFilterComposer,
          $$MedicineRowsTableOrderingComposer,
          $$MedicineRowsTableAnnotationComposer,
          $$MedicineRowsTableCreateCompanionBuilder,
          $$MedicineRowsTableUpdateCompanionBuilder,
          (
            MedicineRow,
            BaseReferences<_$AppDatabase, $MedicineRowsTable, MedicineRow>,
          ),
          MedicineRow,
          PrefetchHooks Function()
        > {
  $$MedicineRowsTableTableManager(_$AppDatabase db, $MedicineRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MedicineRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MedicineRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MedicineRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<String?> packageType = const Value.absent(),
                Value<String?> usageIndication = const Value.absent(),
                Value<int> priceCentavos = const Value.absent(),
                Value<int?> stock = const Value.absent(),
                Value<String> aliases = const Value.absent(),
                Value<String?> genericKey = const Value.absent(),
                Value<String?> expiryDate = const Value.absent(),
                Value<bool> requiresRx = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> dosageInfo = const Value.absent(),
                Value<String?> cautions = const Value.absent(),
                Value<String> ageGroup = const Value.absent(),
                Value<String?> ageGuidance = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MedicineRowsCompanion(
                id: id,
                name: name,
                productId: productId,
                packageType: packageType,
                usageIndication: usageIndication,
                priceCentavos: priceCentavos,
                stock: stock,
                aliases: aliases,
                genericKey: genericKey,
                expiryDate: expiryDate,
                requiresRx: requiresRx,
                category: category,
                dosageInfo: dosageInfo,
                cautions: cautions,
                ageGroup: ageGroup,
                ageGuidance: ageGuidance,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> productId = const Value.absent(),
                Value<String?> packageType = const Value.absent(),
                Value<String?> usageIndication = const Value.absent(),
                required int priceCentavos,
                Value<int?> stock = const Value.absent(),
                Value<String> aliases = const Value.absent(),
                Value<String?> genericKey = const Value.absent(),
                Value<String?> expiryDate = const Value.absent(),
                Value<bool> requiresRx = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> dosageInfo = const Value.absent(),
                Value<String?> cautions = const Value.absent(),
                Value<String> ageGroup = const Value.absent(),
                Value<String?> ageGuidance = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MedicineRowsCompanion.insert(
                id: id,
                name: name,
                productId: productId,
                packageType: packageType,
                usageIndication: usageIndication,
                priceCentavos: priceCentavos,
                stock: stock,
                aliases: aliases,
                genericKey: genericKey,
                expiryDate: expiryDate,
                requiresRx: requiresRx,
                category: category,
                dosageInfo: dosageInfo,
                cautions: cautions,
                ageGroup: ageGroup,
                ageGuidance: ageGuidance,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MedicineRowsTable, MedicineRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MedicineRowsTable,
                    MedicineRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MedicineRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MedicineRowsTable,
      MedicineRow,
      $$MedicineRowsTableFilterComposer,
      $$MedicineRowsTableOrderingComposer,
      $$MedicineRowsTableAnnotationComposer,
      $$MedicineRowsTableCreateCompanionBuilder,
      $$MedicineRowsTableUpdateCompanionBuilder,
      (
        MedicineRow,
        BaseReferences<_$AppDatabase, $MedicineRowsTable, MedicineRow>,
      ),
      MedicineRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MedicineRowsTableTableManager get medicineRows =>
      $$MedicineRowsTableTableManager(_db, _db.medicineRows);
}
