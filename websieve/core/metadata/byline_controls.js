function bylineWithoutSourceControls(value, roots) {
  if (!value) return value;
  var fields = [];
  roots.forEach(function(root) {
    root.querySelectorAll("[class*='byline' i], [class*='author' i], [itemprop='author'], [rel='author']").forEach(function(node) {
      if (fields.indexOf(node) < 0 && !elementSubtreeHidden(node) && articleBylineNode(node) &&
          !node.closest("nav, aside, footer") && normalizeText(node.textContent) === normalizeText(value)) fields.push(node);
    });
  });
  fields = fields.filter(function(node) {
    return !fields.some(function(other) { return other !== node && node.contains(other); });
  });
  if (fields.length !== 1) return value;
  var field = fields[0];
  var owner = field.closest("article, main, [role='main']");
  var sourceOwner = owner && articleActionSourceOwner(owner);
  var clone = field.cloneNode(true);
  var sources = Array.from(field.querySelectorAll("*"));
  var copies = Array.from(clone.querySelectorAll("*"));
  sources.forEach(function(node, index) {
    if (elementSubtreeHidden(node) || node.closest("a[href], p, blockquote, pre, code, figure, figcaption, table")) return;
    if (articleSyntheticAudioNotice(node) || (sourceOwner && articleActionCluster(node, sourceOwner))) copies[index].remove();
  });
  return normalizeText(clone.textContent) || null;
}
