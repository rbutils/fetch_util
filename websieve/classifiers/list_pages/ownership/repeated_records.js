  function repeatedRecordAssessmentForContent(content, selectedFocalArticleOwner) {
    if (!content || content.hostAware || content.docsLike) return null;
    var computedFocalArticleOwner = articleRouteFocalContent(content, true);
    var focalArticleOwner = computedFocalArticleOwner || selectedFocalArticleOwner;
    var collection = repeatedRecordCollectionPage(focalArticleOwner, content);
    if (collection && collection.articleOwnershipConflict) content.repeatedRecordArticleOwnershipConflict = true;
    return collection;
  }

  function repeatedRecordCollectionPage(focalArticleOwner, content) {
    if (!document.body) return null;

    var visibleMainRegions = Array.prototype.filter.call(document.querySelectorAll("main, [role='main']"), function(main) {
      return !elementSubtreeHidden(main) && !listChromeNode(main);
    });
    var primaryMain = visibleMainRegions.length === 1 ? visibleMainRegions[0] : null;
    var proseScope = primaryMain || document.body;
    var candidateOwners = new Set();
    Array.prototype.forEach.call(document.querySelectorAll("a[href]"), function(link) {
      var owner = link.parentElement;
      while (owner && !owner.matches("body, html")) {
        if (!primaryMain || primaryMain.contains(owner)) candidateOwners.add(owner);
        if (primaryMain ? owner === primaryMain : owner.matches("main, [role='main']")) break;
        owner = owner.parentElement;
      }
    });

    var visibleParagraphs = Array.prototype.map.call(proseScope.querySelectorAll("p"), function(paragraph) {
      if (elementSubtreeHidden(paragraph) || listChromeNode(paragraph) ||
          paragraph.closest("nav, header, footer, aside, [role='navigation'], [role='complementary']")) return null;
      var text = normalizeText(paragraph.textContent || "");
      if (text.length < 80) return null;
      var ancestors = new Set();
      var ancestor = paragraph;
      while (ancestor) {
        ancestors.add(ancestor);
        ancestor = ancestor.parentElement;
      }
      return { node: paragraph, text: text, ancestors: ancestors };
    }).filter(Boolean);

    var paragraphGroups = new Map();
    visibleParagraphs.forEach(function(paragraph) {
      var group = paragraphGroups.get(paragraph.text);
      if (group) group.push(paragraph);
      else paragraphGroups.set(paragraph.text, [paragraph]);
    });
    var proseWithinOwner = new Map();
    var proseEvidenceTexts = new Set();
    var proseCharacters = 0;
    paragraphGroups.forEach(function(group, text) {
      proseEvidenceTexts.add(text);
      proseCharacters += text.length;
      var commonAncestor = group[0].node;
      while (commonAncestor && !group.every(function(paragraph) {
        return paragraph.ancestors.has(commonAncestor);
      })) commonAncestor = commonAncestor.parentElement;
      while (commonAncestor) {
        var texts = proseWithinOwner.get(commonAncestor);
        if (!texts) {
          texts = new Set();
          proseWithinOwner.set(commonAncestor, texts);
        }
        texts.add(text);
        commonAncestor = commonAncestor.parentElement;
      }
    });

    function unlinkedContextSection(node) {
      return node.matches("section, div") && !node.querySelector("a[href], ul, ol, [role='list']") &&
        !!node.querySelector("h1, h2, h3, h4") && !!node.querySelector("p");
    }

    function linklessText(node) {
      var clone = node.cloneNode(true);
      Array.prototype.forEach.call(clone.querySelectorAll("a, script, style, template"), function(link) {
        link.remove();
      });
      Array.prototype.forEach.call(clone.querySelectorAll("[hidden], [aria-hidden='true']"), function(hidden) {
        hidden.remove();
      });
      return normalizeText(clone.textContent || "");
    }

    function visibleRecord(node) {
      if (elementSubtreeHidden(node) || listChromeNode(node) || listExplicitAdvertisementOwner(node)) return null;
      var destinations = new Set();
      var primaryLinks = [];
      Array.prototype.forEach.call(node.querySelectorAll("a[href]"), function(link) {
        if (elementSubtreeHidden(link)) return;
        var url = materializedHttpUrl(link.getAttribute("href"));
        if (!url) return;
        var key = listCanonicalKey(url);
        destinations.add(key);
        var title = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
        if (title.length >= 4 && !genericListControlText(title) && !looksLikeFooterLink(title, url)) {
          primaryLinks.push({ key: key, url: url, title: title });
        }
      });
      if (destinations.size !== 1 || primaryLinks.length === 0) return null;

      var titleLink = primaryLinks.find(function(link) {
        return link.key === primaryLinks[0].key;
      });
      if (!titleLink) return null;
      var recordClass = Array.prototype.some.call(node.classList || [], function(name) {
        return /(?:^|[-_])(?:card|item|story|teaser|news|headline|result)(?:$|[-_])/i.test(name);
      });
      if (!node.matches("article, li") && !recordClass && !node.querySelector("img[src], h1, h2, h3, h4, p, time, [datetime]")) return null;

      var title = titleLink.title;
      return {
        node: node,
        destination: titleLink.key,
        title: title,
        identity: titleLink.key + "|" + title.toLowerCase(),
        mediaMarkdown: Array.prototype.reduce.call(node.querySelectorAll("a[href] img[src]"), function(media, image) {
          if (elementSubtreeHidden(image)) return media;
          var imageLink = image.closest("a[href]");
          var imageDestination = materializedHttpUrl(imageLink && imageLink.getAttribute("href"));
          var imageUrl = materializedHttpUrl(image.getAttribute("src"));
          var alt = normalizeText(image.getAttribute("alt") || "");
          if (!imageUrl || !imageDestination || listCanonicalKey(imageDestination) !== titleLink.key ||
              image.matches("[role='presentation'], [role='none'], [aria-hidden='true']")) return media;
          var imageAlt = alt || titleLink.title;
          if (alt && alt.toLowerCase() !== titleLink.title.toLowerCase() &&
              titleLink.title.toLowerCase().indexOf(alt.toLowerCase()) === -1) imageAlt += " " + titleLink.title;
          var escapedAlt = imageAlt.replace(/\\/g, "\\\\").replace(/([\[\]])/g, "\\$1");
          media.push("[![" + escapedAlt + "](" + imageUrl + ")](" + imageDestination + ")");
          return media;
        }, [])
      };
    }

    function substantialProseOutside(owner) {
      var inside = proseWithinOwner.get(owner) || new Set();
      var count = proseEvidenceTexts.size - inside.size;
      var characters = proseCharacters;
      inside.forEach(function(text) { characters -= text.length; });
      return count >= 3 && characters >= 600;
    }

    function substantialProseWithin(owner) {
      var texts = proseWithinOwner.get(owner) || new Set();
      var characters = 0;
      texts.forEach(function(text) { characters += text.length; });
      return texts.size >= 3 && characters >= 600;
    }

    // Only a live Article owner returned after the route predicate passed blocks a separate collection.
    // A page-level introduction or neighboring record is not focal ownership evidence.
    function focalArticleOutsideCollection(owner) {
      return !!focalArticleOwner && !owner.contains(focalArticleOwner);
    }

    var owners = [];
    candidateOwners.forEach(function(owner) {
      if (primaryMain && !primaryMain.contains(owner)) return;
      if (owner.matches("body, html, article, nav, header, footer, aside, [role='navigation'], [role='complementary']") ||
          owner.closest("nav, header, footer, aside, [role='navigation'], [role='complementary']") ||
          elementSubtreeHidden(owner) || listChromeNode(owner) || listNoiseNode(owner)) return;
      var children = Array.prototype.filter.call(owner.children, function(child) {
        return !child.matches("script, style, template") && !elementSubtreeHidden(child);
      });
      var records = [];
      var nonRecordChildren = [];
      children.forEach(function(child) {
        var record = visibleRecord(child);
        if (record) records.push(record);
        else nonRecordChildren.push(child);
      });
      var leadingHeading = nonRecordChildren.length === 1 && children[0] === nonRecordChildren[0] &&
        nonRecordChildren[0].matches("h1, h2, h3, h4") && !nonRecordChildren[0].querySelector("a[href]");
      if (records.length < 4 || (nonRecordChildren.length > 0 && !leadingHeading)) return;

      var identities = new Set();
      var uniqueRecords = records.every(function(record) {
        if (identities.has(record.destination)) return false;
        identities.add(record.destination);
        return true;
      });
      owners.push({
        owner: owner,
        records: records,
        primaryMain: primaryMain,
        articleOwnershipConflict: !uniqueRecords || substantialProseOutside(owner) || focalArticleOutsideCollection(owner)
      });
    });

    var mostSpecificOwners = owners.filter(function(candidate) {
      return !owners.some(function(other) {
        return other !== candidate && candidate.owner.contains(other.owner) && other.records.length >= candidate.records.length;
      });
    });
    if (mostSpecificOwners.length !== 1) return null;

    var collection = mostSpecificOwners[0];
    if (collection.articleOwnershipConflict) return collection;
    if (!primaryMain) {
      var renderContext = pageOwnedRenderContext(collection.owner, content);
      collection.renderNodes = renderContext ? renderContext.nodes : [collection.owner];
      collection.contextNodes = collection.renderNodes.filter(function(node) { return node !== collection.owner; });
      collection.renderOwner = renderContext ? renderContext.owner : collection.owner;
      return collection;
    }
    var renderOwner = collection.owner;
    function unlinkedEditorialContext(node) {
      if (node.matches("header, footer, nav, menu, [role='navigation'], [role='banner'], [role='contentinfo']")) return true;
      if (node.matches("h1, h2, h3, h4") && !node.querySelector("a[href]")) return true;
      if (node.matches("p") && !substantialProseWithin(node)) return true;
      return unlinkedContextSection(node) && !substantialProseWithin(node);
    }
    while (!renderOwner.matches("body, html, main, [role='main']")) {
      var parent = renderOwner.parentElement;
      if (!parent || parent.matches("html")) break;
      var contextSiblings = Array.prototype.filter.call(parent.children, function(child) {
        return child !== renderOwner && !elementSubtreeHidden(child);
      });
      if (!contextSiblings.every(unlinkedEditorialContext)) break;
      renderOwner = parent;
      if (parent.matches("main, [role='main']")) break;
    }
    collection.renderOwner = renderOwner;
    return collection;
  }

  function repeatedRecordCandidateCoversOwner(candidate, collection) {
    var items = candidate && candidate.listExtraction && candidate.listExtraction.items;
    var extraction = candidate && candidate.listExtraction;
    var mappedOwner = extraction && extraction.collectionOwnerMapped &&
      extraction.collectionOwnerSourceNode === collection.owner && extraction.renderOwnerSourceNode === collection.renderOwner;
    var mappedMain = collection && collection.primaryMain && extraction && extraction.primaryMainMapped &&
      extraction.primaryMainSourceNode === collection.primaryMain;
    if (!items || !collection || !collection.records.length || !collection.owner || !collection.renderOwner ||
        !mappedOwner || (collection.primaryMain ? !mappedMain : extraction.primaryMainMapped)) return false;
    var matched = new Set();
    return collection.records.every(function(record) {
      var itemIndex = items.findIndex(function(item, index) {
        if (matched.has(index) || listCanonicalKey(materializedHttpUrl(item.url) || "") !== record.destination) return false;
        return normalizeText(item.text || "").toLowerCase().indexOf(record.title.toLowerCase()) !== -1;
      });
      if (itemIndex < 0) return false;
      matched.add(itemIndex);
      return true;
    });
  }

  // These route-local source proofs do not alter the live DOM or persist across extraction.
