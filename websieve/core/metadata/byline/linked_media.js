function bylineMediaPublicationTitleKey(value) {
  var words = normalizeText(value || "").normalize("NFKC").toLowerCase().match(/[\p{L}\p{N}]+/gu);
  return words ? words.join("-") : "";
}

function bylineMediaPublicationRecord(node) {
  var cover = node && node.parentElement;
  if (!cover || cover.matches("html, body, main, [role='main']") ||
      cover.closest("nav, aside, footer, pre, code, kbd, samp, button, [role='button']")) return null;
  var links = Array.from(cover.children).filter(function(link) {
    if (!link.matches("a[href]") || link.hasAttribute("download") || link.children.length !== 1 ||
        !link.firstElementChild.matches("img") || normalizeText(link.textContent || "")) return false;
    return bylineForeignPublicationLink(link) && !elementVisuallyHidden(link.firstElementChild);
  });
  if (links.length !== 1) return null;
  var destination = new URL(materializedHttpUrl(links[0].getAttribute("href")));
  if (/\.(?:avif|gif|jpe?g|png|svg|webp|bmp|ico|tiff?)$/i.test(destination.pathname)) return null;
  var current = [location.href, materializedCanonicalUrl()].filter(Boolean).some(function(value) {
    var href = materializedHttpUrl(value);
    if (!href) return false;
    var page = new URL(href);
    return page.origin === destination.origin &&
      page.pathname.replace(/\/+$/, "") === destination.pathname.replace(/\/+$/, "");
  });
  if (current) return null;
  var segment;
  try {
    segment = decodeURIComponent(destination.pathname.split("/").filter(Boolean).pop() || "");
  } catch (_) {
    return null;
  }
  var destinationKey = bylineMediaPublicationTitleKey(segment);
  if (!destinationKey) return null;
  var owner = cover.parentElement;
  while (owner && !owner.matches("html, body, main, [role='main']")) {
    if (bylineLinkedTitleFields(owner, node).length) {
      var title = bylineUnlinkedPrincipalTitle(owner, node);
      if (!title || bylineOutsideTitleRecord(title, node, owner)) return null;
      return { owner: owner, cover: cover, credit: node, link: links[0], title: title,
        titleKey: bylineMediaPublicationTitleKey(title.textContent), destination: destination,
        destinationKey: destinationKey };
    }
    owner = owner.parentElement;
  }
  return null;
}

function bylineMediaPublicationPageTitle(record, partial) {
  var titles = [document.title, metadataValue("og:title", "property"), metadataValue("twitter:title", "name")];
  var declared = titles.some(function(value) {
    if (partial) {
      var key = bylineMediaPublicationTitleKey(value);
      return key && ("-" + key + "-").indexOf("-" + record.titleKey + "-") !== -1;
    }
    return String(value || "").split(/\s+[|\-–—]\s+/).some(function(part) {
      return bylineMediaPublicationTitleKey(part) === record.titleKey;
    });
  });
  if (declared) return true;
  return Array.from(record.cover.getRootNode().querySelectorAll("h1")).some(function(heading) {
    return !record.owner.contains(heading) && !elementVisuallyHidden(heading) &&
      bylineMediaPublicationTitleKey(heading.textContent) === record.titleKey;
  });
}

function bylineMediaPublicationFieldPath(node, owner) {
  var parts = [];
  while (node && node !== owner) {
    var parent = node.parentElement;
    if (!parent) return null;
    parts.unshift(node.tagName + ":" + Array.from(parent.children).indexOf(node));
    node = parent;
  }
  return node === owner ? parts.join("/") : null;
}

function bylineMediaPublicationShape(record) {
  return JSON.stringify([record.owner.tagName,
    bylineMediaPublicationFieldPath(record.cover, record.owner),
    bylineMediaPublicationFieldPath(record.credit, record.owner),
    bylineMediaPublicationFieldPath(record.link, record.owner),
    bylineMediaPublicationFieldPath(record.title, record.owner)]);
}

function bylineMediaPublicationCollection(record) {
  var path = record.destination.pathname.replace(/\/+$/, "");
  return record.destination.origin + path.replace(/\/[^/]*$/, "/");
}

function bylineRepeatedMediaPublicationOwner(record) {
  if (record.credit.closest("article, [role='article'], [itemprop~='articleBody']") ||
      bylineMediaPublicationPageTitle(record, false)) return null;
  var shape = bylineMediaPublicationShape(record);
  var collection = bylineMediaPublicationCollection(record);
  var position = Array.from(record.cover.children).indexOf(record.credit);
  var images = record.cover.getRootNode().querySelectorAll("a[href] > img");
  var matched = Array.from(images).some(function(image) {
    var cover = image.parentElement.parentElement;
    if (cover === record.cover) return false;
    var credit = cover.children[position];
    if (!credit || credit.tagName !== record.credit.tagName || elementVisuallyHidden(credit)) return false;
    var peer = bylineMediaPublicationRecord(credit);
    return peer && peer.titleKey === peer.destinationKey && !bylineMediaPublicationPageTitle(peer, true) &&
      bylineMediaPublicationCollection(peer) === collection && bylineMediaPublicationShape(peer) === shape;
  });
  return matched ? record.owner : null;
}

function bylineLinkedMediaPublicationOwner(node) {
  var record = bylineMediaPublicationRecord(node);
  if (!record) return null;
  if (record.titleKey === record.destinationKey && !bylineMediaPublicationPageTitle(record, true)) return record.owner;
  return bylineRepeatedMediaPublicationOwner(record);
}
