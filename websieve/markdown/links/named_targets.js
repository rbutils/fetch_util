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

  function markdownNamedTargetContext(node, root) {
    if (node.namespaceURI !== "http://www.w3.org/1999/xhtml") return false;
    if (node.closest("pre, code, kbd, samp, table, script, style, noscript, template, svg, math, nav, form, button, select, textarea, [role='button' i], [role='tab' i], [role='navigation' i]")) return false;
    return !emptyMarkdownNamedTargetHidden(node, root);
  }

  function emptyMarkdownNamedTarget(node, root) {
    if (node.childNodes.length) return false;
    if (node.nodeName !== "SPAN" && node.nodeName !== "A") return false;
    if (node.nodeName === "A" && node.hasAttribute("href")) return false;
    if (!node.getAttribute("id") && !(node.nodeName === "A" && node.getAttribute("name"))) return false;
    return markdownNamedTargetContext(node, root);
  }

  function prepareMarkdownNamedTargets(root) {
    var headings = Array.from(root.querySelectorAll("h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]"));
    if (root.nodeType === Node.ELEMENT_NODE && /^H[1-6]$/.test(root.nodeName) && root.hasAttribute("id")) {
      headings.unshift(root);
    }
    var records = headings.filter(function(heading) {
      return heading.getAttribute("id") && markdownNamedTargetContext(heading, root);
    }).map(function(heading) { return { node: heading, identity: heading.getAttribute("id") }; });
    var prepared = prepareEmptyMarkdownNamedTargets(root);
    if (!records.length) return prepared;
    if (!prepared) prepared = { prefix: emptyMarkdownNamedTargetPrefix(root), targets: [] };
    prepared.headings = records;
    return prepared;
  }

  function materializeMarkdownHeadingTargets(root, prepared) {
    if (!prepared || !prepared.headings) return prepared;
    var declarations = [];
    prepared.headings.forEach(function(record) {
      var heading = record.node;
      if (!root.contains(heading) || heading.getAttribute("id") !== record.identity ||
          !markdownNamedTargetContext(heading, root)) return;
      var declaration = heading.ownerDocument.createElement("span");
      declaration.setAttribute("id", record.identity);
      heading.removeAttribute("id");
      // Keep the complete heading line intact and its locator at that boundary.
      if (heading === root) heading.appendChild(declaration);
      else heading.parentNode.insertBefore(declaration, heading);
      declarations.push(declaration);
    });
    delete prepared.headings;
    return protectEmptyMarkdownNamedTargets(root, declarations, prepared);
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

  function emptyMarkdownNamedTargetPrefix(root) {
    var prefix = "FETCHUTILNAMEDTARGET";
    var html = root.innerHTML;
    var text = root.textContent;
    while (html.indexOf(prefix) !== -1 || text.indexOf(prefix) !== -1) prefix += "OWNED";
    return prefix;
  }

  function protectEmptyMarkdownNamedTargets(root, candidates, prepared) {
    if (!candidates.length) return prepared || null;
    if (!prepared) prepared = { prefix: emptyMarkdownNamedTargetPrefix(root), targets: [] };
    candidates.forEach(function(node) {
      var declaration = emptyMarkdownNamedTargetHtml(node);
      var index = prepared.targets.length;
      prepared.targets.push(declaration);
      node.replaceWith(root.ownerDocument.createTextNode(prepared.prefix + index + "END"));
    });
    return prepared;
  }

  function prepareEmptyMarkdownNamedTargets(root) {
    var candidates = Array.from(root.querySelectorAll("span[id], a[id], a[name]")).filter(function(node) {
      return emptyMarkdownNamedTarget(node, root);
    });
    return protectEmptyMarkdownNamedTargets(root, candidates, null);
  }

  function restoreEmptyMarkdownNamedTargets(markdown, prepared) {
    if (!prepared) return markdown;
    return markdown.replace(new RegExp(prepared.prefix + "([0-9]+)END", "g"), function(_match, key) {
      if (!Object.prototype.hasOwnProperty.call(prepared.targets, key)) throw new Error("Missing named target declaration");
      return prepared.targets[key];
    });
  }
