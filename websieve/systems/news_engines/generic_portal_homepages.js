  function genericHomepageLeadRoot(metadata, options) {
    options = options || {};
    if (!document.body || !homepageRootPath()) return null;
    if (homepageHasEditorialSections(document)) return null;
    if (typeof articleRouteFocalContent === "function" && articleRouteFocalContent()) return null;
    if (document.querySelector("article h1, article [itemprop='articleBody'], [type='application/ld+json']")) {
      var bodyText = normalizeText(document.body.textContent || "");
      if (document.querySelector("article h1") && bodyText.length < 30000) return null;
    }

    var roots = [];
    ["main", "[role='main']", "#main", ".main", "body"].forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(root) {
        if (roots.indexOf(root) === -1) roots.push(root);
      });
    });

    var best = null;
    var minItems = options.minItems || 5;
    var portalIntentPattern = /\b(find|search|book|compare|deals?|offers?|destinations?|routes?|tickets?|timetables?|trains?|travel|hotels?|homes?|properties|real estate|for sale|for rent|marketplaces?|listings?|latest|top stories|headlines|breaking news)\b/i;
    var titleIntentText = normalizeText([
      (metadata && metadata.title) || "",
      (metadata && metadata.siteName) || "",
      document.title || ""
    ].join(" ")).toLowerCase();
    var descriptionIntentText = normalizeText((metadata && metadata.excerpt) || "").toLowerCase();
    var descriptionPortalIntentTerms = [];
    (descriptionIntentText.match(new RegExp(portalIntentPattern.source, "gi")) || []).forEach(function(term) {
      term = term.toLowerCase();
      if (descriptionPortalIntentTerms.indexOf(term) === -1) descriptionPortalIntentTerms.push(term);
    });
    var intentText = normalizeText([
      (metadata && metadata.title) || "",
      (metadata && metadata.siteName) || "",
      document.title || "",
      document.body.textContent || ""
    ].join(" ")).toLowerCase().slice(0, 6000);
    var metadataPortalIntent = portalIntentPattern.test(titleIntentText) || descriptionPortalIntentTerms.length >= 2;
    var portalIntent = portalIntentPattern.test(intentText);

    function leadActionText(text) {
      return /^(?:read|learn|see) more$/i.test(normalizeText(text || ""));
    }

    function leadVisibleClone(node) {
      if (!node || elementSubtreeHidden(node)) return null;
      var clone = visibilityPrunedClone(node, document);
      var text = normalizeText(clone.textContent || "");
      var media = clone.querySelector("img[src], picture source[srcset], video[src], svg");
      return text || media ? clone : null;
    }

    function leadCardNode(link) {
      return link.closest("article, li, [class*='card'], [class*='tile'], [class*='item'], [class*='listing'], [class*='result'], [class*='destination'], [class*='route'], [class*='story']");
    }

    function leadActionHeading(link) {
      if (!materializedHttpUrl(link.getAttribute("href") || "")) return "";
      var card = leadCardNode(link);
      if (!card) return "";

      var destinations = {};
      Array.prototype.forEach.call(card.querySelectorAll("a[href]"), function(candidate) {
        if (!leadVisibleClone(candidate)) return;
        var href = candidate.getAttribute("href") || "";
        var url = materializedHttpUrl(href);
        if (url) destinations[homepageCanonicalUrl(url)] = true;
      });
      if (Object.keys(destinations).length !== 1) return "";

      var title = "";
      Array.prototype.some.call(card.querySelectorAll("h1, h2, h3, h4"), function(heading) {
        var visibleHeading = leadVisibleClone(heading);
        title = normalizeText((visibleHeading && visibleHeading.textContent) || "");
        return !!title;
      });
      return title;
    }

    function leadTitle(link) {
      if (!link || elementSubtreeHidden(link)) return "";
      if (link.closest("header, nav, footer, aside, form, [role='navigation'], [role='banner'], [role='contentinfo']")) return "";

      var href = link.getAttribute("href") || "";
      var visibleLink = visibilityPrunedClone(link, document);
      var titleNode = visibleLink && visibleLink.querySelector("h1, h2, h3, h4");
      var accessibleTitle = elementVisuallyHidden(link) ? "" : link.getAttribute("aria-label");
      var title = normalizeText((titleNode && titleNode.textContent) || (visibleLink && visibleLink.textContent) || accessibleTitle || "");
      if (leadActionText(title)) title = leadActionHeading(link);
      if (rejectedHomepageLeadText(title, href)) return "";
      if (title.length < 12 && !/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u.test(title)) return "";
      return title;
    }

    function leadDetailRoot(link, boundary, selectedTitle) {
      var href = link.getAttribute("href") || "";
      var url = materializedHttpUrl(href);
      var selectedKey = url ? homepageCanonicalUrl(url) : "unlinked:" + selectedTitle.toLowerCase() + "|href:" + href;
      var localRoot = link;
      var current = link;
      var selectedIsPrimary = !!link.closest("h1, h2, h3, h4") || leadActionText(normalizeText(link.textContent || ""));

      while (current && boundary.contains(current)) {
        var selectedBranch = link;
        while (selectedBranch.parentElement && selectedBranch.parentElement !== current) {
          selectedBranch = selectedBranch.parentElement;
        }
        var links = current.matches && current.matches("a[href]")
          ? [current]
          : Array.prototype.slice.call(current.querySelectorAll("a[href]"));
        var hasPeer = links.some(function(candidate) {
          if (candidate === link) return false;
          var candidateBranch = candidate;
          while (candidateBranch.parentElement && candidateBranch.parentElement !== current) {
            candidateBranch = candidateBranch.parentElement;
          }
          if (candidateBranch === selectedBranch) return false;
          var candidateIsPrimary = !!candidate.closest("h1, h2, h3, h4") || leadActionText(normalizeText(candidate.textContent || ""));
          if (selectedIsPrimary && !candidateIsPrimary) return false;
          if (candidate.matches("[rel='author'], [itemprop='author']") || candidate.closest("[class*='author' i], [class*='byline' i]")) return false;
          var title = leadTitle(candidate);
          if (!title) return false;
          var candidateHref = candidate.getAttribute("href") || "";
          var candidateUrl = materializedHttpUrl(candidateHref);
          var key = candidateUrl ? homepageCanonicalUrl(candidateUrl) : "unlinked:" + title.toLowerCase() + "|href:" + candidateHref;
          var selectedLinkClone = leadVisibleClone(link);
          var candidateLinkClone = leadVisibleClone(candidate);
          var selectedLinkText = normalizeText((selectedLinkClone && selectedLinkClone.textContent) || "");
          var candidateLinkText = normalizeText((candidateLinkClone && candidateLinkClone.textContent) || "");
          var selectedAction = leadActionText(selectedLinkText);
          var candidateAction = leadActionText(candidateLinkText);
          var selectedCard = leadCardNode(link);
          var candidateCard = leadCardNode(candidate);
          var selectedBranchClone = leadVisibleClone(selectedBranch);
          var candidateBranchClone = leadVisibleClone(candidateBranch);
          var selectedBranchHasHeading = !!(selectedBranchClone &&
            (selectedBranchClone.matches("h1, h2, h3, h4") || selectedBranchClone.querySelector("h1, h2, h3, h4")));
          var candidateBranchHasHeading = !!(candidateBranchClone &&
            (candidateBranchClone.matches("h1, h2, h3, h4") || candidateBranchClone.querySelector("h1, h2, h3, h4")));
          var selectedBranchText = normalizeText((selectedBranchClone && selectedBranchClone.textContent) || "");
          var candidateBranchText = normalizeText((candidateBranchClone && candidateBranchClone.textContent) || "");
          var sameRecordAlias = key === selectedKey && title === selectedTitle && selectedCard === candidateCard && (
            (selectedAction && !candidateAction && !selectedBranchHasHeading && candidateBranchHasHeading &&
              selectedBranchText === selectedLinkText && candidateBranchText === title) ||
            (candidateAction && !selectedAction && selectedBranchHasHeading && !candidateBranchHasHeading &&
              selectedBranchText === selectedTitle && candidateBranchText === candidateLinkText)
          );
          if (sameRecordAlias) return false;
          if (key !== selectedKey || !candidateAction) return true;

          if (selectedCard && candidateCard && selectedCard !== candidateCard) return true;
          return !!(selectedBranch.querySelector && candidateBranch.querySelector &&
            selectedBranch.querySelector("h1, h2, h3, h4") && candidateBranch.querySelector("h1, h2, h3, h4"));
        });
        if (hasPeer) break;

        localRoot = current;
        if (current === boundary) break;
        current = current.parentElement;
      }
      return localRoot;
    }

    roots.forEach(function(root) {
      var seen = {};
      var items = [];
      var headings = [];
      var hero = normalizeText(((root.querySelector("h1") || {}).textContent) || "");

      root.querySelectorAll("h2, h3").forEach(function(heading) {
        if (elementSubtreeHidden(heading)) return;
        var visibleHeading = visibilityPrunedClone(heading, document);
        var text = normalizeText(visibleHeading.textContent || "");
        if (!text) return;
        var titleCard = heading.closest("article, li, [class~='card'], [class~='tile'], [class~='item'], [class~='listing'], [class~='result'], [class~='destination'], [class~='route'], [class~='story']");
        var cardTitle = !!(heading.closest("a[href]") || heading.querySelector("a[href]"));
        if (!cardTitle && titleCard) {
          cardTitle = Array.prototype.slice.call(titleCard.querySelectorAll("a[href]")).some(function(link) {
            if (elementSubtreeHidden(link)) return false;
            return normalizeText(visibilityPrunedClone(link, document).textContent || "") === text;
          });
        }
        if (cardTitle) return;
        if (heading.closest && heading.closest("aside, nav, header, footer, [role='navigation'], [role='complementary'], [role='banner'], [role='contentinfo']")) return;
        if (listNoiseNode(heading.parentElement)) return;
        if (text.length >= 6 && text.length <= 90 && !rejectedHomepageLeadText(text, "") && headings.indexOf(text) === -1) headings.push(text);
      });

      root.querySelectorAll("a[href]").forEach(function(link) {
        var href = link.getAttribute("href") || "";
        var url = materializedHttpUrl(href);
        var title = leadTitle(link);
        var canonicalUrl = url ? homepageCanonicalUrl(url) : "unlinked:" + title.toLowerCase() + "|href:" + href;
        if (!title || seen[canonicalUrl]) return;

        var container = link.closest("article, section, li, [class*='card'], [class*='tile'], [class*='item'], [class*='listing'], [class*='result'], [class*='destination'], [class*='route'], [class*='story']") || link.parentElement;
        var cardRoot = homepageCardRoot(link);
        if (cardRoot && cardRoot !== container && cardRoot.contains(link)) container = cardRoot;
        if (cardRoot && cardRoot.querySelector("article h1 a[href], article h2 a[href], article h3 a[href], article h4 a[href]") && !cardRoot.querySelector("h1 a[href], h2 a[href], h3 a[href], h4 a[href]").contains(link)) return;
        container = leadDetailRoot(link, container, title);
        var detailRoot = visibilityPrunedClone(container, document);
        Array.prototype.slice.call(detailRoot.querySelectorAll("h1, h2, h3, h4, a[href]")).forEach(function(node) {
          var text = normalizeText(node.textContent || "");
          if (text === title || leadActionText(text)) node.remove();
        });
        var detail = searchItemDetail(detailRoot, title);

        seen[canonicalUrl] = true;
        items.push({ text: title, url: url, detail: detail });
      });

      var text = normalizeText(root.textContent || "");
      var links = root.querySelectorAll("a[href]").length;
      var cards = root.querySelectorAll("article, section, li, [class*='card'], [class*='tile'], [class*='item'], [class*='listing'], [class*='result'], [class*='destination'], [class*='route'], [class*='story']").length;
      var heroScore = hero && hero.length >= 8 && hero.length <= 120 ? 180 : 0;
      var sectionScore = Math.min(headings.length, 6) * 60;
      var score = items.length * 180 + heroScore + sectionScore + Math.min(cards, 18) * 12 + Math.min(links, 80);
      var materializedItems = materializedListItemCount(items);

      if (materializedItems < minItems && !(materializedItems >= 3 && heroScore && headings.length >= 2)) return;
      if (!portalIntent && !(materializedItems >= 6 && cards >= 6 && headings.length >= 3)) return;
      if (links < items.length || text.length < 120) return;
      if (!best || score > best.score) {
        best = { root: root, items: items, hero: hero, headings: headings, materializedItems: materializedItems, score: score };
      }
    });

    if (!best) return null;
    if (best.materializedItems < minItems && (!best.hero || best.headings.length < 2)) return null;
    best.provisional = best.materializedItems < minItems && !metadataPortalIntent;
    return best;
  }

  function genericPortalHomepageContent(metadata) {
    if (homepageRootPath()) {
      var sectioned = listContent(metadata, { portalRoot: true });
      if (sectioned.portalRootEvidence) return sectioned;
    }

    var leadRoot = genericHomepageLeadRoot(metadata, { minItems: 4 });
    if (!leadRoot) return null;

    var title = leadRoot.hero || (metadata && metadata.title) || document.title || location.hostname;
    var markdownParts = [];
    if (leadRoot.hero) markdownParts.push("# " + leadRoot.hero);
    if (metadata && metadata.excerpt) markdownParts.push(metadata.excerpt);
    var itemTitles = new Set(leadRoot.items.map(function(item) { return normalizeText(item.text).toLowerCase(); }));
    var sectionHeadings = leadRoot.headings.filter(function(text) {
      return !itemTitles.has(normalizeText(text).toLowerCase());
    });
    if (sectionHeadings.length >= 2) {
      markdownParts.push(sectionHeadings.map(function(text) { return "- " + text; }).join("\n"));
    }
    markdownParts.push(listMarkdown(leadRoot.items));

    var markdown = markdownParts.filter(Boolean).join("\n\n").trim();
    var supplemented = supplementedHomepageLead(leadRoot, sectioned);
    if (supplemented) markdown = supplemented.markdown;
    if (normalizeText(markdown).length < 180) return null;

    var result = listContentResult({
      title: title,
      excerpt: metadata && metadata.excerpt,
      siteName: (metadata && metadata.siteName) || location.hostname,
      markdown: markdown,
      textContent: normalizeText(markdown)
    });
    result.listSourceNode = leadRoot.root;
    result.listSourceItems = supplemented ? supplemented.items : leadRoot.items;
    if (leadRoot.provisional) result.provisionalPortal = true;
    return result;
  }
