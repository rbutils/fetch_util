  function escapeMarkdownLinkLabel(text) {
    return String(text == null ? "" : text).replace(/\\/g, "\\\\").replace(/([\[\]])/g, "\\$1");
  }

  function markdownLink(text, url) {
    if (!normalizeText(text)) return "";
    var href = listPresentationUrl(url);
    return href ? "[" + escapeMarkdownLinkLabel(text) + "](" + href + ")" : text;
  }

  function markdownLinkWithFormattedLabel(markdown, url) {
    if (!normalizeText(markdown)) return "";
    var href = listPresentationUrl(url);
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

  function removeEmptyMarkdownLinks(root) {
    root.querySelectorAll("a[href]").forEach(function(link) {
      if (link.closest("pre, code, kbd, samp") || normalizeText(link.textContent)) return;
      if (link.querySelector("img, video, audio, canvas, iframe, object, embed, math, pre, code")) return;
      link.replaceWith.apply(link, Array.prototype.slice.call(link.childNodes));
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
