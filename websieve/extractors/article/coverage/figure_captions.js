  function sourceOwnedFigureCaptionContent(content) {
    if (!content || content.contentType !== "article" || !content.readerMode || content.hostAware ||
        content.markdown || !content.html || !/<figure(?:\s|>)/i.test(content.html)) return content;
    var root = document.createElement("div");
    root.innerHTML = content.html;
    var missingCaptions = Array.from(root.querySelectorAll("figure")).filter(function(figure) {
      return !figure.querySelector("figcaption") && figure.querySelectorAll("img[src]").length === 1;
    });
    if (!missingCaptions.length) return content;
    var owner = articleResourceOwner(content);
    if (!owner) return content;

    var figuresByImage = new Map();
    owner.querySelectorAll("figure").forEach(function(figure) {
      if (elementSubtreeHidden(figure)) return;
      var images = figure.querySelectorAll("img[src]");
      var caption = figure.querySelector("figcaption");
      if (images.length !== 1 || !caption || elementSubtreeHidden(caption)) return;
      var url = materializedHttpUrl(images[0].getAttribute("src"));
      if (!url || !normalizeText(caption.textContent || "")) return;
      figuresByImage.set(url, figuresByImage.has(url) ? null : caption);
    });
    if (!figuresByImage.size) return content;

    var originalHtml = root.innerHTML;
    missingCaptions.forEach(function(figure) {
      var url = materializedHttpUrl(figure.querySelector("img[src]").getAttribute("src"));
      var caption = figuresByImage.get(url);
      if (!caption || normalizeText(content.textContent || "").includes(normalizeText(caption.textContent))) return;
      figure.appendChild(visibilityPrunedClone(caption, document));
    });
    if (root.innerHTML === originalHtml) return content;
    return Object.assign({}, content, {
      html: root.innerHTML,
      textContent: normalizeText(root.textContent || "")
    });
  }
