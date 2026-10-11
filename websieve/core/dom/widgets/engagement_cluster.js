function articleLeafEngagementBody(node) {
  var tokens = articleWidgetTokens(node);
  if (tokens.indexOf("facepile") === -1 &&
      !(tokens.some(function(token) { return /^(?:reaction|reactions|engagement)$/.test(token); }) &&
        tokens.some(function(token) { return /^(?:cluster|controls)$/.test(token); }))) return null;
  var article = node.closest("article");
  if (!article || node.closest("p, blockquote, pre, code, figure, [itemprop~='author' i], [itemprop~='comment' i], [rel~='author' i], .author, .byline, .comment, .comment-body, .reply-body, [data-fetchutil-social-comment]")) return null;
  for (var owner = node; owner && owner !== article; owner = owner.parentElement) {
    if (articleWidgetTokens(owner).some(function(token) { return /^(?:author|byline|comments?|replies|reply)$/.test(token); })) return null;
  }
  if (node.querySelector("article, main, section, p, h1, h2, h3, h4, h5, h6, blockquote, pre, code, table, ul, ol, dl, figure, video, audio, iframe, form, input, textarea, [itemprop], [rel~='author' i], .comment, .comment-body, .reply-body")) return null;

  var bodies = Array.from(article.querySelectorAll("div, section, [itemprop~='articleBody' i]")).filter(function(body) {
    if (body.closest("article") !== article || elementSubtreeHidden(body) ||
        body.closest("[itemprop~='comment' i], .comment, .comment-body, .reply-body")) return false;
    return (body.matches("[itemprop~='articleBody' i]") || articleWidgetTokens(body).indexOf("body") !== -1) &&
      Array.from(body.querySelectorAll("p")).some(function(paragraph) { return normalizeText(paragraph.textContent || ""); });
  });
  bodies = bodies.filter(function(body) { return !bodies.some(function(other) { return body !== other && body.contains(other); }); });
  return bodies.length === 1 && !bodies[0].contains(node) && !node.contains(bodies[0]) ? bodies[0] : null;
}

function articleLeafEngagementCounter(node) {
  if (!node.matches("a, span") || node.children.length) return false;
  var match = normalizeText(node.textContent || "").match(/^\d[\d,.\s]*\s+(likes?|reactions?|shares?|reposts?|restacks?)$/i);
  if (!match) return false;
  var href = node.getAttribute("href");
  if (!href) return true;
  try {
    var label = match[1].toLowerCase().replace(/s$/, "");
    var action = new URL(href, location.href).pathname.replace(/\/$/, "").split("/").pop().toLowerCase().replace(/s$/, "");
    return action === label;
  } catch (_error) { return false; }
}

function articleLeafEngagementCluster(node) {
  var body = articleLeafEngagementBody(node);
  if (!body || elementSubtreeHidden(node)) return null;
  var descendants = Array.from(node.querySelectorAll("*"));
  if (descendants.some(function(child) { return !child.matches("div, span, a, img, picture, source, br"); })) return null;
  var counters = descendants.filter(articleLeafEngagementCounter);
  var portraits = Array.from(node.querySelectorAll("img"));
  if (!counters.length || !portraits.length || portraits.some(function(image) {
    var link = image.closest("a[href]");
    return !link || !node.contains(link) || normalizeText(link.textContent || "") ||
      !/\b(?:avatar|portrait)\b/i.test(image.getAttribute("alt") || "") ||
      !/\bprofile\b/i.test(link.getAttribute("aria-label") || "");
  })) return null;
  if (Array.from(node.querySelectorAll("a[href]")).some(function(link) {
    return counters.indexOf(link) === -1 && !portraits.some(function(image) { return link.contains(image); });
  })) return null;
  if (Array.from(node.querySelectorAll("source")).some(function(source) {
    return !source.closest("picture") || !portraits.some(function(image) { return source.closest("picture").contains(image); });
  })) return null;
  var walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
  while (walker.nextNode()) {
    var textNode = walker.currentNode;
    if (counters.some(function(counter) { return counter.contains(textNode); })) continue;
    if (normalizeText(textNode.nodeValue || "").replace(/[\s·∙•|,]/g, "")) return null;
  }
  return body;
}

function sourceOwnedEngagementClusters(sourceRoot) {
  return Array.from(sourceRoot.querySelectorAll("div")).map(function(source) {
    var body = articleLeafEngagementCluster(source);
    return body ? { source: source, body: body } : null;
  }).filter(Boolean);
}

function stripSourceOwnedEngagementClusters(sourceRoot, selectedRoot, sourceClones, clusters) {
  if (!sourceRoot || !selectedRoot || !sourceClones) return;
  (clusters || sourceOwnedEngagementClusters(sourceRoot)).forEach(function(cluster) {
    var source = cluster.source;
    var selected = sourceClones.get(source);
    var selectedBody = sourceClones.get(cluster.body);
    if (selected && selectedBody && selected !== selectedRoot && selectedRoot.contains(selected) && selectedRoot.contains(selectedBody)) selected.remove();
  });
}
