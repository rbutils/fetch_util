function sourceOwnedPrimaryReviewCollectionLink(node, productId) {
  return Array.prototype.some.call(node.querySelectorAll("a[href]"), function(link) {
    if (elementSubtreeHidden(link) || link.closest("blockquote, q, form, aside, nav, footer, [role='complementary'], [role='navigation']") ||
        link.closest("[data-hook='review'], [data-review-id], [itemprop='review'], [itemtype*='schema.org/Review'], .review")) return false;
    var href = materializedHttpUrl(link.getAttribute("href"));
    if (!href) return false;
    var url = new URL(href);
    if (url.origin !== location.origin) return false;
    var segments = url.pathname.split("/").filter(Boolean).map(function(segment) {
      return safeDecodeURI(segment).toLowerCase();
    });
    return segments.some(function(segment, index) {
      return segment === productId && index > 0 && /(?:^|[-_])reviews?(?:$|[-_])/.test(segments[index - 1]);
    });
  });
}

function sourceOwnedPrimaryReviewRecords(root) {
  return Array.prototype.filter.call(root.querySelectorAll(
    "[data-hook='review'], [data-review-id], [itemprop='review'], [itemtype*='schema.org/Review'], .review"
  ), function(node) {
    return !elementSubtreeHidden(node) &&
      !node.closest("aside, nav, footer, [role='complementary'], [role='navigation']") &&
      !Array.prototype.some.call(node.querySelectorAll("[data-hook='review'], [data-review-id], [itemprop='review'], [itemtype*='schema.org/Review'], .review"), function(child) {
        return child !== node && !elementSubtreeHidden(child);
      });
  });
}

function sourceOwnedPrimaryServiceReviews(serviceOwner) {
  var productId;
  try {
    productId = safeDecodeURI(new URL(location.href).pathname.split("/").filter(Boolean).pop()).toLowerCase();
  } catch (_error) { return null; }
  if (!/^[\p{L}\p{N}_-]+$/u.test(productId)) return null;

  var candidates = Array.prototype.filter.call(document.querySelectorAll("[id*='review' i], [class*='review' i]"), function(node) {
    if (elementSubtreeHidden(node) || sourceOwnershipInChrome(node) ||
        node.closest("aside, nav, footer, [role='complementary'], [role='navigation']") ||
        node === serviceOwner.node || serviceOwner.node.contains(node) || node.contains(serviceOwner.node) ||
        !(serviceOwner.node.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
    var records = sourceOwnedPrimaryReviewRecords(node);
    if (!records.length) return false;
    return records.every(function(record) {
      return normalizeText((visibilityPrunedClone(record, document) || {}).textContent || "") &&
        !record.querySelector("article, [role='article'], form");
    });
  });
  candidates = candidates.filter(function(node) {
    return !candidates.some(function(ancestor) { return ancestor !== node && ancestor.contains(node); });
  });
  if (!candidates.length) return null;
  if (candidates.length !== 1) return false;
  var reviews = candidates[0];
  var records = sourceOwnedPrimaryReviewRecords(reviews);
  if (Array.prototype.some.call(reviews.querySelectorAll("article, [role='article']"), function(article) {
    return !elementSubtreeHidden(article) && (!records.includes(article) ||
      !article.matches("[data-hook='review'], [data-review-id], [itemprop='review'], [itemtype*='schema.org/Review']") ||
      ![article.getAttribute("data-product-id"), article.getAttribute("data-asin")].some(function(id) {
        return id && id.toLowerCase() === productId;
      }));
  })) return false;
  if (!sourceOwnedPrimaryReviewCollectionLink(serviceOwner.node, productId) ||
      !sourceOwnedPrimaryReviewCollectionLink(reviews, productId)) return false;
  if (Array.prototype.some.call([reviews].concat(Array.prototype.slice.call(reviews.querySelectorAll("[data-product-id], [data-asin]"))), function(node) {
    if (elementSubtreeHidden(node)) return false;
    return [node.getAttribute("data-product-id"), node.getAttribute("data-asin")].some(function(identity) {
      return identity && identity.toLowerCase() !== productId;
    });
  })) return false;
  if (Array.prototype.some.call(reviews.querySelectorAll("aside, nav, footer, [role='complementary'], [role='navigation']"), function(node) {
    return !elementSubtreeHidden(node) && normalizeText((visibilityPrunedClone(node, document) || {}).textContent || "");
  })) return false;
  var common = serviceOwner.node.parentElement;
  while (common && !common.contains(reviews)) common = common.parentElement;
  if (!common || common.matches("html, body") || sourceOwnershipInChrome(common)) return false;

  // An independent article in the shared scope defeats the product association.
  if (Array.prototype.some.call(common.querySelectorAll("article, [role='article']"), function(article) {
    return !serviceOwner.node.contains(article) && !reviews.contains(article) &&
      !elementSubtreeHidden(article) && !sourceOwnershipInChrome(article);
  })) return false;
  var clone = visibilityPrunedClone(reviews, document);
  if (!clone) return false;
  Array.prototype.forEach.call(clone.querySelectorAll("button"), function(button) {
    if (!button.querySelector("img[src]") || button.querySelector("input, select, textarea, form")) return;
    var figure = document.createElement("figure");
    while (button.firstChild) figure.appendChild(button.firstChild);
    button.parentNode.replaceChild(figure, button);
  });
  return clone;
}
