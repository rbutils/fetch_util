  function escapeMarkdownLinkLabel(text) {
    return String(text == null ? "" : text).replace(/\\/g, "\\\\").replace(/[\[\]_*]/g, function(character, index, label) {
      // Intraword underscores do not open emphasis; retain plain reference identifiers.
      if (character === "_" && /[a-z0-9]/i.test(label.charAt(index - 1)) &&
          /[a-z0-9]/i.test(label.charAt(index + 1))) return character;
      return "\\" + character;
    });
  }

  function markdownLink(text, url) {
    var href = listPresentationUrl(url);
    if (!normalizeText(text)) text = href || "";
    return href ? "[" + escapeMarkdownLinkLabel(text) + "](" + href + ")" : text;
  }

  function markdownLinkWithFormattedLabel(markdown, url) {
    var href = listPresentationUrl(url);
    if (!normalizeText(markdown)) markdown = href ? escapeMarkdownLinkLabel(href) : "";
    return href ? "[" + markdown + "](" + href + ")" : markdown;
  }

  function preserveAccessibleLinkLabels(root) {
    root.querySelectorAll("a[aria-label][href]").forEach(function(link) {
      var label = normalizeText(link.getAttribute("aria-label"));
      if (!label || !materializedHttpUrl(link.getAttribute("href"))) return;
      var visible = link.cloneNode(true);
      visible.querySelectorAll("svg, [aria-hidden='true']").forEach(function(node) { node.remove(); });
      if (normalizeText(visible.textContent)) return;
      if (Array.prototype.some.call(visible.querySelectorAll("img[alt]"), function(image) {
        return !!normalizeText(image.getAttribute("alt"));
      })) return;
      link.appendChild(document.createTextNode(label));
    });
  }

  function markdownFragmentTargetIndex(root) {
    var targets = new Map();
    var nodes = Array.prototype.slice.call(root.querySelectorAll("[id], a[name]"));
    if (root.matches && root.matches("[id], a[name]")) nodes.unshift(root);
    nodes.forEach(function(node) {
      [node.getAttribute("id"), node.matches("a[name]") && node.getAttribute("name")].forEach(function(name) {
        if (!name) return;
        if (!targets.has(name)) targets.set(name, new Set());
        targets.get(name).add(node);
      });
    });
    return targets;
  }

  function emptyMarkdownSelfControl(link, href, root, targets, sourceTargets) {
    if (!href || link.closest("pre, code, kbd, samp")) return false;
    try {
      var destination = new URL(href);
      var page = new URL(location.href);
      if (destination.origin !== page.origin || destination.pathname !== page.pathname || destination.search !== page.search) return false;
      if (!destination.hash) return href.endsWith("#");
      var heading = link.closest("h1, h2, h3, h4, h5, h6");
      if (!heading || !root.contains(heading)) return false;
      var id = decodeURIComponent(destination.hash.slice(1));
      var owners = (targets || markdownFragmentTargetIndex(root)).get(id);
      var sourceOwners = (sourceTargets || markdownFragmentTargetIndex(document)).get(id);
      return !!(owners && owners.size === 1 && sourceOwners && sourceOwners.size === 1 && heading.contains(Array.from(owners)[0]));
    } catch (_error) {
      return false;
    }
  }

  function preserveUnlabeledMarkdownDestinations(root) {
    var targets;
    var sourceTargets;
    root.querySelectorAll("a[href]").forEach(function(link) {
      if (link.closest("pre, code, kbd, samp") || normalizeText(link.textContent)) return;
      if (link.querySelector("img, video, audio, canvas, iframe, object, embed, math, pre, code")) return;
      var href = materializedHttpUrl(link.getAttribute("href"));
      if (!targets) targets = markdownFragmentTargetIndex(root);
      if (!sourceTargets) sourceTargets = markdownFragmentTargetIndex(document);
      if (!href || emptyMarkdownSelfControl(link, href, root, targets, sourceTargets)) {
        link.replaceWith.apply(link, Array.prototype.slice.call(link.childNodes));
        return;
      }
      var label = normalizeText(link.getAttribute("title")) || href;
      link.appendChild(document.createTextNode(label));
    });
  }

  function markdownLinkPrecedingText(link, root) {
    var previous = link;
    while (previous && previous !== root) {
      if (previous.previousSibling) {
        previous = previous.previousSibling;
        while (previous.lastChild) previous = previous.lastChild;
        if (previous.nodeType === Node.TEXT_NODE) return previous;
      } else {
        previous = previous.parentNode;
      }
    }
    return null;
  }

  function markdownLinkImageBoundaryText(link, root) {
    if (link.closest("pre, code, kbd, samp")) return null;
    var previous = markdownLinkPrecedingText(link, root);
    if (!previous || !previous.parentElement || previous.parentElement.closest("pre, code, kbd, samp")) return null;
    return previous.nodeValue.endsWith("!") ? previous : null;
  }

  function escapeMarkdownLinkImageBoundary(link, root) {
    var previous = markdownLinkImageBoundaryText(link, root);
    if (!previous || markdownEscapedAt(previous.nodeValue, previous.nodeValue.length - 1)) return;
    previous.nodeValue = previous.nodeValue.slice(0, -1) + "\\!";
  }

  function prepareMarkdownLinkBoundaryEscaping(service) {
    var boundaryTexts = new Set();
    var escape = service.escape;
    service.escape = function(text) {
      var escaped = escape.call(service, text);
      return boundaryTexts.has(text) ? escaped.slice(0, -1) + "\\!" : escaped;
    };
    return function(root) {
      boundaryTexts.clear();
      root.querySelectorAll("a[href]").forEach(function(link) {
        var previous = markdownLinkImageBoundaryText(link, root);
        if (previous) boundaryTexts.add(previous.nodeValue);
      });
    };
  }
