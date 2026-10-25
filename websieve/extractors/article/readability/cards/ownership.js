  function readabilityCardSelectionExcluded() {
    return "nav, aside, footer, form, button, pre, code, kbd, samp, details:not([open]), " +
      "[role='navigation'], [role='complementary'], [role='dialog'], [role='menu'], " +
      "[role='toolbar'], [role='button']";
  }

  function readabilityCardTitle(link, sourceClones) {
    if (link.closest(readabilityCardSelectionExcluded()) || elementSubtreeHidden(link) ||
        link.querySelector("img, picture, svg, video, audio, iframe, object, embed")) return null;
    var fields = Array.from(link.querySelectorAll("h2, h3, h4, h5, h6, p"));
    if (fields.length !== 1 || fields[0].closest("a") !== link || elementSubtreeHidden(fields[0])) return null;
    var text = normalizeText(fields[0].textContent);
    var clone = sourceClones.get(fields[0]);
    if (!text || normalizeText(link.textContent) !== text || !clone || normalizeText(clone.textContent) !== text) return null;
    var destination = materializedHttpUrl(link.getAttribute("href"));
    var mappedLink = sourceClones.get(link);
    return destination && mappedLink && mappedLink.contains(clone) &&
      materializedHttpUrl(mappedLink.getAttribute("href")) === destination ?
      { node: link, field: fields[0], destination: destination } : null;
  }

  function readabilityCardImageLink(link, destination, sourceClones) {
    if (materializedHttpUrl(link.getAttribute("href")) !== destination || normalizeText(link.textContent) ||
        link.closest(readabilityCardSelectionExcluded()) || elementSubtreeHidden(link)) return false;
    var images = Array.from(link.querySelectorAll("img[src]"));
    if (images.length !== 1 || link.querySelector("video, audio, iframe, object, embed, input, button")) return false;
    var image = images[0];
    var mappedLink = sourceClones.get(link);
    var mappedImage = sourceClones.get(image);
    var source = materializedHttpUrl(image.getAttribute("src"));
    return !!source && !elementSubtreeHidden(image) && mappedLink && mappedImage && mappedLink.contains(mappedImage) &&
      materializedHttpUrl(mappedLink.getAttribute("href")) === destination &&
      materializedHttpUrl(mappedImage.getAttribute("src")) === source;
  }

  function readabilityCardRecord(title, article, titleCounts, sourceClones) {
    for (var owner = title.node.parentElement; owner && owner !== article; owner = owner.parentElement) {
      if (titleCounts.get(owner) !== 1 || owner.closest(readabilityCardSelectionExcluded())) return null;
      if (!/^(div|section|li)$/.test(owner.localName)) continue;
      var clone = sourceClones.get(owner);
      if (!clone || elementSubtreeHidden(owner)) return null;
      var images = Array.from(owner.querySelectorAll("a[href]")).filter(function(link) {
        return link !== title.node && readabilityCardImageLink(link, title.destination, sourceClones);
      });
      if (!images.length) continue;
      if (images.length !== 1 || !clone.contains(sourceClones.get(images[0])) ||
          !clone.contains(sourceClones.get(title.node))) return null;
      var prose = Array.from(owner.querySelectorAll("p")).filter(function(paragraph) {
        var mapped = sourceClones.get(paragraph);
        return !title.node.contains(paragraph) && !images[0].contains(paragraph) &&
          !paragraph.closest(readabilityCardSelectionExcluded()) && !elementSubtreeHidden(paragraph) &&
          mapped && clone.contains(mapped) && !!normalizeText(paragraph.textContent) &&
          normalizeText(mapped.textContent) === normalizeText(paragraph.textContent);
      });
      return prose.length ? { source: owner, clone: clone, prose: prose } : null;
    }
    return null;
  }

  function readabilityOwnedCardCohorts(ownership, root, sourceClones, sourceIdentities) {
    if (!ownership || ownership.titleIdentityProven !== true) return null;
    var article = ownership.node;
    var heading = ownership.heading;
    var mappedArticle = article && sourceClones.get(article);
    var mappedHeading = heading && sourceClones.get(heading);
    var identity = heading && sourceIdentities.get(heading);
    if (!article || article.localName !== "article" || article.closest(readabilityCardSelectionExcluded()) ||
        !mappedArticle || !root.contains(mappedArticle) || !heading || heading.localName !== "h1" ||
        !article.contains(heading) || !mappedHeading || !mappedArticle.contains(mappedHeading) ||
        !identity || !identity.unique || elementSubtreeHidden(article)) return null;

    var titles = Array.from(article.querySelectorAll("a[href]")).map(function(link) {
      return readabilityCardTitle(link, sourceClones);
    }).filter(Boolean);
    if (titles.length < 2) return null;
    var titleCounts = new WeakMap();
    titles.forEach(function(title) {
      for (var parent = title.node.parentElement; parent && parent !== article; parent = parent.parentElement) {
        titleCounts.set(parent, (titleCounts.get(parent) || 0) + 1);
      }
    });
    var groups = new Map();
    titles.forEach(function(title) {
      var record = readabilityCardRecord(title, article, titleCounts, sourceClones);
      if (!record || record.source.parentElement === article) return;
      var parent = record.source.parentElement;
      if (!groups.has(parent)) groups.set(parent, []);
      groups.get(parent).push(record);
    });
    var cohorts = [];
    groups.forEach(function(records, parent) {
      var mapped = sourceClones.get(parent);
      var members = new Set(records.map(function(record) { return record.source; }));
      if (records.length < 2 || members.size !== records.length || !mapped || !mappedArticle.contains(mapped) ||
          !(heading.compareDocumentPosition(parent) & Node.DOCUMENT_POSITION_FOLLOWING)) return;
      var children = Array.from(parent.children).filter(function(child) { return !elementSubtreeHidden(child); });
      if (children.length !== records.length || !children.every(function(child) { return members.has(child); })) return;
      if (!records.every(function(record) { return record.clone.parentElement === mapped; })) return;
      cohorts.push({ source: parent, clone: mapped, records: records });
    });
    return cohorts.length ? { source: article, root: mappedArticle, heading: mappedHeading, cohorts: cohorts } : null;
  }
