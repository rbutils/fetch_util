  function extractFallbackHeadlineItems(node, existingContext, repeatedRecordByLink) {
    if (!node || !node.querySelectorAll) return [];
    var seen = {};
    var ranked = [];
    var context = listPageContext();
    if (existingContext) context.supportingLinks = existingContext.supportingLinks || existingContext;
    var coveredTables = existingContext && existingContext.coveredRecordTables || [];
    var sectionContext = Object.assign({}, context);
    context.tableIndexPage = !!linkedTableIndexRoot();
    var selectors = [
      "h1 a[href]", "h2 a[href]", "h3 a[href]", "h4 a[href]", "a[href]:has(h1, h2, h3, h4)", "article a[href]",
      "section a[href]", "[class*='headline' i] a[href]", "[class*='story' i] a[href]",
      "[class*='post' i] a[href]", "[class*='news' i] a[href]", "[class*='feed' i] a[href]",
      "[class*='teaser' i] a[href]", "[class*='result' i] a[href]"
    ].join(", ");

    Array.prototype.forEach.call(node.querySelectorAll(selectors), function(link) {
      if (context.supportingLinks.has(link) || coveredTables.some(function(table) {
        return table.contains(link);
      })) return;
      var container = link.closest("tr, article, section, li, div") || link.parentElement;
      if (listNavigationNode(link) || listNavigationNode(link.parentElement) || listNavigationAncestor(link)) return;
      var candidate = listLinkCandidate(link, container, context, true);
      if (!candidate) return;
      if (candidate.groupLabel == null && candidate.card && genericListCardBoundary(candidate.card)) {
        var nested = candidate.card.querySelectorAll(genericListCardSelector());
        if (genericListStructuredCardLink(candidate.card) !== link && Array.prototype.some.call(nested, function(card) {
          return genericListNestedCard(card) && genericListNestedCardReplaces(candidate.card, card);
        })) return;
        var primary = sectionCardCandidate(candidate.card, { listContext: sectionContext });
        if (primary && primary.sourceNode !== link &&
            (!candidate.url || listCanonicalKey(primary.url) !== listCanonicalKey(candidate.url))) return;
      }
      candidate.sourceNode = link;
      var ownSection = candidate.url && candidate.card && candidate.card.matches("section") &&
        !Array.prototype.some.call(candidate.card.querySelectorAll("a[href]"), function(other) {
          var url = materializedHttpUrl(other.getAttribute("href"));
          return url && url !== candidate.url;
        });
      if (genericListStructuredCardLink(candidate.card) === link || (primary && primary.sourceNode === link) || ownSection) {
        addCardContext(candidate, candidate.card);
      }
      var repeatedRecord = repeatedRecordByLink && repeatedRecordByLink.get(link);
      applyRepeatedRecordIdentity(candidate, repeatedRecord);
      if (repeatedRecordOwnsHeadlineCard(candidate, repeatedRecord)) candidate.sourceOrderedRepeatedRecord = true;
      pushUniqueListCandidate(ranked, seen, candidate);
    });
    return ranked;
  }

  function applyLinkedHeadingRecordIdentity(candidate) {
    var card = candidate && candidate.card;
    var link = candidate && candidate.sourceNode;
    if (!card || !link || candidate.repeatedRecordIdentity || !link.matches("a[href]") || !card.contains(link) ||
        !link.querySelector("h1, h2, h3, h4, h5, h6") || !link.querySelector("p")) return;
    if (!materializedHttpUrl(link.getAttribute("href")) || listCardNodeHidden(card) || listCardNodeHidden(link) ||
        listChromeNode(card) || listChromeNode(link) || listChromeAncestor(link) ||
        link.closest("pre, code, kbd, samp, button, nav, [role='button'], [role='navigation']")) return;
    var owner = link;
    while (owner !== card) {
      var parent = owner.parentElement;
      if (!parent || Array.from(parent.childNodes).some(function(node) {
        return node !== owner && (node.nodeType === 1 ||
          (node.nodeType === 3 && normalizeText(node.nodeValue || "")));
      })) return;
      owner = parent;
    }
    var headings = Array.from(link.querySelectorAll("h1, h2, h3, h4, h5, h6")).filter(function(heading) {
      return normalizeText(heading.textContent || "") && !listCardNodeHidden(heading) &&
        heading.closest("a[href]") === link &&
        !heading.closest("pre, code, kbd, samp, button, nav, [role='button'], [role='navigation']");
    });
    var hasProse = Array.from(link.querySelectorAll("p")).some(function(paragraph) {
      return normalizeText(paragraph.textContent || "") && !listCardNodeHidden(paragraph) &&
        !paragraph.closest("pre, code, kbd, samp, button, nav");
    });
    if (headings.length !== 1 || !hasProse) return;
    candidate.dedupeKey = card;
    candidate.sourceOrderedHeadingCard = true;
  }

  function linkedNarrativeRouteKind(path) {
    path = path || "";
    var routes = /\/(?:subscribe|subscription|abonnement|login|register|newsletter|account|instellingen|settings)\b/ig;
    var matched = false;
    var match;
    while ((match = routes.exec(path))) {
      matched = true;
      // A prefixed article slug is not an exact account or subscription action segment.
      if (!/^-[^/]+(?:\/|$)/.test(path.slice(match.index + match[0].length))) return "action";
    }
    return matched ? "slug" : "ordinary";
  }

  function applyLinkedNarrativeRouteIdentity(candidate, path) {
    var kind = linkedNarrativeRouteKind(path);
    if (kind === "action") return false;
    if (kind === "ordinary") return true;
    applyLinkedHeadingRecordIdentity(candidate);
    if (!candidate.sourceOrderedHeadingCard) return false;
    candidate.sourceOwnedNarrativeRoute = true;
    return true;
  }

  function linkedNarrativeActionCard(card) {
    var link = card.matches("a[href]") ? card : card.querySelector("a[href]");
    var url = link && materializedHttpUrl(link.getAttribute("href"));
    if (!url || linkedNarrativeRouteKind(new URL(url).pathname) !== "action") return false;
    var record = { card: card, sourceNode: link };
    applyLinkedHeadingRecordIdentity(record);
    return record.sourceOrderedHeadingCard === true;
  }
