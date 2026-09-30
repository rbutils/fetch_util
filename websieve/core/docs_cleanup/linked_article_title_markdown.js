function articleSelfLinkedHeadlineMarkdown(markdown, html, title) {
  if (!markdown || !html || !title || !document.body) return markdown;
  var root = document.createElement("div");
  root.innerHTML = html;
  var articles = root.querySelectorAll("article");
  if (articles.length !== 1) return markdown;
  var proof = sourceOwnedSelfLinkedArticle(articles[0], title);
  if (!proof) return markdown;

  var lines = markdown.split("\n");
  var first = lines.findIndex(function(line) { return !!normalizeText(line); });
  var firstLine = normalizeText(lines[first] || "");
  var plainTitle = normalizeText(firstLine.replace(/^#{1,6}\s+/, ""));
  var linkedTitle = markdownLink(title, proof.url);
  if (first < 0 || (plainTitle !== normalizeText(title) && plainTitle !== normalizeText(linkedTitle))) return markdown;
  lines[first] = "# " + markdownLink(title, proof.url);
  return lines.join("\n");
}
