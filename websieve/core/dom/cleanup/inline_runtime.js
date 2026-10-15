  var INLINE_JS_SYNTAX_PATTERNS = [
    /\b(document\.(body|getElementById|querySelector|createElement|cookie|write)|window\.(location|addEventListener|dataLayer|gtag|ga\())/,
    /\b(var\s+\w+\s*=\s*|\.push\s*\(\s*function|\.classList\.(add|remove|toggle)|\.style\.\w+\s*=|\.innerHTML\s*=)/,
    /\b(\.setAttribute\s*\(|addEventListener\s*\(|\.insertBefore\s*\(|\.appendChild\s*\(|\.parentNode\s*\.)/,
    /\b(new\s+(Date|Array|Object|RegExp|Map|Set)\s*\(|typeof\s+\w+\s*[!=]==?\s*|===?\s*['"]undefined['"])/,
    /\b(console\.(log|warn|error)|setTimeout\s*\(|setInterval\s*\(|JSON\.(parse|stringify)|Promise\.(resolve|reject|all))/,
    /\b(Object\.(keys|values|assign|defineProperty)|Array\.(isArray|from|prototype)|if\s*\([^)]*\)\s*\{|try\s*\{|catch\s*\(\w+\)\s*\{|throw\s+new\s+\w+)/,
    // A parenthetical explanation of a function is not an anonymous function.
    /\bfunction\s*\(.*\)\s*\{/,
    // Prose can say "return true if ...". Require an expression/statement
    // boundary, rather than interpreting that phrase as a return statement.
    /\breturn\s+(?:(?:true|false|null|this)\b(?=\s*(?:[;})\].,?&|!=+*\/%<>:\[(-]|$))|void\b)/
  ];

  function looksLikeInlineJS(text) {
    var normalized = normalizeText(text || "");
    if (!normalized || normalized.length > 1200 || normalized.length < 12) return false;
    if (!textMatchesAnyPattern(normalized, INLINE_JS_SYNTAX_PATTERNS)) return false;
    var jsTokens = normalized.match(/[{};()=]|function\s|var\s|const\s|let\s|return\s|\.push\(|\.call\(|\.apply\(|=>|===?|!==?|&&|\|\|/g) || [];
    return jsTokens.length >= 3;
  }
