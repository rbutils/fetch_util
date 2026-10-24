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
      programs.push({ text: text, language: language, html: linkedCodeProgramHtml(pre) });
      // Turndown evaluates children before the PRE replacement. The replacement
      // owns the complete literal program, so its discarded child conversion
      // needs only a nonblank token rather than another pass over every byte.
      pre.textContent = "x";
    });
    return { attribute: attribute, programs: programs };
  }

  function blockOwnedMultilineCode(code) {
    if (code.namespaceURI !== "http://www.w3.org/1999/xhtml" ||
        code.closest("pre, table, button, textarea, select, nav, [role='button' i], [role='tab' i], [hidden], [aria-hidden='true'], [inert]") ||
        code.matches("[id], [name]") ||
        code.querySelector("a[href], img, br, pre, svg, math, button, input, textarea, select, [id], [name]")) return false;
    var parent = code.parentElement;
    if (!parent || !/^(?:P|DIV|LI|DD|DT|BLOCKQUOTE|ARTICLE|SECTION|MAIN)$/.test(parent.nodeName)) return false;
    for (var following = code.nextSibling; following; following = following.nextSibling) {
      if (following.nodeType !== Node.TEXT_NODE || /\S/.test(following.textContent)) return false;
    }
    var previous = code.previousSibling;
    while (previous && previous.nodeType === Node.TEXT_NODE && !/\S/.test(previous.textContent)) {
      previous = previous.previousSibling;
    }
    return !previous || (parent.nodeName === "P" && previous.nodeType === Node.ELEMENT_NODE && previous.nodeName === "BR");
  }

  function prepareBlockOwnedLiteralPrograms(root) {
    var attribute = "data-fetch-util-block-code-program";
    while (root.querySelector("[" + attribute + "]")) attribute += "-owned";
    var programs = [];
    root.querySelectorAll("code").forEach(function(code) {
      var text = code.textContent;
      if (!/[\r\n]/.test(text) || !/\S/.test(text) || !blockOwnedMultilineCode(code)) return;
      code.setAttribute(attribute, String(programs.length));
      programs.push({ text: text, language: code.getAttribute("data-language") || guessCodeLanguage(code) });
      // Keep the complete program before wrapper cleanup or Turndown can turn
      // its line breaks into inline spaces. Only the disposable clone changes.
      code.textContent = "x";
    });
    return { attribute: attribute, programs: programs };
  }

  function addBlockOwnedLiteralProgramRule(service, snapshot) {
    service.addRule("blockOwnedLiteralPrograms", {
      filter: function(node) {
        return node.nodeName === "CODE" && node.hasAttribute(snapshot.attribute);
      },
      replacement: function(_content, node) {
        var program = snapshot.programs[Number(node.getAttribute(snapshot.attribute))];
        if (!program) throw new Error("Missing block-owned literal program snapshot");
        return fencedCodeBlock(program.language, program.text);
      }
    });
  }
