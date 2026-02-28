// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evaluation.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetEvaluationCollection on Isar {
  IsarCollection<Evaluation> get evaluations => this.collection();
}

const EvaluationSchema = CollectionSchema(
  name: r'Evaluation',
  id: 6409158845927912730,
  properties: {
    r'comeToSit': PropertySchema(
      id: 0,
      name: r'comeToSit',
      type: IsarType.long,
    ),
    r'date': PropertySchema(
      id: 1,
      name: r'date',
      type: IsarType.dateTime,
    ),
    r'gait': PropertySchema(
      id: 2,
      name: r'gait',
      type: IsarType.long,
    ),
    r'patientId': PropertySchema(
      id: 3,
      name: r'patientId',
      type: IsarType.long,
    ),
    r'patientName': PropertySchema(
      id: 4,
      name: r'patientName',
      type: IsarType.string,
    ),
    r'rolling': PropertySchema(
      id: 5,
      name: r'rolling',
      type: IsarType.long,
    ),
    r'sitToStand': PropertySchema(
      id: 6,
      name: r'sitToStand',
      type: IsarType.long,
    ),
    r'stair': PropertySchema(
      id: 7,
      name: r'stair',
      type: IsarType.long,
    ),
    r'totalScore': PropertySchema(
      id: 8,
      name: r'totalScore',
      type: IsarType.long,
    ),
    r'transfer': PropertySchema(
      id: 9,
      name: r'transfer',
      type: IsarType.long,
    )
  },
  estimateSize: _evaluationEstimateSize,
  serialize: _evaluationSerialize,
  deserialize: _evaluationDeserialize,
  deserializeProp: _evaluationDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _evaluationGetId,
  getLinks: _evaluationGetLinks,
  attach: _evaluationAttach,
  version: '3.1.0+1',
);

int _evaluationEstimateSize(
  Evaluation object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.patientName.length * 3;
  return bytesCount;
}

void _evaluationSerialize(
  Evaluation object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.comeToSit);
  writer.writeDateTime(offsets[1], object.date);
  writer.writeLong(offsets[2], object.gait);
  writer.writeLong(offsets[3], object.patientId);
  writer.writeString(offsets[4], object.patientName);
  writer.writeLong(offsets[5], object.rolling);
  writer.writeLong(offsets[6], object.sitToStand);
  writer.writeLong(offsets[7], object.stair);
  writer.writeLong(offsets[8], object.totalScore);
  writer.writeLong(offsets[9], object.transfer);
}

Evaluation _evaluationDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Evaluation();
  object.comeToSit = reader.readLong(offsets[0]);
  object.date = reader.readDateTime(offsets[1]);
  object.gait = reader.readLong(offsets[2]);
  object.id = id;
  object.patientId = reader.readLong(offsets[3]);
  object.patientName = reader.readString(offsets[4]);
  object.rolling = reader.readLong(offsets[5]);
  object.sitToStand = reader.readLong(offsets[6]);
  object.stair = reader.readLong(offsets[7]);
  object.transfer = reader.readLong(offsets[9]);
  return object;
}

P _evaluationDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _evaluationGetId(Evaluation object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _evaluationGetLinks(Evaluation object) {
  return [];
}

void _evaluationAttach(IsarCollection<dynamic> col, Id id, Evaluation object) {
  object.id = id;
}

extension EvaluationQueryWhereSort
    on QueryBuilder<Evaluation, Evaluation, QWhere> {
  QueryBuilder<Evaluation, Evaluation, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension EvaluationQueryWhere
    on QueryBuilder<Evaluation, Evaluation, QWhereClause> {
  QueryBuilder<Evaluation, Evaluation, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Evaluation, Evaluation, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterWhereClause> idBetween(
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
}

extension EvaluationQueryFilter
    on QueryBuilder<Evaluation, Evaluation, QFilterCondition> {
  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> comeToSitEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'comeToSit',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      comeToSitGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'comeToSit',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> comeToSitLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'comeToSit',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> comeToSitBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'comeToSit',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> dateEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> dateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> dateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> dateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'date',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> gaitEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'gait',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> gaitGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'gait',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> gaitLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'gait',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> gaitBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'gait',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> patientIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'patientId',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
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

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> patientIdLessThan(
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

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> patientIdBetween(
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

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      patientNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      patientNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      patientNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      patientNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'patientName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      patientNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      patientNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      patientNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'patientName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      patientNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'patientName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      patientNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'patientName',
        value: '',
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      patientNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'patientName',
        value: '',
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> rollingEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rolling',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      rollingGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rolling',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> rollingLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rolling',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> rollingBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rolling',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> sitToStandEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sitToStand',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      sitToStandGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sitToStand',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      sitToStandLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sitToStand',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> sitToStandBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sitToStand',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> stairEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'stair',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> stairGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'stair',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> stairLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'stair',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> stairBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'stair',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> totalScoreEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalScore',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      totalScoreGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalScore',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      totalScoreLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalScore',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> totalScoreBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalScore',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> transferEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'transfer',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition>
      transferGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'transfer',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> transferLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'transfer',
        value: value,
      ));
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterFilterCondition> transferBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'transfer',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension EvaluationQueryObject
    on QueryBuilder<Evaluation, Evaluation, QFilterCondition> {}

extension EvaluationQueryLinks
    on QueryBuilder<Evaluation, Evaluation, QFilterCondition> {}

extension EvaluationQuerySortBy
    on QueryBuilder<Evaluation, Evaluation, QSortBy> {
  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByComeToSit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'comeToSit', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByComeToSitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'comeToSit', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByGait() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gait', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByGaitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gait', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByPatientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientId', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByPatientIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientId', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByPatientName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientName', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByPatientNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientName', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByRolling() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rolling', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByRollingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rolling', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortBySitToStand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sitToStand', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortBySitToStandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sitToStand', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByStair() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stair', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByStairDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stair', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByTotalScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalScore', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByTotalScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalScore', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByTransfer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transfer', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> sortByTransferDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transfer', Sort.desc);
    });
  }
}

