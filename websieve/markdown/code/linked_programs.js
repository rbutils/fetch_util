  function codeBindingElement(node, href) {
    var element = document.createElement(node.matches("a") ? "a" : "span");
    ["id", "name", "title", "class", "lang", "dir", "aria-label", "aria-labelledby"].forEach(function(attribute) {
      if (node.hasAttribute(attribute)) element.setAttribute(attribute, node.getAttribute(attribute));
    });
    if (href) element.setAttribute("href", href);
    return element;
  }

  function appendLinkedCodeReferences(code, text, source) {
    if (!source) return false;
    var nodes = Array.isArray(source) ? source : [source];
    var hasReference = nodes.some(function(node) {
      var links = Array.prototype.slice.call(node.querySelectorAll("a[href]"));
      if (node.matches("a[href]")) links.unshift(node);
      return links.some(function(link) {
        return normalizeText(link.textContent) && materializedHttpUrl(link.getAttribute("href"));
      });
    });
    if (!hasReference) return false;

    var surface = namedCodeTargetSurface(source, true);
    if (cleanCodeText(surface.text) !== text || !surface.references.some(function(reference) {
      return reference.end > reference.start;
    })) return false;

    var normalized = surface.text.replace(/\r\n?/g, "\n");
    var leading = (normalized.match(/^\n+/) || [""])[0].length;
    var cursor = 0, normalizedOffset = 0, previous = 0;
    var parents = [code];
    surface.bindings.forEach(function(binding) {
      if (binding.reference && binding.reference.end <= binding.reference.start) return;
      while (cursor < binding.offset) {
        cursor += surface.text[cursor] === "\r" && surface.text[cursor + 1] === "\n" ? 2 : 1;
        normalizedOffset++;
      }
      var offset = Math.max(0, Math.min(text.length, normalizedOffset - leading));
      var parent = parents[parents.length - 1];
      if (offset > previous) parent.appendChild(document.createTextNode(text.slice(previous, offset)));
      if (binding.kind === "open") {
        var anchor = codeBindingElement(binding.reference.node, binding.reference.href);
        parent.appendChild(anchor);
        parents.push(anchor);
      } else if (binding.kind === "close") {
        parents.pop();
      } else {
        parent.appendChild(codeBindingElement(binding.node, materializedHttpUrl(binding.node.getAttribute("href"))));
      }
      previous = offset;
    });
    if (previous < text.length) parents[parents.length - 1].appendChild(document.createTextNode(text.slice(previous)));
    return true;
  }

  function linkedCodeProgramHtml(pre) {
    var code = pre.querySelector("code");
    if (!code || !Array.prototype.some.call(code.querySelectorAll("a[href]"), function(anchor) {
      return normalizeText(anchor.textContent) && materializedHttpUrl(anchor.getAttribute("href"));
    })) return null;
    var program = document.createElement("pre");
    ["id", "name", "title", "lang", "dir"].forEach(function(attribute) {
      if (pre.hasAttribute(attribute)) program.setAttribute(attribute, pre.getAttribute(attribute));
    });
    program.appendChild(code.cloneNode(true));
    return program.outerHTML;
  }
