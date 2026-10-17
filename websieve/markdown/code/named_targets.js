  function namedCodeTargetSurface(source) {
    var chunks = [], targets = [], length = 0;
    function append(text) {
      chunks.push(text);
      length += text.length;
    }
    function walk(node) {
      if (node.nodeType === 3) { append(node.textContent); return; }
      if (node.nodeType !== 1) return;
      if (node.matches("br")) { append("\n"); return; }
      if (node.matches("button, script, style, template, [hidden], [aria-hidden='true']")) return;
      if (node.matches("a[id], a[name]") && !node.textContent && !node.children.length &&
          (node.getAttribute("id") || node.getAttribute("name"))) {
        targets.push({ node: node, offset: length });
      }
      var children = Array.prototype.slice.call(node.childNodes);
      var lines = children.filter(function(child) {
        return child.nodeType === 1 && child.matches("div, p, li");
      });
      if (lines.length && children.every(function(child) {
        return child.nodeType === 1 && child.matches("div, p, li") || child.nodeType === 3 && !child.textContent.trim();
      })) {
        lines.forEach(function(line, index) { if (index) append("\n"); walk(line); });
      } else {
        children.forEach(walk);
      }
    }
    var nodes = Array.isArray(source) ? source : [source];
    nodes.forEach(function(node, index) { if (index) append("\n"); walk(node); });
    return { text: chunks.join(""), targets: targets };
  }

  function appendNamedCodeTargets(code, text, source) {
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
