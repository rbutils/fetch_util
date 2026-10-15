function productPhysicalResources(root, context) {
  var present = new Set(Array.from(root.querySelectorAll("a[href]")).map(function(link) {
    return materializedHttpUrl(link.getAttribute("href"));
  }).filter(Boolean));
  var resources = [];
  var model = productIdentityKey(context.heading.textContent).replace(/^20\d{2}/, "");
  if (!model) return;
  context.regions.forEach(function(region) {
    Array.from(region.querySelectorAll("a[href][aria-label]")).forEach(function(source) {
      var href = materializedHttpUrl(source.getAttribute("href"));
      var label = normalizeText(source.getAttribute("aria-label"));
      if (!href || present.has(href) || productIdentityKey(label).indexOf(model) === -1 ||
          productSourceChrome(source, region) || elementSubtreeHidden(source)) return;
      present.add(href);
      var link = document.createElement("a");
      link.setAttribute("href", href);
      link.textContent = label;
      var item = document.createElement("li");
      item.appendChild(link);
      resources.push(item);
    });
  });
  if (!resources.length) return;
  var heading = document.createElement("h2");
  heading.textContent = "Product resources";
  var list = document.createElement("ul");
  resources.forEach(function(item) { list.appendChild(item); });
  root.appendChild(heading);
  root.appendChild(list);
}

function sourceOwnedProductContent(metadata) {
  var context = sourceOwnedProductContext(metadata);
  if (!context) return null;
  var root = document.createElement("article");
  context.regions.forEach(function(region) {
    var sourceClones = new Map();
    var visible = visibilityPrunedClone(region, document, sourceClones);
    Array.from(region.querySelectorAll("svg[aria-label]")).forEach(function(source) {
      var glyph = sourceClones.get(source);
      if (!glyph || !glyph.parentNode || !source.querySelector("use[href^='#']") ||
          source.closest("a, button, [role='button'], [role='combobox']") || productSourceChrome(source, region)) return;
      if (!Array.from(source.children).every(function(child) { return /^(?:use|title|desc)$/i.test(child.localName); })) return;
      var label = normalizeText(source.getAttribute("aria-label"));
      if (label) glyph.replaceWith(document.createTextNode(label));
    });
    context.labels.forEach(function(label) {
      var sourceButton = label.closest("button");
      var button = sourceButton && sourceClones.get(sourceButton);
      if (!button || !button.parentNode) return;
      var paragraph = document.createElement("p");
      while (button.firstChild) paragraph.appendChild(button.firstChild);
      button.replaceWith(paragraph);
    });
    var clone = cleanClone(visible);
    if (clone.tagName === "SCRIPT" || clone.tagName === "STYLE" || clone.tagName === "LINK") return;
    while (clone.firstChild) root.appendChild(clone.firstChild);
  });
  cleanupAgentRoot(root);
  productPhysicalResources(root, context);
  var title = normalizeText(context.heading.textContent);
  var lead = Array.from(root.querySelectorAll("p")).map(function(node) { return normalizeText(node.textContent); }).find(function(text) {
    return /[.!?。！？](?:\s|$)/.test(text);
  });
  var html = root.innerHTML;
  var markdown = markdownFor(html);
  var dates = Array.from(root.querySelectorAll("[itemprop~='datePublished']")).map(function(node) {
    return normalizeText(node.getAttribute("datetime") || node.getAttribute("content") || node.textContent);
  }).filter(function(value, index, all) { return visiblePublicationDateLike(value) && all.indexOf(value) === index; });
  return {
    title: title,
    description: context.description,
    byline: null,
    date: null,
    publishedTime: dates.length === 1 ? dates[0] : null,
    excerpt: lead || normalizeText(metadata.excerpt || metadata.description || ""),
    textContent: root.textContent,
    html: html,
    markdown: markdown,
    docsLike: false,
    readerMode: false,
    sourceOwnedProduct: true,
    contentType: "product"
  };
}
