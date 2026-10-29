  function namedCodeTargetSurface(source, preserveReferences) {
    var chunks = [], targets = [], bindings = [], references = [], length = 0;
    function append(text) {
      chunks.push(text);
      length += text.length;
    }
    function walk(node) {
      if (node.nodeType === 3) { append(node.textContent); return; }
      if (node.nodeType !== 1) return;
      if (node.matches("br")) { append("\n"); return; }
      if (node.matches("button, [role='button' i], script, style, template, [hidden], [aria-hidden='true']")) return;
      var emptyTarget = node.matches("a[id], a[name]") && !node.textContent && !node.children.length &&
        (node.getAttribute("id") || node.getAttribute("name"));
      if (emptyTarget) {
        var target = { node: node, offset: length, kind: "target" };
        targets.push(target);
        if (preserveReferences) bindings.push(target);
      }
      var href = preserveReferences && node.matches("a[href]") && normalizeText(node.textContent) &&
        materializedHttpUrl(node.getAttribute("href"));
      var reference = href ? { node: node, href: href, start: length, end: length } : null;
      if (reference) {
        references.push(reference);
        bindings.push({ kind: "open", offset: length, reference: reference });
      } else if (preserveReferences && !emptyTarget && !node.matches("pre") &&
          (node.hasAttribute("id") || node.matches("a[name]"))) {
        bindings.push({ kind: "target", node: node, offset: length });
      }
      var lines = codeSurfaceBlockLines(node);
      if (lines) {
        lines.forEach(function(line, index) { if (index) append("\n"); walk(line); });
      } else {
        Array.prototype.forEach.call(node.childNodes, walk);
      }
      if (reference) {
        reference.end = length;
        bindings.push({ kind: "close", offset: length, reference: reference });
      }
    }
    var nodes = Array.isArray(source) ? source : [source];
    nodes.forEach(function(node, index) { if (index) append("\n"); walk(node); });
    return { text: chunks.join(""), targets: targets, bindings: bindings, references: references };
  }

  function appendNamedCodeTargets(code, text, source) {
    if (appendLinkedCodeReferences(code, text, source)) return;
    var nodes = Array.isArray(source) ? source : [source];
    if (!source || !nodes.some(function(node) { return node.querySelector("a[id], a[name]"); })) {
      code.textContent = text;
      return;
    }
    var surface = namedCodeTargetSurface(source);
    if (!surface.targets.length || cleanCodeText(surface.text) !== text) {
      code.textContent = text;
      return;
    }
    var normalized = surface.text.replace(/\r\n?/g, "\n");
    var leading = (normalized.match(/^\n+/) || [""])[0].length;
    var cursor = 0, normalizedOffset = 0, previous = 0;
    surface.targets.forEach(function(target) {
      while (cursor < target.offset) {
        var width = surface.text[cursor] === "\r" && surface.text[cursor + 1] === "\n" ? 2 : 1;
        cursor += width;
        normalizedOffset++;
      }
      // Existing code cleanup trims edge newlines. Targets in those edges bind
      // the same complete program's start or end, without adding program text.
      var offset = Math.max(0, Math.min(text.length, normalizedOffset - leading));
      if (offset > previous) code.appendChild(document.createTextNode(text.slice(previous, offset)));
      var anchor = document.createElement("a");
      ["id", "name", "title", "class", "lang", "dir", "aria-label", "aria-labelledby"].forEach(function(attribute) {
        if (target.node.hasAttribute(attribute)) anchor.setAttribute(attribute, target.node.getAttribute(attribute));
      });
      var href = materializedHttpUrl(target.node.getAttribute("href"));
      if (href) anchor.setAttribute("href", href);
      code.appendChild(anchor);
      previous = offset;
    });
    if (previous < text.length) code.appendChild(document.createTextNode(text.slice(previous)));
  }

  function restorePrunedNamedCodeTargets(sourceRoot, sourceClones) {
    var programs = sourceRoot.tagName === "PRE" ? [sourceRoot] : sourceRoot.querySelectorAll("pre");
    programs.forEach(function(sourcePre) {
      var clonePre = sourceClones.get(sourcePre);
      if (!clonePre) return;
      var sourceCode = sourcePre.querySelector("code") || sourcePre;
      if (!sourceCode.querySelector("a[id], a[name]")) return;
      var cloneCode = clonePre.querySelector("code") || clonePre;
      var text = cleanCodeText(namedCodeTargetSurface(sourceCode).text);
      if (text !== cleanCodeText(namedCodeTargetSurface(cloneCode).text)) return;
      // Empty reference targets carry bindings, not hidden program text. Restore
      // them only when the visible clone already contains the entire program.
      cloneCode.replaceChildren();
      appendNamedCodeTargets(cloneCode, text, sourceCode);
    });
  }
