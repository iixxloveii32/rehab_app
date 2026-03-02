// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_log.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSessionLogCollection on Isar {
  IsarCollection<SessionLog> get sessionLogs => this.collection();
}

const SessionLogSchema = CollectionSchema(
  name: r'SessionLog',
  id: -2594700486533071519,
  properties: {
    r'appVersion': PropertySchema(
      id: 0,
      name: r'appVersion',
      type: IsarType.string,
    ),
    r'attemptIndex': PropertySchema(
      id: 1,
      name: r'attemptIndex',
      type: IsarType.long,
    ),
    r'compensation': PropertySchema(
      id: 2,
      name: r'compensation',
      type: IsarType.long,
    ),
    r'dateKey': PropertySchema(
      id: 3,
      name: r'dateKey',
      type: IsarType.string,
    ),
    r'exerciseId': PropertySchema(
      id: 4,
      name: r'exerciseId',
      type: IsarType.long,
    ),
    r'featuresJson': PropertySchema(
      id: 5,
      name: r'featuresJson',
      type: IsarType.string,
    ),
    r'imitationVideoPath': PropertySchema(
      id: 6,
      name: r'imitationVideoPath',
      type: IsarType.string,
    ),
    r'isReference': PropertySchema(
      id: 7,
      name: r'isReference',
      type: IsarType.bool,
    ),
    r'overall': PropertySchema(
      id: 8,
      name: r'overall',
      type: IsarType.long,
    ),
    r'patientId': PropertySchema(
      id: 9,
      name: r'patientId',
      type: IsarType.long,
    ),
    r'qualityJson': PropertySchema(
      id: 10,
      name: r'qualityJson',
      type: IsarType.string,
    ),
    r'referenceVideoPath': PropertySchema(
      id: 11,
      name: r'referenceVideoPath',
      type: IsarType.string,
    ),
    r'rom': PropertySchema(
      id: 12,
      name: r'rom',
      type: IsarType.long,
    ),
    r'scoreSchemaVersion': PropertySchema(
      id: 13,
      name: r'scoreSchemaVersion',
      type: IsarType.long,
    ),
    r'sessionUuid': PropertySchema(
      id: 14,
      name: r'sessionUuid',
      type: IsarType.string,
    ),
    r'smoothness': PropertySchema(
      id: 15,
      name: r'smoothness',
      type: IsarType.long,
    ),
    r'symmetry': PropertySchema(
      id: 16,
      name: r'symmetry',
      type: IsarType.long,
    ),
    r'timestampKst': PropertySchema(
      id: 17,
      name: r'timestampKst',
      type: IsarType.dateTime,
    ),
    r'timing': PropertySchema(
      id: 18,
      name: r'timing',
      type: IsarType.long,
    )
  },
  estimateSize: _sessionLogEstimateSize,
  serialize: _sessionLogSerialize,
  deserialize: _sessionLogDeserialize,
  deserializeProp: _sessionLogDeserializeProp,
  idName: r'id',
  indexes: {
    r'patientId': IndexSchema(
      id: 403389457658259617,
      name: r'patientId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'patientId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'exerciseId': IndexSchema(
      id: -5431545612219001672,
      name: r'exerciseId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'exerciseId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'timestampKst': IndexSchema(
      id: 5341575572997193812,
      name: r'timestampKst',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'timestampKst',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'dateKey': IndexSchema(
      id: 7975223786082927131,
      name: r'dateKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'dateKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'sessionUuid': IndexSchema(
      id: 1105448749916514119,
      name: r'sessionUuid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sessionUuid',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'isReference': IndexSchema(
      id: -229470881069193118,
      name: r'isReference',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isReference',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _sessionLogGetId,
  getLinks: _sessionLogGetLinks,
  attach: _sessionLogAttach,
  version: '3.1.0+1',
);

int _sessionLogEstimateSize(
  SessionLog object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.appVersion.length * 3;
  bytesCount += 3 + object.dateKey.length * 3;
  {
    final value = object.featuresJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.imitationVideoPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.qualityJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.referenceVideoPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sessionUuid.length * 3;
  return bytesCount;
}

void _sessionLogSerialize(
  SessionLog object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.appVersion);
  writer.writeLong(offsets[1], object.attemptIndex);
  writer.writeLong(offsets[2], object.compensation);
  writer.writeString(offsets[3], object.dateKey);
  writer.writeLong(offsets[4], object.exerciseId);
  writer.writeString(offsets[5], object.featuresJson);
  writer.writeString(offsets[6], object.imitationVideoPath);
  writer.writeBool(offsets[7], object.isReference);
  writer.writeLong(offsets[8], object.overall);
  writer.writeLong(offsets[9], object.patientId);
  writer.writeString(offsets[10], object.qualityJson);
  writer.writeString(offsets[11], object.referenceVideoPath);
  writer.writeLong(offsets[12], object.rom);
  writer.writeLong(offsets[13], object.scoreSchemaVersion);
  writer.writeString(offsets[14], object.sessionUuid);
  writer.writeLong(offsets[15], object.smoothness);
  writer.writeLong(offsets[16], object.symmetry);
  writer.writeDateTime(offsets[17], object.timestampKst);
  writer.writeLong(offsets[18], object.timing);
}

SessionLog _sessionLogDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SessionLog();
  object.appVersion = reader.readString(offsets[0]);
  object.attemptIndex = reader.readLong(offsets[1]);
  object.compensation = reader.readLong(offsets[2]);
  object.dateKey = reader.readString(offsets[3]);
  object.exerciseId = reader.readLong(offsets[4]);
  object.featuresJson = reader.readStringOrNull(offsets[5]);
  object.id = id;
  object.imitationVideoPath = reader.readStringOrNull(offsets[6]);
  object.isReference = reader.readBool(offsets[7]);
  object.overall = reader.readLong(offsets[8]);
  object.patientId = reader.readLong(offsets[9]);
  object.qualityJson = reader.readStringOrNull(offsets[10]);
  object.referenceVideoPath = reader.readStringOrNull(offsets[11]);
  object.rom = reader.readLong(offsets[12]);
  object.scoreSchemaVersion = reader.readLong(offsets[13]);
  object.sessionUuid = reader.readString(offsets[14]);
  object.smoothness = reader.readLong(offsets[15]);
  object.symmetry = reader.readLong(offsets[16]);
  object.timestampKst = reader.readDateTime(offsets[17]);
  object.timing = reader.readLong(offsets[18]);
  return object;
}

P _sessionLogDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readStringOrNull(offset)) as P;
    case 12:
      return (reader.readLong(offset)) as P;
    case 13:
      return (reader.readLong(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (reader.readLong(offset)) as P;
    case 16:
      return (reader.readLong(offset)) as P;
    case 17:
      return (reader.readDateTime(offset)) as P;
    case 18:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _sessionLogGetId(SessionLog object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _sessionLogGetLinks(SessionLog object) {
  return [];
}

void _sessionLogAttach(IsarCollection<dynamic> col, Id id, SessionLog object) {
  object.id = id;
}

extension SessionLogQueryWhereSort
    on QueryBuilder<SessionLog, SessionLog, QWhere> {
  QueryBuilder<SessionLog, SessionLog, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhere> anyPatientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'patientId'),
      );
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhere> anyExerciseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'exerciseId'),
      );
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhere> anyTimestampKst() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'timestampKst'),
      );
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhere> anyIsReference() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isReference'),
      );
    });
  }
}

