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

  function nextCitationSibling(node) {
    var next = node.nextSibling;
    while (next && next.nodeType === Node.COMMENT_NODE) next = next.nextSibling;
    return next;
  }

  function mergeAdjacentCitationLetters(root) {
    root.querySelectorAll("a[href]").forEach(function(link) {
      var emphasis = nextCitationSibling(link);
      if (!emphasis || emphasis.nodeType !== Node.ELEMENT_NODE || !emphasis.matches("em, i") ||
          emphasis.attributes.length || emphasis.children.length || link.closest("pre, code, kbd, samp") ||
          link.querySelector("img, svg, math, button, input, pre, code, kbd, samp")) return;
      var letter = emphasis.textContent || "";
      if (!/^[a-z]$/i.test(letter)) return;
      var href = materializedHttpUrl(link.getAttribute("href"));
      if (!href) return;
      var path = new URL(href).pathname;
      var label = normalizeText(link.textContent || "");
      var section = /^Section\s+\d[\d.]*$/i.test(label) && /\/section-[^/]+$/.test(path);
      var statute = /^\d+$/.test(label) && /\/link\/uscode\//.test(path);
      if (!section && !statute) return;

      var suffix = "";
      var following = nextCitationSibling(emphasis);
      if (section) {
        if (!following || following.nodeType !== Node.TEXT_NODE) return;
        var number = following.textContent.match(/^-\d+(?![\p{L}\p{N}\p{M}])/u);
        if (!number) return;
        suffix = number[0];
      } else if (/^[\p{L}\p{N}\p{M}]/u.test(emphasisBoundaryText(emphasis, false))) return;

      link.appendChild(root.ownerDocument.createTextNode(letter + suffix));
      emphasis.remove();
      if (suffix) following.textContent = following.textContent.slice(suffix.length);
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
