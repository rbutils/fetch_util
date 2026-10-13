  function mergeAdjacentEmphasis(root) {
    root.querySelectorAll("em, i").forEach(function(node) {
      if (!node.parentNode || node.attributes.length || node.closest("pre, code, kbd, samp")) return;
      var next = node.nextSibling;
      while (next && next.nodeType === Node.ELEMENT_NODE && next.nodeName === node.nodeName && !next.attributes.length) {
        while (next.firstChild) node.appendChild(next.firstChild);
        next.remove();
        next = node.nextSibling;
      }
    });
  }

  function emphasisBoundaryText(node, previous) {
    var blockBoundary = "p, li, td, th, h1, h2, h3, h4, h5, h6, div, section, article, main, blockquote, pre";
    for (var current = node; current && current.parentElement; current = current.parentElement) {
      for (var sibling = previous ? current.previousSibling : current.nextSibling; sibling;
        sibling = previous ? sibling.previousSibling : sibling.nextSibling) {
        if (sibling.nodeType === Node.COMMENT_NODE) continue;
        if (sibling.nodeType === Node.ELEMENT_NODE && sibling.matches("br, " + blockBoundary)) return "";
        var text = sibling.textContent || "";
        if (text) return text;
      }
      if (current.parentElement.matches(blockBoundary)) return "";
    }
    return "";
  }

  function intrawordEmphasis(node) {
    if (node.nodeName !== "EM" && node.nodeName !== "I") return false;
    var content = (node.textContent || "").trim();
    return /^[\p{L}\p{N}\p{M}]/u.test(content) &&
      /[\p{L}\p{N}\p{M}]$/u.test(emphasisBoundaryText(node, true)) ||
      /[\p{L}\p{N}\p{M}]$/u.test(content) &&
      /^[\p{L}\p{N}\p{M}]/u.test(emphasisBoundaryText(node, false));
  }

  function addIntrawordEmphasisRule(service) {
    service.addRule("intrawordEmphasis", {
      filter: intrawordEmphasis,
      replacement: function(content) {
        if (!content) return "";
        // CommonMark forbids underscores inside words, including Unicode modifier letters.
        return "*" + content + "*";
      }
    });
  }