extension SessionLogQueryWhere
    on QueryBuilder<SessionLog, SessionLog, QWhereClause> {
  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> patientIdEqualTo(
      int patientId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'patientId',
        value: [patientId],
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> patientIdNotEqualTo(
      int patientId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'patientId',
              lower: [],
              upper: [patientId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'patientId',
              lower: [patientId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'patientId',
              lower: [patientId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'patientId',
              lower: [],
              upper: [patientId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> patientIdGreaterThan(
    int patientId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'patientId',
        lower: [patientId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> patientIdLessThan(
    int patientId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'patientId',
        lower: [],
        upper: [patientId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> patientIdBetween(
    int lowerPatientId,
    int upperPatientId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'patientId',
        lower: [lowerPatientId],
        includeLower: includeLower,
        upper: [upperPatientId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> exerciseIdEqualTo(
      int exerciseId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'exerciseId',
        value: [exerciseId],
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> exerciseIdNotEqualTo(
      int exerciseId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'exerciseId',
              lower: [],
              upper: [exerciseId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'exerciseId',
              lower: [exerciseId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'exerciseId',
              lower: [exerciseId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'exerciseId',
              lower: [],
              upper: [exerciseId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> exerciseIdGreaterThan(
    int exerciseId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'exerciseId',
        lower: [exerciseId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> exerciseIdLessThan(
    int exerciseId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'exerciseId',
        lower: [],
        upper: [exerciseId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> exerciseIdBetween(
    int lowerExerciseId,
    int upperExerciseId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'exerciseId',
        lower: [lowerExerciseId],
        includeLower: includeLower,
        upper: [upperExerciseId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> timestampKstEqualTo(
      DateTime timestampKst) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'timestampKst',
        value: [timestampKst],
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause>
      timestampKstNotEqualTo(DateTime timestampKst) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestampKst',
              lower: [],
              upper: [timestampKst],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestampKst',
              lower: [timestampKst],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestampKst',
              lower: [timestampKst],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestampKst',
              lower: [],
              upper: [timestampKst],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause>
      timestampKstGreaterThan(
    DateTime timestampKst, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestampKst',
        lower: [timestampKst],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> timestampKstLessThan(
    DateTime timestampKst, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestampKst',
        lower: [],
        upper: [timestampKst],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> timestampKstBetween(
    DateTime lowerTimestampKst,
    DateTime upperTimestampKst, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestampKst',
        lower: [lowerTimestampKst],
        includeLower: includeLower,
        upper: [upperTimestampKst],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> dateKeyEqualTo(
      String dateKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'dateKey',
        value: [dateKey],
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> dateKeyNotEqualTo(
      String dateKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'dateKey',
              lower: [],
              upper: [dateKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'dateKey',
              lower: [dateKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'dateKey',
              lower: [dateKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'dateKey',
              lower: [],
              upper: [dateKey],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> sessionUuidEqualTo(
      String sessionUuid) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sessionUuid',
        value: [sessionUuid],
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> sessionUuidNotEqualTo(
      String sessionUuid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionUuid',
              lower: [],
              upper: [sessionUuid],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionUuid',
              lower: [sessionUuid],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionUuid',
              lower: [sessionUuid],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionUuid',
              lower: [],
              upper: [sessionUuid],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> isReferenceEqualTo(
      bool isReference) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isReference',
        value: [isReference],
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterWhereClause> isReferenceNotEqualTo(
      bool isReference) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isReference',
              lower: [],
              upper: [isReference],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isReference',
              lower: [isReference],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isReference',
              lower: [isReference],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isReference',
              lower: [],
              upper: [isReference],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SessionLogQueryFilter
    on QueryBuilder<SessionLog, SessionLog, QFilterCondition> {
  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> appVersionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      appVersionGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      appVersionLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> appVersionBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'appVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      appVersionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      appVersionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      appVersionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'appVersion',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> appVersionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'appVersion',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      appVersionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'appVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      appVersionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'appVersion',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      attemptIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'attemptIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      attemptIndexGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'attemptIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      attemptIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'attemptIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      attemptIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'attemptIndex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      compensationEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'compensation',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      compensationGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'compensation',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      compensationLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'compensation',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      compensationBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'compensation',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> dateKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      dateKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> dateKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> dateKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dateKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> dateKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> dateKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> dateKeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> dateKeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dateKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> dateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dateKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      dateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dateKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> exerciseIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'exerciseId',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      exerciseIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'exerciseId',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      exerciseIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'exerciseId',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> exerciseIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'exerciseId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'featuresJson',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'featuresJson',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'featuresJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'featuresJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'featuresJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'featuresJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'featuresJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'featuresJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'featuresJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'featuresJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'featuresJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      featuresJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'featuresJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imitationVideoPath',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imitationVideoPath',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imitationVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'imitationVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'imitationVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'imitationVideoPath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'imitationVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'imitationVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imitationVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imitationVideoPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imitationVideoPath',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      imitationVideoPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imitationVideoPath',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      isReferenceEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isReference',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> overallEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'overall',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      overallGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'overall',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> overallLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'overall',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> overallBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'overall',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> patientIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'patientId',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      patientIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'patientId',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> patientIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'patientId',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> patientIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'patientId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'qualityJson',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'qualityJson',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'qualityJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'qualityJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'qualityJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'qualityJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'qualityJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'qualityJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'qualityJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'qualityJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'qualityJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      qualityJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'qualityJson',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'referenceVideoPath',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'referenceVideoPath',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'referenceVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'referenceVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'referenceVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'referenceVideoPath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'referenceVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'referenceVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'referenceVideoPath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'referenceVideoPath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'referenceVideoPath',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      referenceVideoPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'referenceVideoPath',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> romEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rom',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> romGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rom',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> romLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rom',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> romBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rom',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      scoreSchemaVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scoreSchemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      scoreSchemaVersionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'scoreSchemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      scoreSchemaVersionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'scoreSchemaVersion',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      scoreSchemaVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'scoreSchemaVersion',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      sessionUuidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      sessionUuidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sessionUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      sessionUuidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sessionUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      sessionUuidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sessionUuid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      sessionUuidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sessionUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      sessionUuidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sessionUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      sessionUuidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sessionUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      sessionUuidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sessionUuid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      sessionUuidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionUuid',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      sessionUuidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sessionUuid',
        value: '',
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> smoothnessEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'smoothness',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      smoothnessGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'smoothness',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      smoothnessLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'smoothness',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> smoothnessBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'smoothness',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> symmetryEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'symmetry',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      symmetryGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'symmetry',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> symmetryLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'symmetry',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> symmetryBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'symmetry',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      timestampKstEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestampKst',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      timestampKstGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestampKst',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      timestampKstLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestampKst',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition>
      timestampKstBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestampKst',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> timingEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timing',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> timingGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timing',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> timingLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timing',
        value: value,
      ));
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterFilterCondition> timingBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timing',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SessionLogQueryObject
    on QueryBuilder<SessionLog, SessionLog, QFilterCondition> {}

extension SessionLogQueryLinks
    on QueryBuilder<SessionLog, SessionLog, QFilterCondition> {}

extension SessionLogQuerySortBy
    on QueryBuilder<SessionLog, SessionLog, QSortBy> {
  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByAppVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appVersion', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByAppVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appVersion', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByAttemptIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptIndex', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByAttemptIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptIndex', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByCompensation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compensation', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByCompensationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compensation', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByDateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByDateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByExerciseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exerciseId', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByExerciseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exerciseId', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByFeaturesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'featuresJson', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByFeaturesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'featuresJson', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      sortByImitationVideoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imitationVideoPath', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      sortByImitationVideoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imitationVideoPath', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByIsReference() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReference', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByIsReferenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReference', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByOverall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'overall', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByOverallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'overall', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByPatientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientId', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByPatientIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientId', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByQualityJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qualityJson', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByQualityJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qualityJson', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      sortByReferenceVideoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'referenceVideoPath', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      sortByReferenceVideoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'referenceVideoPath', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByRom() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rom', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByRomDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rom', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      sortByScoreSchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scoreSchemaVersion', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      sortByScoreSchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scoreSchemaVersion', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortBySessionUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionUuid', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortBySessionUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionUuid', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortBySmoothness() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'smoothness', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortBySmoothnessDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'smoothness', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortBySymmetry() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'symmetry', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortBySymmetryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'symmetry', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByTimestampKst() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampKst', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByTimestampKstDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampKst', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByTiming() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timing', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> sortByTimingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timing', Sort.desc);
    });
  }
}

extension SessionLogQuerySortThenBy
    on QueryBuilder<SessionLog, SessionLog, QSortThenBy> {
  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByAppVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appVersion', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByAppVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'appVersion', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByAttemptIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptIndex', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByAttemptIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptIndex', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByCompensation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compensation', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByCompensationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'compensation', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByDateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByDateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByExerciseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exerciseId', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByExerciseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'exerciseId', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByFeaturesJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'featuresJson', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByFeaturesJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'featuresJson', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      thenByImitationVideoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imitationVideoPath', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      thenByImitationVideoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imitationVideoPath', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByIsReference() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReference', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByIsReferenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isReference', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByOverall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'overall', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByOverallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'overall', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByPatientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientId', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByPatientIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientId', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByQualityJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qualityJson', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByQualityJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'qualityJson', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      thenByReferenceVideoPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'referenceVideoPath', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      thenByReferenceVideoPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'referenceVideoPath', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByRom() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rom', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByRomDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rom', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      thenByScoreSchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scoreSchemaVersion', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy>
      thenByScoreSchemaVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scoreSchemaVersion', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenBySessionUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionUuid', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenBySessionUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionUuid', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenBySmoothness() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'smoothness', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenBySmoothnessDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'smoothness', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenBySymmetry() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'symmetry', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenBySymmetryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'symmetry', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByTimestampKst() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampKst', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByTimestampKstDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestampKst', Sort.desc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByTiming() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timing', Sort.asc);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QAfterSortBy> thenByTimingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timing', Sort.desc);
    });
  }
}

extension SessionLogQueryWhereDistinct
    on QueryBuilder<SessionLog, SessionLog, QDistinct> {
  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByAppVersion(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'appVersion', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByAttemptIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptIndex');
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByCompensation() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'compensation');
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByDateKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dateKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByExerciseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'exerciseId');
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByFeaturesJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'featuresJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByImitationVideoPath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imitationVideoPath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByIsReference() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isReference');
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByOverall() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'overall');
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByPatientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'patientId');
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByQualityJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'qualityJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByReferenceVideoPath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'referenceVideoPath',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByRom() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rom');
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct>
      distinctByScoreSchemaVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scoreSchemaVersion');
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctBySessionUuid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionUuid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctBySmoothness() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'smoothness');
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctBySymmetry() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'symmetry');
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByTimestampKst() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestampKst');
    });
  }

  QueryBuilder<SessionLog, SessionLog, QDistinct> distinctByTiming() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timing');
    });
  }
}

extension SessionLogQueryProperty
    on QueryBuilder<SessionLog, SessionLog, QQueryProperty> {
  QueryBuilder<SessionLog, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SessionLog, String, QQueryOperations> appVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'appVersion');
    });
  }

  QueryBuilder<SessionLog, int, QQueryOperations> attemptIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptIndex');
    });
  }

  QueryBuilder<SessionLog, int, QQueryOperations> compensationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'compensation');
    });
  }

  QueryBuilder<SessionLog, String, QQueryOperations> dateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dateKey');
    });
  }

  QueryBuilder<SessionLog, int, QQueryOperations> exerciseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'exerciseId');
    });
  }

  QueryBuilder<SessionLog, String?, QQueryOperations> featuresJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'featuresJson');
    });
  }

  QueryBuilder<SessionLog, String?, QQueryOperations>
      imitationVideoPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imitationVideoPath');
    });
  }

  QueryBuilder<SessionLog, bool, QQueryOperations> isReferenceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isReference');
    });
  }

  QueryBuilder<SessionLog, int, QQueryOperations> overallProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'overall');
    });
  }

  QueryBuilder<SessionLog, int, QQueryOperations> patientIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'patientId');
    });
  }

  QueryBuilder<SessionLog, String?, QQueryOperations> qualityJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'qualityJson');
    });
  }

  QueryBuilder<SessionLog, String?, QQueryOperations>
      referenceVideoPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'referenceVideoPath');
    });
  }

  QueryBuilder<SessionLog, int, QQueryOperations> romProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rom');
    });
  }

  QueryBuilder<SessionLog, int, QQueryOperations> scoreSchemaVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scoreSchemaVersion');
    });
  }

  QueryBuilder<SessionLog, String, QQueryOperations> sessionUuidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionUuid');
    });
  }

  QueryBuilder<SessionLog, int, QQueryOperations> smoothnessProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'smoothness');
    });
  }

  QueryBuilder<SessionLog, int, QQueryOperations> symmetryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'symmetry');
    });
  }

  QueryBuilder<SessionLog, DateTime, QQueryOperations> timestampKstProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestampKst');
    });
  }

  QueryBuilder<SessionLog, int, QQueryOperations> timingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timing');
    });
  }
}
