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

function articlePreferredSourcePrompt(node) {
  if (!node.matches("div, section") || node.children.length || codeContentNode(node) ||
      node.closest("p, a, blockquote, pre, code, table, aside, nav, [data-fetchutil-social-comment], [itemprop~='comment' i], .comment, .reply, .comment-body, .reply-body")) return false;
  var tokens = articleWidgetTokens(node);
  if (tokens.indexOf("preferred") === -1 || tokens.indexOf("source") === -1) return false;
  var text = normalizeText(node.textContent || "");
  if (!/^(?:(?:make|add|choose|set|select)\s+.+\s+(?:a|your)\s+preferred\s+source(?:\s+on\s+google)?|(?:κάντε|προσθέστε|ορίστε)\s+.+\s+προτιμώμενη\s+πηγή)$/i.test(text)) return false;
  var selected = node.closest("article");
  if (!selected) return false;
  var sources = Array.from(document.querySelectorAll("article")).filter(function(article) {
    return !elementSubtreeHidden(article) && (selected.id ? article.id === selected.id : !article.parentElement.closest("article"));
  });
  if (sources.length !== 1) return false;
  var source = sources[0];
  var sourceHeading = source.querySelector("h1");
  var selectedHeading = selected.querySelector("h1");
  if (!sourceHeading || !selectedHeading || normalizeText(sourceHeading.textContent) !== normalizeText(selectedHeading.textContent)) return false;
  var matches = Array.from(source.querySelectorAll("div, section")).filter(function(original) {
    return !elementSubtreeHidden(original) && original.closest("article") === source && !original.children.length &&
      !original.closest("blockquote, pre, code, table, aside, nav") &&
      original.getAttribute("class") === node.getAttribute("class") && normalizeText(original.textContent) === text;
  });
  return matches.length === 1;
}
