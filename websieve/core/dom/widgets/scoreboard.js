function articleUnrelatedScoreboardNode(node) {
  if (!node.matches("div, section, aside") || node.children.length || codeContentNode(node)) return false;
  if (articleWidgetTokens(node).indexOf("scoreboard") === -1) return false;
  var text = normalizeText(node.textContent || "");
  var score = text.match(/^([\p{L}\p{M}][\p{L}\p{M} .'-]*?)\s*\d+\s*(?:[-:]\s*)?([\p{L}\p{M}][\p{L}\p{M} .'-]*?)\s*\d+\s*(?:fine|final|finished|full time|ft|ht|live)$/iu);
  if (!score) return false;
  var sources = Array.from(document.querySelectorAll("div, section, aside")).filter(function(source) {
    return !source.children.length && !elementSubtreeHidden(source) &&
      source.localName === node.localName && source.id === node.id && source.className === node.className &&
      normalizeText(source.textContent || "") === text;
  });
  if (sources.length !== 1) return false;
  var owner = sources[0].parentElement.closest("article, section, [role='article'], main");
  if (!owner || sourceOwnershipInChrome(sources[0])) return false;
  var headings = Array.from(owner.querySelectorAll("h1")).filter(function(heading) {
    return !elementSubtreeHidden(heading);
  });
  var paragraphs = Array.from(owner.querySelectorAll("p")).filter(function(paragraph) {
    return !elementSubtreeHidden(paragraph) && !codeContentNode(paragraph);
  });
  if (headings.length !== 1 || !paragraphs.length) return false;
  var reporting = normalizeText(headings[0].textContent + " " + paragraphs.map(function(paragraph) {
    return paragraph.textContent || "";
  }).join(" ")).toLocaleLowerCase();
  return [score[1], score[2]].every(function(team) {
    return reporting.indexOf(normalizeText(team).toLocaleLowerCase()) === -1;
  });
}
