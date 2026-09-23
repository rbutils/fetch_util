function articleGroupedActionKind(value) {
  var text = normalizeText(value || "");
  if (/^(?:show (?:article )?summary|tampilkan ringkasan artikel)$/i.test(text)) return "summary";
  if (/^(?:listen to (?:this |the )?article|dengarkan artikel)$/i.test(text)) return "listen";
  if (/^(?:share(?: this article)?|bagikan)$/i.test(text)) return "share";
  return null;
}

function articleGroupedActionPrompt(node) {
  if (!node.matches("p") || !node.closest("article") || node.closest("blockquote, aside") ||
      node.children.length || codeContentNode(node)) return false;
  var kind = articleGroupedActionKind(node.textContent);
  if (!kind) return false;

  var selected = node.closest("article");
  var source = selected.id ? document.getElementById(selected.id) :
    document.querySelectorAll("article").length === 1 ? document.querySelector("article") : null;
  if (!source || !source.matches("article") || elementSubtreeHidden(source)) return false;

  var paragraphs = Array.from(source.querySelectorAll("p")).filter(function(paragraph) {
    return !elementSubtreeHidden(paragraph) && !paragraph.closest("blockquote, aside") && !paragraph.children.length;
  });
  if (paragraphs.filter(function(paragraph) {
    return !articleGroupedActionKind(paragraph.textContent) && normalizeText(paragraph.textContent).length >= 90;
  }).length < 3) return false;

  var actions = paragraphs.filter(function(paragraph) { return articleGroupedActionKind(paragraph.textContent); });
  if (actions.length !== 3 || ["summary", "listen", "share"].some(function(action) {
    return actions.filter(function(paragraph) { return articleGroupedActionKind(paragraph.textContent) === action; }).length !== 1;
  })) return false;
  return actions.some(function(paragraph) {
    return normalizeText(paragraph.textContent) === normalizeText(node.textContent);
  });
}
