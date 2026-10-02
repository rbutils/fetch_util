  function sourceOwnedResultCountLabel(node) {
    if (!node || !node.matches("p") || elementSubtreeHidden(node) ||
        node.closest("nav, header, footer, aside, [role='navigation'], [role='complementary']")) return false;
    return /^\d[\d,]*\s+(?:matches|results?)\b/i.test(normalizeText(node.textContent || ""));
  }

  function sourceOwnedMoreResultAction(node, records, owner, scope) {
    if (!node || elementSubtreeHidden(node) || !scope.contains(node) ||
        node.closest("nav, header, footer, aside, [role='navigation'], [role='complementary']")) return false;
    var text = normalizeText([node.textContent || "", node.getAttribute("aria-label") || "",
      node.getAttribute("title") || ""].join(" "));
    if (!/\d[\d,]*/.test(text) || !/\b(?:more|load|additional|next)\b/i.test(text)) return false;
    if (!owner || !scope.contains(owner) || node.closest("article, [role~='article' i]")) return false;
    return records.every(function(record) {
      return record.node && (record.node.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
  }

  function sourceOwnedResultCountNodes(owner, records) {
    if (!owner || !records || !records.length) return [];
    var recordNodes = records.map(function(record) { return record.node; });
    if (recordNodes.some(function(node, index) {
      return !node || !owner.contains(node) || elementSubtreeHidden(node) || recordNodes.indexOf(node) !== index;
    })) return [];

    var ancestor = owner;
    while (ancestor && !ancestor.matches("body, html")) {
      if (ancestor.closest("nav, header, footer, aside, [role='navigation'], [role='complementary']")) break;
      if (ancestor.querySelector("article, [role~='article' i]") &&
          Array.prototype.some.call(ancestor.querySelectorAll("article, [role~='article' i]"), function(article) {
             return !owner.contains(article);
          })) break;
      var forms = Array.prototype.filter.call(ancestor.querySelectorAll("form"), function(form) {
        if (elementSubtreeHidden(form) || form.closest("nav, header, footer, aside, [role='navigation'], [role='complementary']")) return false;
        var identity = [form.id || "", form.className || "", form.getAttribute("role") || "",
          form.getAttribute("aria-label") || "", form.getAttribute("action") || ""].join(" ");
        return /search/i.test(identity) || !!form.querySelector("input[type='search'], [role='searchbox']");
      });
      if (forms.length === 1) {
        var form = forms[0];
        var formParent = form.parentElement;
        var counts = formParent ? Array.prototype.filter.call(formParent.children, sourceOwnedResultCountLabel) : [];
        var actionCandidates = Array.prototype.filter.call(ancestor.querySelectorAll("button, [role~='button' i]"), function(node) {
          return sourceOwnedMoreResultAction(node, records, owner, ancestor);
        });
        actionCandidates = actionCandidates.filter(function(node) {
          return !actionCandidates.some(function(other) {
            return other !== node && other.contains(node) &&
              normalizeText(other.textContent || "") === normalizeText(node.textContent || "");
          });
        });
        var recordBranch = owner;
        while (recordBranch.parentElement && recordBranch.parentElement !== ancestor) recordBranch = recordBranch.parentElement;
        var searchBranch = form;
        while (searchBranch.parentElement && searchBranch.parentElement !== ancestor) searchBranch = searchBranch.parentElement;
        var actionBranch = actionCandidates[0];
        while (actionBranch && actionBranch.parentElement && actionBranch.parentElement !== ancestor) {
          actionBranch = actionBranch.parentElement;
        }
        var intervening = [];
        for (var sibling = recordBranch.nextElementSibling; sibling && sibling !== actionBranch;
             sibling = sibling.nextElementSibling) intervening.push(sibling);
        var adjacentAction = actionBranch &&
          (recordBranch.compareDocumentPosition(actionBranch) & Node.DOCUMENT_POSITION_FOLLOWING) &&
          intervening.every(function(sibling) {
            return sibling.matches("p") && !sibling.querySelector("a, button, form, article, section");
          });
        if (counts.length === 1 && actionCandidates.length === 1 &&
            searchBranch !== recordBranch && (actionBranch === recordBranch || adjacentAction) &&
            (form.compareDocumentPosition(counts[0]) & Node.DOCUMENT_POSITION_FOLLOWING) &&
            (form.compareDocumentPosition(recordNodes[0]) & Node.DOCUMENT_POSITION_FOLLOWING) &&
            (counts[0].compareDocumentPosition(recordNodes[0]) & Node.DOCUMENT_POSITION_FOLLOWING)) {
          return [
            { kind: "match-count", sourceNode: counts[0] },
            { kind: "more-found", sourceNode: actionCandidates[0] }
          ];
        }
      }
      ancestor = ancestor.parentElement;
    }
    return [];
  }

  function sourceOwnedRecordMediaForItems(collection, extraction) {
    if (!collection || !extraction || !extraction.collectionOwnerMapped ||
        extraction.collectionOwnerSourceNode !== collection.owner) return;
    var items = extraction.items || [];
    var used = new Set();
    collection.records.forEach(function(record) {
      if (!record.mediaMarkdown || !record.mediaMarkdown.length) return;
      var item = items.find(function(candidate) {
        return !used.has(candidate) && listCanonicalKey(materializedHttpUrl(candidate.url) || "") === record.destination &&
          (candidate.repeatedRecordIdentity === record.identity || normalizeText(candidate.text) === record.title);
      });
      if (!item) return;
      used.add(item);
      var sourceAlt = normalizeText((record.node.querySelector("a[href] img[src]") || {}).alt || "");
      if (normalizeText(item.image || "") === sourceAlt) item.image = "";
      if (!record.mediaMarkdown.some(function(media) { return (item.image || "").includes(media); })) {
        item.image = [item.image, record.mediaMarkdown.join(" ")].filter(Boolean).join(" ");
      }
    });
  }

  function pageOwnedOverviewSection(node) {
    var identity = [node.className || "", node.id || "", node.getAttribute("aria-label") || "",
      node.getAttribute("itemprop") || "", node.getAttribute("data-section") || "", node.getAttribute("data-type") || ""].join(" ");
    if (!/(?:^|[\s_-])(?:about|overview|intro(?:duction)?|chi[-_ ]?siamo)(?:$|[\s_-])/i.test(identity)) return false;
    if (!node.matches("section, div") || node.closest("article, header, footer, nav, aside, [role='navigation'], [role='complementary']") ||
        listChromeNode(node) || listNoiseNode(node) || listExplicitAdvertisementOwner(node) ||
        /(?:^|[\s_-])(?:sidebar|rail|related|recommendations?|support(?:ing)?|promotions?|sponsors?|advert(?:ising)?|widgets?|navigation|toolbar)(?:$|[\s_-])/i.test(identity) ||
        node.querySelector("a[href], article, header, footer, nav, aside, form, button, input, select, textarea, ul, ol, table, [role='list'], [role='navigation'], [role='complementary'], [class*='card' i], [class*='story' i], [class*='news' i], [class*='item' i]")) return false;
    var headings = Array.prototype.filter.call(node.querySelectorAll("h2, h3, h4"), function(heading) {
      return !elementSubtreeHidden(heading) && !heading.closest("a[href]");
    });
    var paragraphs = Array.prototype.filter.call(node.querySelectorAll("p"), function(paragraph) {
      return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent || "").length >= 80;
    });
    return headings.length === 1 && paragraphs.length > 0;
  }

  function pageOwnedHeadingIntro(parent, branch, content) {
    var children = Array.prototype.slice.call(parent.children);
    var ownerIndex = children.indexOf(branch);
    var pageTitles = [normalizeText(content && content.title || ""), normalizeText(document.title || "")].filter(Boolean);
    var headings = children.filter(function(child) {
      return child.matches("h1") && !elementSubtreeHidden(child) && !child.querySelector("a[href]") &&
        pageTitles.indexOf(normalizeText(child.textContent || "")) !== -1;
    });
    if (headings.length !== 1) return [];
    var headingIndex = children.indexOf(headings[0]);
    if (headingIndex >= ownerIndex) return [];
    var introNodes = [headings[0]];
    var paragraphCharacters = 0;
    for (var index = headingIndex + 1; index < ownerIndex; index += 1) {
      var sibling = children[index];
      if (!sibling.matches("p") || elementSubtreeHidden(sibling) || sibling.querySelector("a[href]")) return [];
      var text = normalizeText(sibling.textContent || "");
      if (!text) continue;
      paragraphCharacters += text.length;
      introNodes.push(sibling);
    }
    return introNodes.length > 1 && paragraphCharacters >= 80 ? introNodes : [];
  }

  function pageOwnedRenderContext(owner, content) {
    var branch = owner;
    var parent = branch.parentElement;
    while (parent && !parent.matches("html, main, [role='main']") &&
        !parent.closest("article, nav, header, footer, aside, [role='navigation'], [role='complementary']")) {
      var overviewNodes = Array.prototype.filter.call(parent.children, function(child) {
        return child !== branch && !elementSubtreeHidden(child) && pageOwnedOverviewSection(child);
      });
      var headingIntroNodes = pageOwnedHeadingIntro(parent, branch, content);
      var contextNodes = overviewNodes.concat(headingIntroNodes);
      if (contextNodes.length) {
        return {
          owner: parent,
          nodes: Array.prototype.filter.call(parent.children, function(child) {
            return child === branch || contextNodes.indexOf(child) !== -1;
          })
        };
      }
      if (parent.children.length !== 1 || parent.firstElementChild !== branch) break;
      branch = parent;
      parent = parent.parentElement;
    }
    return null;
  }
