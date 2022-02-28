import 'package:meta/meta.dart';
import 'package:xnx/src/ext/path.dart';
import 'package:xnx/src/keywords.dart';
import 'package:xnx/src/regexp_ex.dart';

class FlatMap {

  /////////////////////////////////////////////////////////////////////////////
  // Internals
  /////////////////////////////////////////////////////////////////////////////

  @protected final Keywords? keywords;
  @protected final Map<String, String> map = {};

  /////////////////////////////////////////////////////////////////////////////
  // Interface
  /////////////////////////////////////////////////////////////////////////////

  Map<String, String> get data => map;
  Iterable<MapEntry<String, String>> get entries => map.entries;
  bool get isEmpty => map.isEmpty;
  bool get isNotEmpty => map.isNotEmpty;

  void add(FlatMap other) => map.addAll(other.map);
  void addAll(Map<String, String> other) => map.addAll(other);
  bool containsKey(String key) => map.containsKey(key);
  void forEach(void Function(String key, String value) action) => map.forEach(action);
  void remove(String key) => map.remove(key);
  void removeWhere(bool Function(String key, String value) test) => map.removeWhere(test);

  /////////////////////////////////////////////////////////////////////////////

  FlatMap({this.keywords});

  /////////////////////////////////////////////////////////////////////////////
  // Getter
  /////////////////////////////////////////////////////////////////////////////

  String? operator [](String? key) => map[key];

  /////////////////////////////////////////////////////////////////////////////
  // Setter
  /////////////////////////////////////////////////////////////////////////////

  void operator []=(String? key, String? value) {
    if (key == null) {
      return;
    }

    if (value == null) {
      map.remove(key);
    }
    else {
      map[key] = value;
    }
  }

  /////////////////////////////////////////////////////////////////////////////

  String expand(String? value) {
    if (value == null) {
      return '';
    }

    if (value.isEmpty || map.isEmpty) {
      return value;
    }

    var safeValue = value;
    var forCurDir = keywords?.forCurDir ?? '';

    if (forCurDir.isNotEmpty) {
      safeValue = safeValue.replaceAll(forCurDir, Path.currentDirectory.path);
    }

    for (var oldValue = ''; oldValue != safeValue;) {
      oldValue = safeValue;

      map.forEach((k, v) {
        var rx = RegExpEx.fromDecoratedPattern(k);

        if (rx == null) {
          if (safeValue.contains(k)) {
            safeValue = safeValue.replaceAll(k, v.toString());
          }
        }
        else {
          var r = rx.regExp;

          if (r != null) {
            if (rx.isGlobal) {
              safeValue = safeValue.replaceAll(r, v.toString());
            }
            else {
              safeValue = safeValue.replaceFirst(r, v.toString());
            }
          }
        }
      });
    }

    return safeValue;
  }

  /////////////////////////////////////////////////////////////////////////////

}