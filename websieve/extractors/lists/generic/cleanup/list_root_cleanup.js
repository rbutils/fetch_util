  function cleanupListRoot(root, producerProvenCardNodes) {
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
