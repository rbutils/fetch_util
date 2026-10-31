  function emptyMarkdownNamedTargetHidden(node, root) {
    var visibility = "";
    for (var owner = node; owner && owner.nodeType === Node.ELEMENT_NODE; owner = owner.parentElement) {
      if (owner.hasAttribute("hidden") || owner.hasAttribute("inert")) return true;
      var style = owner.style;
      if (style) {
        if (style.display === "none" || style.contentVisibility === "hidden" ||
            (style.opacity !== "" && Number(style.opacity) === 0)) return true;
        if (!visibility && /^(?:visible|hidden|collapse)$/.test(style.visibility)) visibility = style.visibility;
      }
      if (owner === root) break;
    }
    return visibility === "hidden" || visibility === "collapse";
  }

  function emptyMarkdownNamedTarget(node, root) {
    if (node.namespaceURI !== "http://www.w3.org/1999/xhtml" || node.childNodes.length) return false;
    if (node.nodeName !== "SPAN" && node.nodeName !== "A") return false;
    if (node.nodeName === "A" && node.hasAttribute("href")) return false;
    if (!node.getAttribute("id") && !(node.nodeName === "A" && node.getAttribute("name"))) return false;
    if (node.closest("pre, code, kbd, samp, table, script, style, noscript, template, svg, math, nav, form, button, select, textarea, [role='button' i], [role='tab' i], [role='navigation' i]")) return false;
    return !emptyMarkdownNamedTargetHidden(node, root);
  }

  function emptyMarkdownNamedTargetHtml(node) {
    var tag = node.nodeName.toLowerCase();
    var attributes = Array.from(node.attributes).filter(function(attribute) {
      return attribute.name === "id" || (tag === "a" && attribute.name === "name");
    }).map(function(attribute) {
      // Encode syntax and whitespace, retaining the exact parsed identity without
      // exposing attribute values to later prose or Markdown cleanup patterns.
      var value = attribute.value.replace(/[^A-Za-z0-9_-]/gu, function(character) {
        return "&#" + character.codePointAt(0) + ";";
      });
      return " " + attribute.name + "=\"" + value + "\"";
    }).join("");
    return "<" + tag + attributes + "></" + tag + ">";
  }

  function prepareEmptyMarkdownNamedTargets(root) {
    var candidates = Array.from(root.querySelectorAll("span[id], a[id], a[name]")).filter(function(node) {
      return emptyMarkdownNamedTarget(node, root);
    });
    if (!candidates.length) return null;
    var prefix = "FETCHUTILNAMEDTARGET";
    var html = root.innerHTML;
    var text = root.textContent;
    while (html.indexOf(prefix) !== -1 || text.indexOf(prefix) !== -1) prefix += "OWNED";
    var targets = candidates.map(function(node, index) {
      var declaration = emptyMarkdownNamedTargetHtml(node);
      node.replaceWith(root.ownerDocument.createTextNode(prefix + index + "END"));
      return declaration;
    });
    return { prefix: prefix, targets: targets };
  }

  function restoreEmptyMarkdownNamedTargets(markdown, prepared) {
    if (!prepared) return markdown;
    return markdown.replace(new RegExp(prepared.prefix + "([0-9]+)END", "g"), function(_match, key) {
      if (!Object.prototype.hasOwnProperty.call(prepared.targets, key)) throw new Error("Missing named target declaration");
      return prepared.targets[key];
    });
  }
