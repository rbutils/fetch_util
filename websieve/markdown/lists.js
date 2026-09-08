function markdownLink(text, url) {
  var href = materializedHttpUrl(url);
  return href ? "[" + text + "](" + href + ")" : text;
}

function listItemMaterialIdentity(item, rawHref) {
  return JSON.stringify([
    item.url || "unlinked:" + (rawHref || ""),
    normalizeText(item.text || ""),
    normalizeText(item.detail || "")
  ]);
}

function listDetailWithoutContext(detail, contextValues) {
  var remaining = stripGenericListControlPhrases(detail || "");
  if (!remaining) return "";
  var represented = contextValues.map(normalizeText).filter(Boolean);
  return remaining.split(/\s+(?:[-|·])\s+/).filter(function(segment) {
    return represented.indexOf(normalizeText(segment)) === -1;
  }).join(" - ");
}

function listClonedCardNode(card, clone, node) {
  var path = [];
  while (node && node !== card) {
    var parent = node.parentNode;
    if (!parent) return null;
    path.unshift(Array.prototype.indexOf.call(parent.childNodes, node));
    node = parent;
  }
  if (node !== card) return null;
  return path.reduce(function(current, index) {
    return current && current.childNodes[index];
  }, clone);
}

function listClonedCardFields(card, clone, selector) {
  var fields = cardOwnedNodes(card, selector);
  var selectedValue = fields[0] && normalizeText(
    fields[0].getAttribute("datetime") || fields[0].getAttribute("content") || fields[0].textContent || ""
  );
  return fields.filter(function(field) {
    var value = normalizeText(field.getAttribute("datetime") || field.getAttribute("content") || field.textContent || "");
    return value === selectedValue;
  }).map(function(field) {
    return listClonedCardNode(card, clone, field);
  });
}

function listSupplementalDetail(item, contextValues, card) {
  if (!card || !card.cloneNode) return listDetailWithoutContext(item.detail, contextValues);
  var clone = card.cloneNode(true);
  var contentCard = item.contentCard && listClonedCardNode(card, clone, item.contentCard);
  [
    "[class*='category'], [class*='eyebrow'], [class*='kicker']",
    "[class*='summary'], [class*='description'], [class*='excerpt'], p",
    "[rel='author'], [itemprop='author'], [class*='author' i], [data-author]",
    "time, [datetime], [class*='timestamp' i], [class*='date' i]",
    "[class*='score' i], [data-score], [data-karma]",
    ".reply, .replies, .comment, .comments, [class*='reply'], [class*='replie'], [class*='comment']",
    "[class*='community' i], [class*='subreddit' i], [data-community]",
    "figcaption"
  ].reduce(function(fields, selector) {
    return fields.concat(listClonedCardFields(card, clone, selector));
  }, (item.titleHeadings || []).map(function(heading) {
    return listClonedCardNode(card, clone, heading);
  })).forEach(function(field) {
    if (field && field.remove) field.remove();
  });
  Array.prototype.forEach.call(clone.querySelectorAll("a, h1, h2, h3, h4, [class*='title' i]"), function(node) {
    if (normalizeText(node.textContent || "") === normalizeText(item.text || "")) node.remove();
  });
  clone.querySelectorAll(genericListCardSelector()).forEach(function(nested) {
    if (nested !== contentCard && genericListFieldBoundary(nested)) nested.remove();
  });
  pruneGenericListControls(clone);
  return stripGenericListControlPhrases(clone.textContent || "");
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

function listItemContextValues(item) {
   if (item.groupLabel != null) return item.groupLabel ? [item.groupLabel] : [];
  var card = item.card;
  var rowDetail = card && card.matches && card.matches("tr") ? stripGenericListControlPhrases(item.detail) : "";
  if (rowDetail) {
    if (item.tableReferenceDetail == null) {
      item.tableReferenceDetail = stripGenericListControlPhrases(listTableRowDetail(card, item.text, item.tableCells, { url: item.url }));
    }
    return [item.tableReferenceDetail];
  }

  var contextValues = [
    item.category,
    item.summary,
    cardField(card, "[rel='author'], [itemprop='author'], [class*='author' i], [data-author]") || item.author,
    cardField(card, "time, [datetime], [class*='timestamp' i], [class*='date' i]") || item.time,
    cardField(card, "[class*='score' i], [data-score], [data-karma]") || item.score,
    cardField(card, ".reply, .replies, .comment, .comments, [class~='reply'], [class~='replies'], [class~='comment'], [class~='comments'], [class*='reply'], [class*='replie'], [class*='comment'], [data-reply], [data-replies], [data-comment], [data-comments]") || item.replyCount,
    cardField(card, "[class*='community' i], [class*='subreddit' i], [data-community]") || item.community,
    item.image,
    item.caption
  ];
  var supplementalDetail = listSupplementalDetail(item, contextValues, card);
  if (supplementalDetail) contextValues.push(supplementalDetail);
  return contextValues.filter(Boolean).filter(function(value, index, values) {
    return values.indexOf(value) === index;
  });
}

var listMarkdown = function(items) {
  return items.map(function(item) {
    var line = "- " + markdownLink(item.text, item.url);
    var context = listItemContextValues(item).join(" - ");
    if (context) line += " - " + context;
    return line;
  }).join("\n");
};
