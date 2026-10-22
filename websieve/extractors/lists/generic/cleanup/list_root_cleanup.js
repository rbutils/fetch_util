  function cleanupListRoot(root, producerProvenCardNodes, preservedOwnerNodes) {
    materializeArticleOwnedFooters(root);
    cleanupCookieChrome(root);
    stripTrackingPixels(root);
    resolveLazyImages(root);
    stripUIWidgets(root, { preserveCommentCounts: true });
    stripNavigationLeaks(root);
    root.querySelectorAll("header, footer, nav, menu, [role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='banner'], [role='contentinfo']").forEach(function(el) {
      el.remove();
    });
    root.querySelectorAll("section, div, aside, form, ul, ol").forEach(function(el) {
      if (!listChromeNode(el)) return;
      if (authoredCardActionReference(el)) return;
      if ((preservedOwnerNodes || []).indexOf(el) !== -1) return;
      if ((producerProvenCardNodes || []).some(function(card) {
        return card && (card === el || card.contains(el));
      })) return;
      if (listOwnedHeadingContainer(el)) {
        el.replaceWith.apply(el, Array.from(el.childNodes));
        return;
      }
      var recordRoots = genericListChromeOwnedRecordRoots(el);
      var missingProducerCard = (producerProvenCardNodes || []).some(function(card) {
        return card && el.contains(card) && !recordRoots.some(function(recordRoot) {
          return recordRoot !== el && recordRoot.contains(card);
        });
      });
      if (missingProducerCard) {
        el.replaceWith.apply(el, Array.from(el.childNodes));
        return;
      }
      if (recordRoots.length && el.parentNode) {
        recordRoots.forEach(function(recordRoot) {
          if (!homepageRootPath()) recordRoot.querySelectorAll("ul, ol, [role='list'], [class*='listing' i], [class*='grid' i], [class*='feed' i], [class*='results' i]").forEach(function(collection) {
            if (!listNoiseNode(collection)) return;
            var nestedRecords = Array.prototype.some.call(collection.querySelectorAll(genericListCardSelector()), function(card) {
              return !!genericListStructuredCardLink(card);
            });
            if (nestedRecords) collection.remove();
          });
          recordRoot.__fetchUtilChromeOwnedListRecords = true;
          el.parentNode.insertBefore(recordRoot, el);
        });
      }
      el.remove();
    });
    root.querySelectorAll('a[href^="#"]').forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (!text || /^skip\s+(to\s+)?/i.test(text)) el.remove();
    });
    root.querySelectorAll("a, button").forEach(function(el) {
      var text = normalizeText(el.textContent).toLowerCase();
      if (/^(sign in|log in|login|register|subscribe|newsletter|follow us|follow|join now|create account|my account|account|menu|search)$/i.test(text)) {
        el.remove();
      }
    });
    return root;
  }

  function listHtmlWithoutUnsafeDestinations(root, contactGroups) {
    var clone = safeDeepClone(root, document);
    clone.querySelectorAll("[data-fetch-util-structured-card-field]").forEach(function(node) {
      node.removeAttribute("data-fetch-util-structured-card-field");
    });
    var sourceLinks = contactGroups ? Array.from(root.querySelectorAll("a[href]")) : [];
    var links = Array.from(clone.querySelectorAll("a[href]"));
    links.forEach(function(link, index) {
      var source = sourceLinks[index];
      var contact = sourceLinks.length === links.length && source && contactGroups &&
        source.getAttribute("href") === link.getAttribute("href") && source.textContent === link.textContent &&
        contactGroups.some(function(group) { return group.contains(source); });
      var href = contact ? materializedLinkUrl(link.getAttribute("href"), materializedTextAnchor(link)) :
        materializedHttpUrl(link.getAttribute("href"));
      if (!href) link.removeAttribute("href");
    });
    return clone.innerHTML;
  }
