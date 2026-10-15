  function preserveLiteralInlineCode(root) {
    root.querySelectorAll("code a:not([href])").forEach(function(anchor) {
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
