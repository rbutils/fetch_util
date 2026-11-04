  function preserveLiteralInlineCode(root) {
    root.querySelectorAll("a:not([href])").forEach(function(anchor) {
      if (anchor.closest("pre") && anchor.matches("[id], [name]")) return;
      if (!anchor.closest("code") && !literalNamedCodeContainer(anchor)) return;
      anchor.replaceWith.apply(anchor, Array.prototype.slice.call(anchor.childNodes));
    });
    root.querySelectorAll("code").forEach(function(code) {
      if (code.closest("pre") || code.matches("[id], [name]") ||
          code.querySelector("a[href], img, br, pre, [id], [name]")) return;
      if (code.querySelector("code") || literalInlinePresentation(code)) {
        code.replaceChildren(document.createTextNode(code.textContent));
      }
      var previous = code.previousSibling;
      if (!previous || previous.nodeType !== 1 || previous.localName !== "code" ||
          previous.namespaceURI !== code.namespaceURI || previous.closest("pre") || previous.matches("[id], [name]") ||
          previous.querySelector("a[href], img, br, pre, [id], [name]")) return;
      var attributes = Array.prototype.filter.call(code.attributes, function(attribute) {
        return !/^(?:class|style)$/.test(attribute.name);
      });
      var previousAttributes = Array.prototype.filter.call(previous.attributes, function(attribute) {
        return !/^(?:class|style)$/.test(attribute.name);
      });
      if (previousAttributes.length !== attributes.length ||
          attributes.some(function(attribute) {
            return previous.getAttribute(attribute.name) !== attribute.value;
          })) return;
      previous.append.apply(previous, Array.prototype.slice.call(code.childNodes));
      code.remove();
    });
  }

  function literalNamedCodeContainer(anchor) {
    return anchor.matches("[name], [id]") && anchor.querySelector("code") &&
      !anchor.matches("[rel~='tag' i]") && !tagSpacingEvidence(anchor) &&
      !(anchor.parentElement && tagSpacingEvidence(anchor.parentElement));
  }

  function preserveWholeInlineCodeLinks(root) {
    root.querySelectorAll("code").forEach(function(code) {
      if (code.closest("pre, button, form, [role='button' i], [role='tab' i], [hidden], [aria-hidden='true'], [inert]") ||
          code.querySelector("code, img, br, pre, svg, math, button, input, textarea, select")) return;
      var links = code.querySelectorAll("a[href]");
      if (links.length !== 1) return;
      var link = links[0];
      var text = code.textContent;
      if (!text || /[\r\n]/.test(text) || text !== link.textContent ||
          !materializedHttpUrl(link.getAttribute("href"))) return;
      if (Array.prototype.some.call(code.querySelectorAll("[id], [name]"), function(target) {
        return target !== link;
      })) return;

      code.replaceChildren(document.createTextNode(text));
      code.replaceWith(link);
      link.replaceChildren(code);
    });
  }

  function prepareLinkedInlineCodeWhitespace(service) {
    var snapshots = new WeakMap();
    service.addRule("linkedInlineCodeWhitespace", {
      filter: function(node) {
        return node.nodeName === "CODE" && snapshots.has(node);
      },
      replacement: function(_content, node, options) {
        var snapshot = snapshots.get(node);
        if (!snapshot) throw new Error("Missing linked inline-code whitespace snapshot");
        return snapshot.rule.replacement.call(snapshot.rule, snapshot.text, node, options);
      }
    });
    return function(root) {
      snapshots = new WeakMap();
      root.querySelectorAll("a[href] > code").forEach(function(code) {
        var link = code.parentElement;
        if (code.namespaceURI !== "http://www.w3.org/1999/xhtml" ||
            link.namespaceURI !== code.namespaceURI || link.childNodes.length !== 1 ||
            code.childNodes.length !== 1 || code.firstChild.nodeType !== Node.TEXT_NODE ||
            code.matches("[id], [name]") ||
            code.closest("pre, table, button, form, nav, textarea, select, [role='button' i], [role='tab' i], [hidden], [aria-hidden='true'], [inert], [contenteditable], [tabindex]") ||
            !materializedHttpUrl(link.getAttribute("href"))) return;
        var text = code.textContent;
        if (!/\S/.test(text) || /[\r\n]/.test(text) || !/^[ \t]|[ \t]$/.test(text)) return;
        var rule = service.rules.forNode(code);
        snapshots.set(code, { text: text, rule: rule });
        // The whole literal is owned by CODE. Its disposable child conversion
        // must not expose those same spaces as the parent link's whitespace.
        code.textContent = "x";
      });
    };
  }

  function literalInlinePresentation(code) {
    var descendants = code.querySelectorAll("*");
    return descendants.length > 0 && Array.prototype.every.call(descendants, function(node) {
      return node.namespaceURI === "http://www.w3.org/1999/xhtml" && /^(?:CODE|SPAN)$/.test(node.nodeName) &&
        Array.prototype.every.call(node.attributes, function(attribute) {
          return /^(?:class|style)$/.test(attribute.name);
        });
    });
  }

  function preserveLiteralAngleText(service) {
    var escape = service.escape;
    service.escape = function(text) {
      return escape.call(service, text).replace(/</g, function(character, index, escaped) {
        return markdownEscapedAt(escaped, index) ? character : "\\" + character;
      });
    };
  }

  function markdownEscapedAt(text, index) {
    var backslashes = 0;
    for (var i = index - 1; i >= 0 && text[i] === "\\"; i--) backslashes++;
    return backslashes % 2 === 1;
  }
