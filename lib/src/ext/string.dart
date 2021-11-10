import 'dart:core';


extension StringExt on String {

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  static const int eotCode = 4;
  static final String eot = String.fromCharCode(StringExt.eotCode);
  static const String newLine = '\n';

  static const String stdinDisplay = '<stdin>';
  static const String stdinPath = '-';

  static const String stdoutDisplay = '<stdout>';
  static const String stdoutPath = StringExt.stdinPath;

  static const String unknown = '<unknown>';

  static final RegExp rexBlank = RegExp(r'^[\s]*$');
  static final RegExp rexCmdLine = RegExp(r"""(([^\"\'\s]+)|([\"]([^\"]*)[\"])+|([\']([^\']*)[\']))+""", caseSensitive: false);
  static final RegExp rexInteger = RegExp(r'^\d+$', caseSensitive: false);
  static final RegExp rexProtocol = RegExp(r'^[A-Z]+[\:][\/][\/]+', caseSensitive: false);

  //////////////////////////////////////////////////////////////////////////////

  bool isBlank() =>
    trim().isEmpty; // faster than regex

  //////////////////////////////////////////////////////////////////////////////

  bool parseBool() =>
    (toLowerCase() == 'true');

  //////////////////////////////////////////////////////////////////////////////

  String quote() {
    if (!contains(' ') && !contains('\t')) {
      return this;
    }

    var q = (contains('"') ? "'" : '"');

    return q + this + q;

    // var result = this;

    // if (Env.escape.isNotEmpty && contains(q)) {
    //   result = replaceAll(Env.escape, Env.escapeEscape);
    //   result = result.replaceAll(q, Env.escape + q);
    // }

    // return q + result + q;
  }

  //////////////////////////////////////////////////////////////////////////////

  String unquote() {
    var len = length;

    if (len <= 1) {
      return this;
    }

    var q = this[0];
    var hasQ = (((q == "'") || (q == '"')) && (q == this[len - 1]));

    return (hasQ ? substring(1, (len - 1)) : this);

    // var result = (hasQ ? substring(1, (len - 1)) : this);

    // if (result.contains(Env.escape)) {
    //   result = result.replaceAll(Env.escape + "'", "'");
    //   result = result.replaceAll(Env.escape + '"', '"');
    //   result = result.replaceAll(Env.escapeEscape, Env.escape);
    // }

    // return result;
  }

  //////////////////////////////////////////////////////////////////////////////
}