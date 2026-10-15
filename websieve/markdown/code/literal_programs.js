  function prepareLiteralCodePrograms(root) {
    var attribute = "data-fetch-util-literal-program";
    while (root.querySelector("[" + attribute + "]")) attribute += "-owned";
    var programs = [];
    root.querySelectorAll("pre").forEach(function(pre) {
      // Tables serialize their source cells directly, without this PRE rule.
      // Keep that input intact instead of exposing the discarded-child token.
      if (pre.closest("table")) return;
      var code = pre.querySelector("code");
      var text = cleanCodeText(code ? code.textContent : pre.textContent);
      if (!text) return;
      var language = (code && code.getAttribute("data-language")) || guessCodeLanguage(code || pre);
      pre.setAttribute(attribute, String(programs.length));
      programs.push({ text: text, language: language });
      // Turndown evaluates children before the PRE replacement. The replacement
      // owns the complete literal program, so its discarded child conversion
      // needs only a nonblank token rather than another pass over every byte.
      pre.textContent = "x";
    });
    return { attribute: attribute, programs: programs };
  }
