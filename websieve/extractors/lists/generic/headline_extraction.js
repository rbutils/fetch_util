  function extractFallbackHeadlineItems(node) {
    if (!node || !node.querySelectorAll) return [];
    var seen = {};
    var ranked = [];
    var context = listPageContext();
    var sectionContext = Object.assign({}, context);
    context.tableIndexPage = !!linkedTableIndexRoot();
    var selectors = [
      "h1 a[href]", "h2 a[href]", "h3 a[href]", "h4 a[href]", "a[href]:has(h1, h2, h3, h4)", "article a[href]",
      "section a[href]", "[class*='headline' i] a[href]", "[class*='story' i] a[href]",
      "[class*='post' i] a[href]", "[class*='news' i] a[href]", "[class*='feed' i] a[href]",
      "[class*='teaser' i] a[href]", "[class*='result' i] a[href]"
    ].join(", ");

    function shortCardProof(link, container, candidate) {
      if (genericListDirectAnchorCard(link, container) || genericListPairedMediaCard(link) === candidate.card) return true;
      if (candidate.category || candidate.time || candidate.image || candidate.caption) return true;

      var owner = genericListStructuredCardLink(candidate.card);
      if (!owner || listCanonicalKey(owner.href) !== listCanonicalKey(candidate.url)) return false;
      return Array.prototype.some.call(candidate.card.querySelectorAll("a[href]"), function(peer) {
        var peerUrl = peer !== link && !listCardNodeHidden(peer) && materializedHttpUrl(peer.getAttribute("href"));
        return peerUrl && listCanonicalKey(peerUrl) !== listCanonicalKey(candidate.url);
      });
    }

    Array.prototype.forEach.call(node.querySelectorAll(selectors), function(link) {
      var container = link.closest("tr, article, section, li, div") || link.parentElement;
      if (listNavigationNode(link) || listNavigationNode(link.parentElement) || listNavigationAncestor(link)) return;
      var candidate = listLinkCandidate(link, container, context, true);
      if (!candidate) return;
      if (candidate.groupLabel == null && candidate.card && genericListCardBoundary(candidate.card)) {
        var nested = candidate.card.querySelectorAll(genericListCardSelector());
        if (Array.prototype.some.call(nested, function(card) {
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
      if (candidate.text.length < 18 && !shortCardProof(link, container, candidate)) return;
      pushUniqueListCandidate(ranked, seen, candidate);
    });
    return ranked;
  }
