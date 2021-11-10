import 'package:meta/meta.dart';
import 'package:collection/collection.dart';
import 'package:xnx/src/ext/string.dart';
import 'package:xnx/src/flat_map.dart';
import 'package:xnx/src/keywords.dart';
import 'package:xnx/src/operation.dart';

class Expression {
  static final RegExp rexEndsWithTrue = RegExp(r'(^|[\s\(\|])(true|[1-9][0-9]*)[\s\)[\|]*$',);
  static final RegExp rexEndsWithFalse = RegExp(r'(^|[\s\(\&])(false|[0]+)[\s\)[\&]*$');

  @protected final FlatMap flatMap;
  @protected final Keywords keywords;
  @protected final Operation operation;

  Expression({required this.flatMap, required this.keywords, required this.operation});

  Object? exec(Map<String, Object?> mapIf) {
    var condition = mapIf.entries.firstWhereOrNull((x) =>
      (x.key != keywords.forThen) &&
      (x.key != keywords.forElse)
    )?.value;

    var blockElse = mapIf[keywords.forElse];

    if (condition == null) {
      return blockElse;
    }

    var blockThen = mapIf[keywords.forThen];

    if (blockThen == null) {
      throw Exception('Then-block not found in "$mapIf"');
    }

    var isThen = _exec(condition as String);

    return (isThen ? blockThen : blockElse);
  }

  bool _exec(String condition) {
    if (condition.isBlank()) {
      return false;
    }

    for (; ;) {
      var chunk = _getFirstChunk(condition);
      var start = chunk[0];
      var end = chunk[1];

      if (start < 0) {
        break;
      }

      var before = condition.substring(0, start);

      if (rexEndsWithFalse.hasMatch(before)) {
        return false;
      }

      if (rexEndsWithTrue.hasMatch(before)) {
        return true;
      }

      var result = _exec(condition.substring(start + 1, end - 1));
      condition = condition.replaceRange(start, end, (result ? '1' : '0'));
    }

    return _execBracketFree(condition.trim());
  }

  bool _execBracketFree(String condition) {
    var orParts = condition.split('||');

    for (var orPart in orParts) {
      var andParts = orPart.split('&&');
      var isThen = true;

      for (var andPart in andParts) {
        if (!operation.exec(andPart.trim())) {
          isThen = false;
          break;
        }
      }

      if (isThen) {
        return true;
      }
    }

    return false;
  }

  List<int> _getFirstChunk(String condition) {
    var beg = -1;
    var len = condition.length;
    var bracketCount = 0;

    for (var cur = 0; cur < len; cur++) {
      switch (condition[cur]) {
        case '(':
          ++bracketCount;
          if (beg < 0) {
            beg = cur;
          }
          break;
        case ')':
          --bracketCount;
          if (bracketCount == 0) {
            return [beg, cur + 1];
          }
          break;
      }
    }

    if (bracketCount > 0) {
      throw Exception('Too many opening parentheses in $condition');
    }

    if (bracketCount < 0) {
      throw Exception('Too many closing parentheses in $condition');
    }

    return [-1, -1];
  }
}