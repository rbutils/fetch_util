function listMarkdown(items) {
  return items.map(function(item) {
    var line = item.url ? "- [" + item.text + "](" + item.url + ")" : "- " + item.text;
    var card = item.card;
    var context = [
      item.category,
      item.summary,
      cardField(card, "[rel='author'], [itemprop='author'], [class*='author' i], [data-author]") || item.author,
      cardField(card, "time, [datetime], [class*='timestamp' i], [class*='date' i]") || item.time,
      cardField(card, "[class*='score' i], [data-score], [data-karma]") || item.score,
      cardField(card, ".reply, .replies, .comment, .comments, [class~='reply'], [class~='replies'], [class~='comment'], [class~='comments'], [class*='reply'], [class*='replie'], [class*='comment'], [data-reply], [data-replies], [data-comment], [data-comments]") || item.replyCount,
      cardField(card, "[class*='community' i], [class*='subreddit' i], [data-community]") || item.community,
      item.image,
      item.caption
    ].filter(Boolean).filter(function(value, index, values) {
      return values.indexOf(value) === index;
    }).join(" - ");
    if (context) line += " - " + context;
    else if (item.detail) line += " - " + item.detail;
    return line;
  }).join("\n");
}

function cardField(card, selector) {
  if (!card || !card.querySelector) return "";
  var node = cardOwnedNodes(card, selector)[0];
  if (!node) return "";
  var value = normalizeText(node.getAttribute("datetime") || node.getAttribute("content") || node.textContent || "");
  if (!value) return "";
  if (/^(comment|comments|reply|replies|score|points|likes?)$/i.test(value)) return "";
  return value;
}
