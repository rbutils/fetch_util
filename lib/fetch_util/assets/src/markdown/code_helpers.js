  function escapeRegex(text) {
    return String(text || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  function cleanCodeText(text) {
    return String(text || "")
      .replace(/^Copy(?: to clipboard)?\s*/i, "")
      .replace(/\u00b6/g, "")
      .replace(/\r\n?/g, "\n")
      .replace(/^\n+|\n+$/g, "");
  }

  function fencedCodeBlock(language, text) {
    return "\n\n```" + language + "\n" + text + "\n```\n\n";
  }

  function guessCodeLanguage(node) {
    var signature = normalizeText([
      node && node.className,
      node && node.getAttribute && node.getAttribute("data-language"),
      node && node.getAttribute && node.getAttribute("data-testid"),
      node && node.parentElement && node.parentElement.className
    ].join(" ")).toLowerCase();

    if (/python|pycon/.test(signature)) return "python";
    if (/javascript|js\b/.test(signature)) return "javascript";
    if (/typescript|tsx|ts\b/.test(signature)) return "typescript";
    if (/json/.test(signature)) return "json";
    if (/yaml|yml/.test(signature)) return "yaml";
    if (/bash|shell|sh\b|curl/.test(signature)) return "bash";
    return "";
  }

  // Reconstruct JSON text from ReDoc's interactive DOM tree.
  // ReDoc renders JSON samples as nested <ul class="obj/array collapsible"><li>
  // with <span class="property token string">"key"</span> and value spans.
  // innerText on these produces garbled output; we walk the tree to rebuild valid JSON.
  function reconstructRedocJson(node) {
    var parts = [];
    function walk(el) {
      var children = el.childNodes;
      for (var i = 0; i < children.length; i++) {
        var child = children[i];
        if (child.nodeType === 3) { // text node
          var t = child.textContent;
          if (t && !/^\s*$/.test(t)) parts.push(t);
        } else if (child.nodeType === 1) { // element
          var tag = child.nodeName;
          var cls = child.className || "";
          // Skip collapsers, ellipsis placeholders, and buttons
          if (tag === "BUTTON") continue;
          if (/\bellipsis\b/.test(cls)) continue;
          // Span tokens: emit their text
          if (tag === "SPAN") {
            var st = child.textContent;
            if (st && !/^\s*$/.test(st)) parts.push(st);
            continue;
          }
          // Recurse into ul, li, div, code
          walk(child);
        }
      }
    }
    walk(node);
    // Join and try to parse/reformat as JSON
    var raw = parts.join("").replace(/,(\s*[}\]])/g, "$1");
    try {
      var parsed = JSON.parse(raw);
      return JSON.stringify(parsed, null, 2);
    } catch (e) {
      // Fallback: clean up whitespace and return as-is
      return raw.replace(/\s+/g, " ").trim();
    }
  }

  // Convert ReDoc JSON DOM trees into <pre><code> blocks in-place.
  // Must be called BEFORE removing response tab containers, and BEFORE Turndown.
  function normalizeRedocJsonBlocks(root) {
    root.querySelectorAll("div.redoc-json, div[class*='redoc-json']").forEach(function(el) {
      var text = reconstructRedocJson(el);
      if (!text) return;
      var replacement = document.createElement("pre");
      var code = document.createElement("code");
      code.setAttribute("data-language", "json");
      code.textContent = text;
      replacement.appendChild(code);
      el.replaceWith(replacement);
    });
  }

  function normalizeCodeBlocks(root) {
    removeNodesByText(root, "button, a, span, div", /^(copy|copy to clipboard)$/i);
    root.querySelectorAll("button.copybutton, [aria-label*='copy' i], [title*='copy to clipboard' i]").forEach(function(el) {
      el.remove();
    });

    // Strip <font> tags everywhere (e.g., FastAPI/MkDocs terminal output coloring)
    // Also strip styled spans inside code/pre blocks that carry syntax highlighting
    root.querySelectorAll("font").forEach(function(el) {
      el.replaceWith(document.createTextNode(el.textContent));
    });
    root.querySelectorAll("pre span[style], code span[style]").forEach(function(el) {
      el.replaceWith(document.createTextNode(el.textContent));
    });

    root.querySelectorAll("div.highlight, div[class*='CodeBlock'], div[class*='codeBlock'], div[class*='code-sample'], div[class*='CodeSample'], div[class*='snippet'], div.redoc-json, div[class*='redoc-json']").forEach(function(el) {
      var pre = el.querySelector("pre");
      var text = cleanCodeText((pre || el).innerText || (pre || el).textContent);
      if (!text) return;

      if (!pre && !/^(curl\b|[{[]|>>>|\$\s|GET\b|POST\b|PUT\b|PATCH\b|DELETE\b|HTTP\/|<\w)/m.test(text)) return;

      var replacement = document.createElement("pre");
      var code = document.createElement("code");
      var language = guessCodeLanguage(pre || el);
      if (!language && (el.matches(".redoc-json, [class*='redoc-json']") || /^[\[{]/.test(text))) language = "json";
      code.textContent = text;
      if (language) code.setAttribute("data-language", language);
      replacement.appendChild(code);
      el.replaceWith(replacement);
    });

    root.querySelectorAll("pre").forEach(function(pre) {
      var code = pre.querySelector("code") || document.createElement("code");
      var language = code.getAttribute("data-language") || guessCodeLanguage(code) || guessCodeLanguage(pre);
      code.textContent = cleanCodeText(code.textContent || pre.textContent);
      if (language) code.setAttribute("data-language", language);
      pre.innerHTML = "";
      pre.appendChild(code);
    });
  }

  function unwrapWrapperDivs(root) {
    var BLOCK_TAGS = /^(P|H[1-6]|UL|OL|LI|TABLE|PRE|BLOCKQUOTE|HR|DL|FIGURE|DETAILS|SUMMARY|ARTICLE|SECTION|HEADER|FOOTER|NAV|ASIDE|MAIN|FORM|FIELDSET)$/;
    var changed = true;
    while (changed) {
      changed = false;
      root.querySelectorAll("div").forEach(function(div) {
        if (!div.parentNode) return;
        var hasBlockChild = false;
        for (var i = 0; i < div.childNodes.length; i++) {
          var child = div.childNodes[i];
          if (child.nodeType === 1 && (BLOCK_TAGS.test(child.nodeName) || child.nodeName === "DIV")) {
            hasBlockChild = true;
            break;
          }
        }
        if (hasBlockChild) {
          while (div.firstChild) div.parentNode.insertBefore(div.firstChild, div);
          div.remove();
          changed = true;
        }
      });
    }
  }

  function compactParameterCell(cell) {
    var header = cell.querySelector("div > div") || cell.firstElementChild || cell;
    var nameNode = header.querySelector("code, strong, b");
    var name = normalizeText(nameNode && nameNode.textContent);
    if (!name) return null;

    var headerText = compactReferenceText(header.textContent);
    var typeText = normalizeText(headerText.replace(new RegExp("^" + escapeRegex(name)), "")).replace(/\brequired\b/i, "");
    var required = /\brequired\b/i.test(headerText);
    var description = Array.prototype.map.call(cell.querySelectorAll("p, li"), function(node) {
      return compactReferenceText(node.textContent);
    }).filter(Boolean).join(" ");

    if (!description) {
      description = compactReferenceText(cell.textContent).replace(new RegExp("^" + escapeRegex(name) + "\\s*" + escapeRegex(typeText)), "").trim();
    }

    var line = "- `" + name + "`";
    if (typeText || required) {
      var qualifiers = [];
      if (typeText) qualifiers.push(typeText);
      if (required) qualifiers.push("required");
      line += " (" + qualifiers.join(", ") + ")";
    }
    if (description) line += ": " + description;
    return line;
  }
