  function focalOwnershipRelatedHeading(value) {
    var text = normalizeText(value || "");
    return (typeof relatedRecordCollectionHeading === "function" && relatedRecordCollectionHeading(text)) ||
      /^(?:related|upcoming|recent)\s+(?:fixtures?|matches|games|events|videos|records)$/i.test(text) ||
      /(?:^|\s)liên\s+quan$/i.test(text);
  }

  function focalOwnershipDetachRelatedCollection(root, marker, slotMarker) {
    if (!root || !marker) return null;
    var collection = Array.prototype.find.call(root.querySelectorAll("[data-fetchutil-page-overview]"), function(node) {
      return node.getAttribute("data-fetchutil-page-overview") === marker;
    });
    if (!collection || !collection.parentNode) return null;
    if (slotMarker) collection.parentNode.insertBefore(document.createComment(slotMarker), collection);
    collection.parentNode.removeChild(collection);
    return collection;
  }

  function focalOwnershipRestoreRelatedCollection(root, collection, sourceCollection, sourceArticle, slotMarker) {
    if (!root || !collection || !sourceCollection || !sourceArticle) return false;
    collection.querySelectorAll("script, style, noscript, template, form, button, input, select, textarea").forEach(function(node) {
      node.remove();
    });
    collection.querySelectorAll("*").forEach(function(node) {
      Array.prototype.slice.call(node.attributes || []).forEach(function(attribute) {
        if (/^on/i.test(attribute.name)) node.removeAttribute(attribute.name);
      });
    });
    materializeHttpAttributes(collection, true);

    var nestedOwner = sourceArticle.contains(sourceCollection) && root.querySelector("article");
    var collectionPrecedesArticle = !!(sourceCollection.compareDocumentPosition(sourceArticle) & Node.DOCUMENT_POSITION_FOLLOWING);
    if (nestedOwner) {
      var iterator = document.createNodeIterator(nestedOwner, NodeFilter.SHOW_COMMENT);
      var slots = [];
      for (var comment = iterator.nextNode(); comment; comment = iterator.nextNode()) {
        if (comment.nodeValue === slotMarker) slots.push(comment);
      }
      if (slots.length !== 1 || !slotMarker) return false;
      slots[0].parentNode.replaceChild(collection, slots[0]);
    } else if (slotMarker) {
      return false;
    } else if (!collectionPrecedesArticle) {
      root.appendChild(collection);
    } else {
      var heading = normalizeText((sourceArticle.querySelector("h1") || {}).textContent || "");
      var outputHeading = Array.prototype.find.call(root.querySelectorAll("h1"), function(node) {
        return normalizeText(node.textContent || "") === heading;
      });
      var outputOwner = outputHeading;
      while (outputOwner && outputOwner.parentNode !== root) outputOwner = outputOwner.parentNode;
      root.insertBefore(collection, outputOwner || root.firstChild);
    }
    collection.removeAttribute("data-fetchutil-page-overview");
    return true;
  }

  function focalOwnershipRelatedCollection(root, articleOwner) {
    if (typeof relatedRecordCollectionHeading !== "function") return null;
    var candidates = new Set();
    Array.prototype.forEach.call(root.querySelectorAll("h2, h3, h4"), function(heading) {
      if (elementVisuallyHidden(heading) || !focalOwnershipRelatedHeading(heading.textContent || "")) return;
      for (var owner = heading.parentElement; owner && owner !== root; owner = owner.parentElement) {
        if (!owner.contains(articleOwner)) candidates.add(owner);
      }
    });

    var valid = Array.from(candidates).filter(function(owner) {
      var headings = Array.prototype.filter.call(owner.querySelectorAll("h2, h3, h4"), function(heading) {
        return !elementVisuallyHidden(heading);
      });
      var labels = headings.filter(function(heading) {
        return focalOwnershipRelatedHeading(heading.textContent || "");
      });
      if (labels.length !== 1) return false;
      var records = headings.filter(function(heading) { return heading !== labels[0]; });
      if (records.length < 3) return false;

      var destinations = new Set();
      var titles = new Set();
      var recordUrls = new Set();
      var qualified = records.every(function(heading) {
        var title = normalizeText(heading.textContent || "");
        var links = Array.prototype.filter.call(heading.querySelectorAll("a[href]"), function(link) {
          return !elementVisuallyHidden(link);
        });
        if (title.length < 8 || titles.has(title) || links.length !== 1 ||
            normalizeText(links[0].textContent || "") !== title) return false;
        var destination = materializedHttpUrl(links[0].getAttribute("href") || "");
        if (!destination || focalCanonicalUrl(destination) === focalCanonicalUrl(location.href)) return false;
        titles.add(title);
        destinations.add(destination);
        recordUrls.add(destination);
        return true;
      });
      if (!qualified) return false;
      var links = Array.prototype.filter.call(owner.querySelectorAll("a[href]"), function(link) {
        return !elementVisuallyHidden(link);
      });
      return links.length >= records.length && links.every(function(link) {
        return recordUrls.has(materializedHttpUrl(link.getAttribute("href") || ""));
      });
    });

    var mostSpecific = valid.filter(function(owner) {
      return !valid.some(function(other) { return other !== owner && owner.contains(other); });
    });
    return mostSpecific.length === 1 ? mostSpecific[0] : null;
  }

  function focalOwnershipEmbeddedRelatedCollection(root, media) {
    var article = media.closest("article");
    if (!article || !root.contains(article)) return null;
    var collections = Array.prototype.filter.call(article.querySelectorAll("[class*='related' i], [class*='recommend' i]"), function(node) {
      if (elementSubtreeHidden(node) || node.contains(media)) return false;
      var list = Array.prototype.filter.call(node.children, function(child) { return child.matches("ul, ol"); });
      var labels = Array.prototype.filter.call(node.children, function(child) {
        return child.matches("p, h2, h3, h4") &&
          (focalOwnershipRelatedHeading(child.textContent || "") || /^view more related$/i.test(normalizeText(child.textContent || "")));
      });
      if (labels.length !== 1 || list.length !== 1 || list[0].children.length < 2) return false;
      return Array.prototype.every.call(list[0].children, function(item) {
        if (!item.matches("li")) return false;
        var links = item.querySelectorAll("a[href]");
        if (links.length !== 1 || !normalizeText(links[0].textContent || "")) return false;
        var url = materializedHttpUrl(links[0].getAttribute("href") || "");
        return !!url && focalCanonicalUrl(url) !== focalCanonicalUrl(location.href);
      });
    });
    return collections.length === 1 ? collections[0] : null;
  }

  function focalOwnershipPageMaterialIsAccountedFor(root, articleOwner, relatedCollection) {
    var materialSelector = "h1, h2, h3, h4, h5, h6, p, li, table, blockquote, figure, a[href], img, picture, video, audio, iframe, object, embed";

    function inspect(node) {
      if (node === articleOwner || (relatedCollection && node === relatedCollection)) return true;
      if (node.nodeType === 3) return !normalizeText(node.nodeValue || "");
      if (node.nodeType !== 1 || elementSubtreeHidden(node)) return true;

      var containsOwnedRoot = node.contains(articleOwner) || (relatedCollection && node.contains(relatedCollection));
      if (containsOwnedRoot) return Array.prototype.every.call(node.childNodes, inspect);

      if (node.matches("header") && normalizeText(node.textContent || "").length >= 80 &&
          node.querySelector("h1, h2, h3, h4, p, blockquote")) return false;
      var signal = normalizeText((node.id || "") + " " + (node.getAttribute("class") || ""));
      if (/(?:^|[\s_-])(?:related|recommend)(?:[\s_-]|$)/i.test(signal)) return false;
      if (sourceOwnershipInChrome(node)) return true;
      var material = node.matches(materialSelector) || node.querySelector(materialSelector);
      return !material && normalizeText(node.textContent || "").length < 40;
    }

    return inspect(root);
  }
