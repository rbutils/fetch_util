  function codeSurfaceText(node) {
    if (node.nodeType === 3) return node.textContent;
    if (node.nodeType !== 1) return "";
    if (node.matches("br")) return "\n";
    if (node.matches("button, script, style, template, [hidden], [aria-hidden='true']")) return "";

    var children = Array.prototype.slice.call(node.childNodes);
    var blockLines = children.filter(function(child) {
      return child.nodeType === 1 && child.matches("div, p, li");
    });
    if (blockLines.length && children.every(function(child) {
      return blockLines.indexOf(child) >= 0 || child.nodeType === 3 && !child.textContent.trim();
    })) {
      return blockLines.map(codeSurfaceText).join("\n");
    }
    return children.map(codeSurfaceText).join("");
  }

  function normalizedCodeElement(text, language) {
    var code = document.createElement("code");
    code.textContent = cleanCodeText(text);
    if (language) code.setAttribute("data-language", language);
    return code;
  }

  function normalizeCodeSurfaces(root) {
    root.querySelectorAll("tt").forEach(function(node) {
      node.replaceWith(normalizedCodeElement(codeSurfaceText(node)));
    });

    // Editors render each materialized line separately. Measurements, cursors and
    // hidden source buffers are not additional examples or missing viewport lines.
    root.querySelectorAll(".CodeMirror .CodeMirror-measure, .CodeMirror .CodeMirror-gutters, .CodeMirror .CodeMirror-cursors").forEach(function(node) {
      node.remove();
    });
    root.querySelectorAll(".CodeMirror-code, .cm-editor .cm-content").forEach(function(editor) {
      var selector = editor.matches(".CodeMirror-code") ? "pre.CodeMirror-line" : ".cm-line";
      var lines = Array.prototype.filter.call(editor.querySelectorAll(selector), function(line) {
        return !line.closest("[hidden], [aria-hidden='true']");
      });
      if (!lines.length) return;

      var pre = document.createElement("pre");
      pre.appendChild(normalizedCodeElement(lines.map(codeSurfaceText).join("\n"), guessCodeLanguage(editor)));
      editor.replaceChildren(pre);
    });

    var examples = root.matches && root.matches("pre") ? [root] : Array.prototype.slice.call(root.querySelectorAll("pre"));
    examples.forEach(function(pre) {
      var code = pre.querySelector("code");
      var language = code && code.getAttribute("data-language") || guessCodeLanguage(code) || guessCodeLanguage(pre);
      pre.replaceChildren(normalizedCodeElement(codeSurfaceText(pre), language));
    });
    return root;
  }