extension EvaluationQuerySortThenBy
    on QueryBuilder<Evaluation, Evaluation, QSortThenBy> {
  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByComeToSit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'comeToSit', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByComeToSitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'comeToSit', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByGait() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gait', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByGaitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'gait', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByPatientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientId', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByPatientIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientId', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByPatientName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientName', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByPatientNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'patientName', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByRolling() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rolling', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByRollingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rolling', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenBySitToStand() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sitToStand', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenBySitToStandDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sitToStand', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByStair() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stair', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByStairDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'stair', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByTotalScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalScore', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByTotalScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalScore', Sort.desc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByTransfer() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transfer', Sort.asc);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QAfterSortBy> thenByTransferDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transfer', Sort.desc);
    });
  }
}

extension EvaluationQueryWhereDistinct
    on QueryBuilder<Evaluation, Evaluation, QDistinct> {
  QueryBuilder<Evaluation, Evaluation, QDistinct> distinctByComeToSit() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'comeToSit');
    });
  }

  QueryBuilder<Evaluation, Evaluation, QDistinct> distinctByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date');
    });
  }

  QueryBuilder<Evaluation, Evaluation, QDistinct> distinctByGait() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'gait');
    });
  }

  QueryBuilder<Evaluation, Evaluation, QDistinct> distinctByPatientId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'patientId');
    });
  }

  QueryBuilder<Evaluation, Evaluation, QDistinct> distinctByPatientName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'patientName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Evaluation, Evaluation, QDistinct> distinctByRolling() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rolling');
    });
  }

  QueryBuilder<Evaluation, Evaluation, QDistinct> distinctBySitToStand() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sitToStand');
    });
  }

  QueryBuilder<Evaluation, Evaluation, QDistinct> distinctByStair() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'stair');
    });
  }

  QueryBuilder<Evaluation, Evaluation, QDistinct> distinctByTotalScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalScore');
    });
  }

  QueryBuilder<Evaluation, Evaluation, QDistinct> distinctByTransfer() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'transfer');
    });
  }
}

extension EvaluationQueryProperty
    on QueryBuilder<Evaluation, Evaluation, QQueryProperty> {
  QueryBuilder<Evaluation, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Evaluation, int, QQueryOperations> comeToSitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'comeToSit');
    });
  }

  QueryBuilder<Evaluation, DateTime, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<Evaluation, int, QQueryOperations> gaitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'gait');
    });
  }

  QueryBuilder<Evaluation, int, QQueryOperations> patientIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'patientId');
    });
  }

  QueryBuilder<Evaluation, String, QQueryOperations> patientNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'patientName');
    });
  }

  QueryBuilder<Evaluation, int, QQueryOperations> rollingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rolling');
    });
  }

  QueryBuilder<Evaluation, int, QQueryOperations> sitToStandProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sitToStand');
    });
  }

  QueryBuilder<Evaluation, int, QQueryOperations> stairProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'stair');
    });
  }

  QueryBuilder<Evaluation, int, QQueryOperations> totalScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalScore');
    });
  }

  QueryBuilder<Evaluation, int, QQueryOperations> transferProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'transfer');
    });
  }
}
