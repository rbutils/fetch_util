function listCompactMetadataForbiddenChild(owner, selector) {
  return Array.from(owner.querySelectorAll(selector)).some(function(node) {
    var inertInteractionIcon = node.matches("i, svg, use, path") &&
      node.matches("[class*='comment' i], [class*='reply' i], [class*='community' i]") &&
      !normalizeText(node.textContent || "") &&
      !node.getAttribute("aria-label") && !node.getAttribute("title") &&
      !node.matches("[role], [tabindex], a[href], button, input, select, textarea");
    return !inertInteractionIcon;
  });
}

function listCompactMetadataHasComplexNodes(owner) {
  var allowedTags = new Set(["DIV", "SPAN", "TIME", "I"]);
  var nodes = [owner].concat(Array.from(owner.querySelectorAll("*")));

  return nodes.some(function(node) {
    if (!allowedTags.has(node.tagName)) return true;
    return node.getAttributeNames().some(function(name) {
      var normalized = String(name || "").toLowerCase();
      return normalized.indexOf("aria-") === 0 || normalized.indexOf("on") === 0;
    });
  });
}

function listCompactMetadataHasDirectText(owner) {
  return Array.from(owner.childNodes || []).some(function(node) {
    return node.nodeType === 3 && !!normalizeText(node.nodeValue || "");
  });
}

function listCompactMetadataBranchNamed(branch) {
  var pattern = /^(category|count|eyebrow|kicker|location|meta(?:data)?|metric|region|score|section(?:[-_]?title)?|stat(?:s|istic)?|tag|topic)$/i;
  var textOwners = [branch].concat(Array.from(branch.querySelectorAll("*"))).filter(function(node) {
    return Array.from(node.childNodes || []).some(function(child) {
      return child.nodeType === Node.TEXT_NODE && normalizeText(child.nodeValue || "");
    });
  });
  if (textOwners.length !== 1) return false;
  var owner = textOwners[0];
  var tokens = Array.from(owner.classList || []);
  ["id", "itemprop", "data-field", "data-type"].forEach(function(attribute) {
    tokens = tokens.concat(String(owner.getAttribute(attribute) || "").split(/\s+/));
  });
  return tokens.some(function(token) { return pattern.test(token); });
}

function listCompactMetadataRow(card, item) {
  if (!card || !card.querySelector || !item) return null;
  var timeSelector = "time, [class~='time'], [class~='timestamp']";
  var timeFields = cardOwnedNodes(card, timeSelector);
  if (timeFields.length !== 1) return null;

  var titles = cardOwnedNodes(card, "h1, h2, h3, h4").filter(function(heading) {
    var text = normalizeText(heading.textContent || "");
    return text && [item.text, item.displayText].map(normalizeText).indexOf(text) !== -1;
  });
  if (titles.length !== 1) return null;

  var title = titles[0];
  var owner = timeFields[0].parentElement;
  var forbidden = "a[href], h1, h2, h3, h4, p, blockquote, ul, ol, dl, table, figure, img, picture, " +
    "video, audio, iframe, section, article, details, summary, label, fieldset, output, progress, meter, " +
    "form, input, button, select, textarea, [contenteditable], [role], [tabindex], [aria-label], " +
    "[aria-labelledby], [aria-describedby], [aria-controls], [aria-expanded], [aria-live], " +
    "[aria-current], [aria-selected], [aria-pressed], " +
    "[rel~='author'], [itemprop~='author'], [class*='author' i], [class*='byline' i], " +
    "[class*='comment' i], [class*='reply' i], [class*='community' i]";

  while (owner && owner !== card) {
    var followsOwner = owner.compareDocumentPosition(title) & Node.DOCUMENT_POSITION_FOLLOWING;
    if (owner.parentElement === title.parentElement && owner.nextElementSibling === title && followsOwner &&
        !listCardNodeHidden(owner) && !listCompactMetadataHasComplexNodes(owner) &&
        !listCompactMetadataHasDirectText(owner) && !owner.matches(forbidden) &&
        !listCompactMetadataForbiddenChild(owner, forbidden)) {
      var branches = Array.prototype.filter.call(owner.children, function(child) {
        return !listCardNodeHidden(child) && normalizeText(child.textContent || "");
      });
      var parts = branches.map(function(child) { return normalizeText(child.textContent || ""); });
      var timeBranches = branches.filter(function(child) {
        return child === timeFields[0] || child.contains(timeFields[0]);
      });
      var namedBranches = branches.filter(function(child) {
        return timeBranches.indexOf(child) !== -1 || listCompactMetadataBranchNamed(child);
      });
      var hasCustomElement = Array.prototype.some.call([owner].concat(Array.from(owner.querySelectorAll("*"))), function(node) {
        return node.tagName && node.tagName.indexOf("-") !== -1;
      });
      var text = normalizeText(owner.textContent || "");
      if (branches.length >= 2 && branches.length <= 5 && namedBranches.length === branches.length &&
          timeBranches.length === 1 &&
          parts.every(function(part) { return part.length <= 80; }) &&
          new Set(parts).size === parts.length && text.length <= 160 && !hasCustomElement) {
        return { node: owner, text: text, parts: parts };
      }
    }
    if (owner.contains(title)) break;
    owner = owner.parentElement;
  }
  return null;
}

function listCompactMetadataRepresents(metadata, value) {
  value = normalizeText(value || "");
  return !!(metadata && value && metadata.parts.indexOf(value) !== -1);
}

function listCompactMetadataContains(metadata, node) {
  return !!(metadata && node && metadata.node.contains(node));
}

function cardField(card, selector, primaryUrl, allowReference, fieldFilter) {
  if (!card || !card.querySelector) return "";
  var nodes = cardOwnedNodes(card, selector);
  var node = fieldFilter ? nodes.filter(fieldFilter)[0] : nodes[0];
  if (!node) return "";
  var nodeUrl = node.matches && node.matches("a[href]") && materializedHttpUrl(node.getAttribute("href"));
  if (nodeUrl && primaryUrl && listCanonicalKey(nodeUrl) === listCanonicalKey(primaryUrl)) {
    return normalizeText(node.textContent || node.getAttribute("aria-label") || "");
  }
  var value = node.hasAttribute("datetime") || node.hasAttribute("content") ?
    normalizeText(node.getAttribute("datetime") || node.getAttribute("content") || "") :
    (allowReference === false ? normalizeText(node.textContent) : listTextWithReferences(node));
  if (!value) return "";
  if (/^(comment|comments|reply|replies|score|points|likes?)$/i.test(value)) return "";
  return value;
}

function listCompactMetadataFollowingField(card, metadata, selector, value) {
  value = normalizeText(value || "");
  if (!card || !metadata || !value) return null;
  var fields = cardOwnedNodes(card, selector).filter(function(node) {
    return !listCardNodeHidden(node) && normalizeText(node.textContent || "") === value;
  });
  if (fields.length !== 1) return null;
  var field = fields[0];
  return metadata.node.compareDocumentPosition(field) & Node.DOCUMENT_POSITION_FOLLOWING ? field : null;
}
