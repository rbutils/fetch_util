  function svgMaterialTextNodes(svg) {
    if (!svg || svg.localName !== "svg" || svg.namespaceURI !== "http://www.w3.org/2000/svg") return [];
    var excluded = "defs, clipPath, mask, pattern, marker, symbol, pre, code, kbd, samp, nav, button, " +
      "[role='button'], [hidden], [inert], [aria-hidden='true']";
    return Array.from(svg.querySelectorAll("text")).filter(function(node) {
      return !node.closest(excluded) && !!normalizeText(node.textContent);
    });
  }

  function svgDeclaredImageName(svg) {
    if (!svg || svg.localName !== "svg" || svg.namespaceURI !== "http://www.w3.org/2000/svg") return "";
    if (normalizeText(svg.getAttribute("role") || "").toLowerCase() !== "img") return "";
    var excluded = "defs, clipPath, mask, pattern, marker, symbol, pre, code, kbd, samp, nav, button, " +
      "[role='button'], [role='navigation'], [role='toolbar'], [hidden], [inert], [aria-hidden='true']";
    if (svg.closest(excluded) || normalizeText(svg.getAttribute("aria-labelledby") || "")) return "";
    var label = normalizeText(svg.getAttribute("aria-label") || "");
    if (label) return label;
    var titles = Array.from(svg.children).filter(function(node) {
      return node.localName === "title" && node.namespaceURI === svg.namespaceURI;
    });
    return titles.length === 1 ? normalizeText(titles[0].textContent) : "";
  }

  function inlineSvgVisibilityHidden(node, svg) {
    var current = node;
    while (current && svg.contains(current)) {
      var visibility = current.style && current.style.visibility;
      if (visibility && visibility !== "inherit" && visibility !== "unset") {
        return visibility === "hidden" || visibility === "collapse";
      }
      if (current === svg) break;
      current = current.parentElement;
    }
    return false;
  }

  function pruneInlineSvgVisibility(svg) {
    var nodes = [svg].concat(Array.from(svg.querySelectorAll("*")));
    var rootHidden = false;
    nodes.forEach(function(node) {
      var style = node.style;
      var hidden = node.hasAttribute("hidden") || node.hasAttribute("inert") || node.getAttribute("aria-hidden") === "true" ||
        (style && (style.display === "none" || (style.opacity !== "" && Number(style.opacity) === 0)));
      if (hidden) {
        if (node === svg) rootHidden = true;
        node.remove();
      } else if (/^(?:path|rect|circle|ellipse|line|polygon|polyline|use|image)$/.test(node.localName || "") &&
          inlineSvgVisibilityHidden(node, svg)) {
        node.remove();
      }
    });
    var walker = svg.ownerDocument.createTreeWalker(svg, NodeFilter.SHOW_TEXT);
    var hiddenText = [];
    while (walker.nextNode()) {
      var parent = walker.currentNode.parentElement;
      if (parent && parent.closest("text") && inlineSvgVisibilityHidden(parent, svg)) hiddenText.push(walker.currentNode);
    }
    hiddenText.forEach(function(node) { node.remove(); });
    return !rootHidden;
  }

  function preserveSvgCloneVisibility(source, clone, elementMap) {
    var originals = Array.from(source.querySelectorAll("svg"));
    var copies = Array.from(clone.querySelectorAll("svg"));
    if (originals.length !== copies.length) return;
    originals.forEach(function(svg, index) {
      if ((!svg.querySelector("text") && !svgDeclaredImageName(svg)) ||
          (svg.parentElement && svg.parentElement.closest("svg"))) return;
      var copied = copies[index];
      if (svg.isConnected && svg.ownerDocument === document) {
        var visible = visibilityPrunedClone(svg, copied.ownerDocument, elementMap, true);
        if (visible.localName !== "svg") {
          copied.remove();
          return;
        }
        copied.replaceWith(visible);
        copied = visible;
      }
      if (!pruneInlineSvgVisibility(copied)) copied.remove();
    });
  }

  function materializeSvgPresentationAttribute(element, attribute) {
    var value = element.getAttribute(attribute);
    if (!value) return;
    var reference = value.trim().match(/^url\(\s*(["']?)#([^\s"'()\\]+)\1\s*\)$/i);
    if (reference) {
      var svg = element.closest("svg");
      var targets = svg ? Array.from(svg.querySelectorAll("[id]")).filter(function(node) {
        return node.id === reference[2] && node.namespaceURI === "http://www.w3.org/2000/svg";
      }) : [];
      if (targets.length === 1) return;
    } else if (!/[\\;{}]/.test(value) && !/(?:url|var|env|attr|expression)\s*\(/i.test(value) &&
        typeof CSS !== "undefined" && CSS.supports(attribute, value)) {
      return;
    }
    element.removeAttribute(attribute);
  }

  function appendSvgMarkdownMaterial(source, target, labels) {
    Array.from(source.children || []).forEach(function(node) {
      var name = (node.localName || "").toLowerCase();
      if (/^(?:defs|clippath|mask|pattern|marker|symbol|title|desc)$/.test(name)) return;
      if (name === "text") {
        if (!labels.has(node)) return;
        var paragraph = target.ownerDocument.createElement("p");
        paragraph.textContent = node.textContent;
        target.appendChild(paragraph);
        return;
      }
      if (name === "a") {
        var href = materializedHttpUrl(node.getAttribute("href") || node.getAttribute("xlink:href"));
        if (href) {
          var link = target.ownerDocument.createElement("a");
          link.setAttribute("href", href);
          appendSvgMarkdownMaterial(node, link, labels);
          var block = target.ownerDocument.createElement("p");
          block.appendChild(link);
          target.appendChild(block);
          return;
        }
      }
      if (name === "image") {
        var src = materializedHttpUrl(node.getAttribute("href") || node.getAttribute("xlink:href"));
        if (src) {
          var image = target.ownerDocument.createElement("img");
          image.setAttribute("src", src);
          image.setAttribute("alt", node.getAttribute("aria-label") || "");
          target.appendChild(image);
        }
        return;
      }
      appendSvgMarkdownMaterial(node, target, labels);
    });
  }

  function materializeMarkdownSvgText(root) {
    Array.from(root.querySelectorAll("svg")).forEach(function(svg) {
      if (!root.contains(svg) || !pruneInlineSvgVisibility(svg)) return;
      var nodes = svgMaterialTextNodes(svg);
      if (!nodes.length) {
        var name = svgDeclaredImageName(svg);
        if (!name) return;
        var alternative = root.ownerDocument.createElement("span");
        alternative.textContent = name;
        svg.replaceWith(alternative);
        return;
      }
      var figure = root.ownerDocument.createElement("figure");
      appendSvgMarkdownMaterial(svg, figure, new Set(nodes));
      svg.replaceWith(figure);
    });
  }
