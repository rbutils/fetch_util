function articleAvailabilityModalNode(node) {
  if (!node || !node.matches("div, section, aside") || node.children.length || codeContentNode(node)) return false;
  var tokens = articleWidgetTokens(node);
  if (tokens.indexOf("modal") === -1 || tokens.indexOf("overlay") === -1) return false;
  var text = normalizeText(node.textContent || "");
  if (!/^(?:where to watch\s+)?(?:stream|rent|buy)(?:\s+(?:stream|rent|buy))+$/i.test(text)) return false;

  var article = node.closest("article");
  if (!article) return false;
  var owners = article.id ? Array.from(document.querySelectorAll("article[id]")).filter(function(owner) {
    return owner.id === article.id;
  }) : Array.from(document.querySelectorAll("article")).filter(function(owner) {
    return !owner.parentElement.closest("article");
  });
  if (owners.length !== 1 || elementSubtreeHidden(owners[0])) return false;
  var heading = article.querySelector("h1");
  var sourceHeading = owners[0].querySelector("h1");
  if (!heading || !sourceHeading || normalizeText(heading.textContent) !== normalizeText(sourceHeading.textContent)) return false;
  var sources = Array.from(owners[0].querySelectorAll("div, section, aside")).filter(function(source) {
    return source.id === node.id && source.getAttribute("class") === node.getAttribute("class") &&
      !elementSubtreeHidden(source) && !source.children.length && normalizeText(source.textContent) === text;
  });
  return sources.length === 1 && sources[0].closest("article") === owners[0];
}
