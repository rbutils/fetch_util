  function institutionalCaseIndexFocalArticle(root, headingText, caseCards) {
    var cardNodes = caseCards.map(function(card) { return card.sourceCard; }).filter(Boolean);
    if (!cardNodes.length) return false;

    var collectionOwner = null;
    for (var owner = cardNodes[0].parentElement; owner; owner = owner.parentElement) {
      if (cardNodes.every(function(card) { return owner.contains(card); })) {
        collectionOwner = owner;
        break;
      }
    }
    if (!collectionOwner) return false;

    return Array.prototype.some.call(root.querySelectorAll("article"), function(article) {
      if (elementSubtreeHidden(article) || collectionOwner.contains(article) ||
          article.closest("nav, header, footer, [role='navigation'], [role='complementary']")) return false;
      var ownsIndexHeading = Array.prototype.some.call(article.querySelectorAll("h1, [role='heading'][aria-level='1']"), function(heading) {
        return !elementSubtreeHidden(heading) && normalizeText(heading.textContent || "") === headingText;
      });
      if (!ownsIndexHeading) return false;
      return Array.prototype.some.call(article.querySelectorAll("p"), function(paragraph) {
        return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent || "").length >= 120 &&
          !cardNodes.some(function(card) { return card.contains(paragraph); });
      });
    });
  }

  function institutionalCaseRecordListPage(root, text, allowFocalArticle, returnProof) {
    root = root || document.body;
    text = normalizeText(text || (root && root.textContent) || "");
    if (!root || (!allowFocalArticle && articleRouteFocalContent())) return false;

    var caseRoot = root;
    if (returnProof) {
      if (elementSubtreeHidden(root)) return false;
      var mains = root.matches && root.matches("main, [role='main']") ? [root] :
        Array.prototype.filter.call(root.querySelectorAll("main, [role='main']"), function(node) {
          return !elementSubtreeHidden(node);
        });
      if (mains.length !== 1) return false;
      caseRoot = mains[0];
    }

    var indexHeading = Array.prototype.find.call(caseRoot.querySelectorAll("h1, [role='heading'][aria-level='1']"), function(heading) {
      return !elementSubtreeHidden(heading) &&
        /^(?:(?:all|current|open|closed)\s+)?(?:cases?|defendants?|records?|dockets?|matters?)(?:\s+(?:index|search|listing|directory))?$/i.test(normalizeText(heading.textContent || ""));
    });
    if (!indexHeading) return false;

    var context = normalizeText([location.pathname, document.title, (document.querySelector("h1") || {}).textContent].join(" ")).toLowerCase();
    if (!/\b(?:cases?|defendants?|records?|dockets?|matters?)\b/.test(context)) return false;

    var caseCards = collectCardLinkCandidates(caseRoot, {
      cardSelectors: ".card, [class*='case-card' i], [class*='record-card' i], [class*='result-card' i], article, li",
      allowMissingUrl: true,
      dedupe: false,
      minTitleLength: 3,
      maxTitleLength: returnProof ? Infinity : 180,
      linkBuilder: function(card) {
        return card.querySelector(".card-header, h2, h3, h4, a[href]");
      },
      candidateBuilder: function(card, titleNode) {
        if (card.closest("nav, header, footer, menu, [role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='banner']")) return null;
        var cardText = normalizeText(card.textContent || "");
        var link = titleNode && titleNode.matches && titleNode.matches("a[href]") ? titleNode :
          titleNode && titleNode.querySelector && titleNode.querySelector("a[href]");
        if (!link) link = card.querySelector("a[href]");
        var href = link ? link.getAttribute("href") : "";
        var url = materializedHttpUrl(href);
        if (!/\b(?:case|defendant|prosecutor|trial|charges?|warrant|summons|custody|convicted|acquitted|closed|at large|court|record|docket|matter)\b/i.test(cardText)) return null;
        return {
          text: normalizeText((titleNode || {}).textContent || ""),
          url: url,
          admission: !href || !!url,
          sourceNode: link,
          sourceCard: card
        };
      }
    });
    var filterBlocks = caseRoot.querySelectorAll("form, [class*='filter' i], [class*='facet' i], [class*='exposed' i], [class*='search' i]").length;
    var countLabel = /\b\d{1,4}\s+(?:cases?|defendants?|records?|matters?|results?)\b/i.test(text);
    var admittedCards = caseCards.filter(function(card) { return card.admission; }).length;
    var qualifies = caseCards.length >= 4 && admittedCards >= 4 && (filterBlocks >= 1 || countLabel);
    if (!qualifies) return false;

    var focalArticle = institutionalCaseIndexFocalArticle(caseRoot, normalizeText(indexHeading.textContent || ""), caseCards);
    if (returnProof) {
      return {
        root: caseRoot,
        titleLinks: caseCards.filter(function(card) { return card.admission && card.sourceNode; })
          .map(function(card) { return card.sourceNode; }),
        cardNodes: caseCards.filter(function(card) { return card.admission && card.sourceCard; })
          .map(function(card) { return card.sourceCard; }),
        focalArticle: focalArticle
      };
    }
    return !focalArticle;
  }
