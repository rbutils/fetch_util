function inferredBylineFieldWord(word) {
  return /^(?:authors?|authorship|bylines?|writers?|reporters?|writtenby|dateline)$/.test(word) ||
    /^(?:autor(?:a|as|es|i|en|s)?|auteurs?|verfasser|redakteur(?:e|in|innen)?|penulis|tacgia)$/.test(word);
}

function inferredBylineFieldMarker(marker) {
  var words = String(marker || "").replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .toLowerCase().split(/[\s_:.-]+/).filter(Boolean);
  for (var index = 0; index < words.length; index += 1) {
    var word = words[index];
    if (/^(?:font|typeface|typography)$/.test(word) || /^(?:font|typeface|typography)(?:author|byline)/.test(word)) return false;
    if (inferredBylineFieldWord(word)) return true;
  }
  var compound = words.join("");
  return inferredBylineFieldWord(compound) ||
    /(?:author|byline|writer|reporter|autor|auteur|penulis)(?:s|name|names|info)?$/.test(compound);
}

function inferredArticleBylineNode(node) {
  if (!node || node.nodeType !== 1) return false;
  if (node.matches("html, body, main, [role~='main']")) return false;
  if (node.closest("pre, script, style, template")) return false;

  if (node.matches("[itemprop~='author']")) {
    var names = Array.from(node.querySelectorAll("[itemprop~='name']")).filter(function(name) {
      return name.closest("[itemprop~='author']") === node;
    });
    // An entity's other properties do not become part of its declared name.
    if (names.length === 1) return false;
    return articleBylineNode(node);
  }
  if (node.matches("[rel~='author']")) return articleBylineNode(node);
  if (node.matches("[itemprop~='name']") && node.closest("[itemprop~='author']")) return articleBylineNode(node);

  var markers = (node.getAttribute("class") || "").split(/\s+/);
  markers.push(node.id || "", node.getAttribute("data-testid") || "");
  return markers.some(inferredBylineFieldMarker) && articleBylineNode(node);
}

function inferredBylineSourceNodes(sourceClones) {
  var sources = new WeakMap();
  sourceClones.forEach(function(clone, source) {
    if (source.nodeType !== 1) return;
    var markers = [source.id, source.getAttribute("class"), source.getAttribute("rel"), source.getAttribute("itemprop")].join(" ");
    if (/(?:byline|author|dateline|writtenby)/i.test(markers)) sources.set(clone, source);
  });
  return sources;
}
