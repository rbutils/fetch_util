  function articleActionSourceOwner(root) {
    if (!document.body || root.querySelectorAll("h1").length > 1) return null;
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementSubtreeHidden(heading);
    });
    var selectedHeading = root.querySelector("h1");
    if (headings.length !== 1 || (selectedHeading &&
        normalizeText(headings[0].textContent) !== normalizeText(selectedHeading.textContent))) return null;

    var owner = headings[0].parentElement;
    while (owner && owner !== document.body && owner.querySelectorAll("p").length < 3) {
      owner = owner.parentElement;
    }
    if (!owner || owner === document.body) return null;

    var sourceParagraphs = Array.from(owner.querySelectorAll("p")).filter(function(paragraph) {
      return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent).length >= 50;
    }).map(function(paragraph) { return normalizeText(paragraph.textContent); });
    var selectedParagraphs = Array.from(root.querySelectorAll("p")).filter(function(paragraph) {
      return sourceParagraphs.indexOf(normalizeText(paragraph.textContent)) >= 0;
    });
    return selectedParagraphs.length >= 3 ? owner : null;
  }

  function articleActionClass(node) {
    return /(?:^|[\s_-])(?:comments?|repl(?:y|ies)|support|share|social|rating|vote)(?:[\s_-]|$)/i.test(node.getAttribute("class") || "");
  }

  function articleActionCluster(node, sourceOwner) {
    if (node.children.length < 2 || normalizeText(node.textContent).length > 220 ||
        node.querySelector("p, article, main, h1, h2, h3, h4, a[href], img, picture, video, audio, blockquote, pre, code, table, form")) return false;
    if (Array.from(node.querySelectorAll("ul, ol")).some(function(list) {
      return list.parentElement !== node || !/(?:^|[\s_-])(?:share|social)(?:[\s_-]|$)/i.test(list.className) ||
        !list.children.length || !Array.from(list.children).every(function(item) {
          return item.matches("li") && !item.children.length &&
            /^(?:share|copy (?:link|url)|send)$/i.test(normalizeText(item.textContent || ""));
        });
    })) return false;
    var children = Array.from(node.children);
    if (!children.every(function(child) {
      return articleActionClass(child) && normalizeText(child.textContent).length <= 90;
    })) return false;
    if (!children.some(function(child) { return /comment|repl/i.test(child.getAttribute("class") || ""); }) ||
        !children.some(function(child) { return /support|share|social|rating|vote/i.test(child.getAttribute("class") || ""); })) return false;

    var text = normalizeText(node.textContent || "");
    return Array.from(sourceOwner.querySelectorAll("div, section")).some(function(source) {
      return !elementSubtreeHidden(source) && source.className === node.className &&
        normalizeText(source.textContent || "").startsWith(text);
    });
  }

  function articleNewsFollowControl(node, sourceOwner) {
    if (node.children.length || node.closest("p, h1, h2, h3, h4, figure, blockquote, li") ||
        !/^(?:přidat mezi oblíbené zdroje na .+|add (?:us )?to (?:your )?(?:favorite|favourite) news sources(?: on .+)?|follow (?:us|this (?:site|publisher)) on .+)$/i.test(normalizeText(node.textContent))) return false;
    var destination = materializedHttpUrl(node.getAttribute("href") || "");
    if (!destination || new URL(destination).origin === location.origin ||
        !node.parentElement || node.parentElement.querySelectorAll("p").length !== 1 ||
        normalizeText(node.parentElement.querySelector("p").textContent).length < 60 ||
        node.parentElement.querySelectorAll("a[href]").length !== 1) return false;
    return Array.from(sourceOwner.querySelectorAll("a[href]")).some(function(source) {
      return !elementSubtreeHidden(source) &&
        materializedHttpUrl(source.getAttribute("href")) === destination &&
        normalizeText(source.textContent) === normalizeText(node.textContent);
    });
  }

  function articleReactionControl(node, sourceOwner) {
    var text = normalizeText(node.textContent || "");
    if (!/(?:^|[\s_-])(?:thumbs|rating|feedback|reaction|vote)(?:[\s_-]|$)/i.test(node.getAttribute("class") || "") ||
        !text || text.length > 140 ||
        !/(?:helpful|useful|líbí|nelíbí|like|dislike|thumbs|vote)/i.test(text) ||
        node.querySelector("p, article, a[href], img, picture, video, audio, blockquote, pre, code, table, ul, ol")) return false;
    return Array.from(sourceOwner.querySelectorAll("div, section")).some(function(source) {
      return !elementSubtreeHidden(source) && source.className === node.className &&
        normalizeText(source.textContent || "") === text;
    });
  }

  function articlePublicationPromoControl(node, sourceOwner) {
    var text = normalizeText(node.textContent || "");
    if (node.children.length || !text || text.length > 220 ||
        !SOCIAL_APP_PROMO_TEXT_PATTERN.test(text)) return false;
    return Array.prototype.some.call(sourceOwner.querySelectorAll("p, div, span, a"), function(source) {
      return !elementSubtreeHidden(source) && source.tagName === node.tagName && !source.children.length &&
        normalizeText(source.textContent || "") === text;
    });
  }

  function articleGoogleSourcePreferenceIntent(node) {
    if (!node || !node.matches || !node.matches("a[href]") || node.children.length ||
        node.closest("p, blockquote, li, figure, figcaption, h1, h2, h3, h4, h5, h6, pre, code, td, th, dd, dt") ||
        node.hasAttribute("itemprop") || node.hasAttribute("itemref") || node.hasAttribute("property") ||
        /(?:^|\s)(?:citation|bookmark|canonical)(?:\s|$)/i.test(node.getAttribute("rel") || "")) return null;

    var label = normalizeText(node.textContent || "");
    var match = label.match(/^Προσθήκη του (.+) ως προτεινόμενη πηγή στην Google$/iu);
    if (!match) return null;
    var publisher = normalizeText(match[1]);
    if (!domainLikeText(publisher)) return null;

    var destination = materializedHttpUrl(node.getAttribute("href") || "");
    if (!destination) return null;
    try {
      var url = new URL(destination);
      var parameters = Array.from(url.searchParams.entries());
      if (url.protocol !== "https:" || !/^(?:www\.)?google\.com$/i.test(url.hostname) ||
          url.pathname !== "/preferences/source" || url.username || url.password || url.port || url.hash ||
          parameters.length !== 1 || parameters[0][0] !== "q" ||
          normalizeText(parameters[0][1]).toLowerCase() !== publisher.toLowerCase()) return null;
    } catch (_error) {
      return null;
    }
    return publisher;
  }

  function articleGoogleSourcePreferenceControlContext(node) {
    if (!node || !node.parentElement || !node.closest("article") ||
        node.tagName !== "A") return false;
    var parent = node.parentElement;
    var visibleChildren = Array.from(parent.children).filter(function(child) { return !elementSubtreeHidden(child); });
    if (visibleChildren.length !== 2 || visibleChildren.indexOf(node) === -1 ||
        Array.from(parent.childNodes || []).some(function(child) {
      return child.nodeType === 3 && normalizeText(child.nodeValue || "");
    })) return false;

    var bodies = visibleChildren.filter(function(child) { return child !== node; });
    if (bodies.length !== 1 || bodies[0].matches("a, button, input, select, textarea, form, nav, aside, footer")) return false;
    var material = Array.from(bodies[0].querySelectorAll("p, blockquote, figure, table, ul, ol, pre, code, h2, h3, h4")).some(function(item) {
      if (elementSubtreeHidden(item)) return false;
      return !!(normalizeText(item.textContent || "") || item.querySelector("img, audio, video, a[href], table"));
    });
    return material;
  }

  function articleGoogleSourcePreferenceAnchors(root) {
    if (!root || !root.querySelectorAll) return [];
    var anchors = Array.from(root.querySelectorAll("a[href]"));
    if (root.matches && root.matches("a[href]")) anchors.unshift(root);
    return anchors.filter(function(anchor) {
      return !!articleGoogleSourcePreferenceIntent(anchor) && !elementSubtreeHidden(anchor) &&
        articleGoogleSourcePreferenceControlContext(anchor);
    });
  }

  function stripGoogleSourcePreferenceControl(sourceRoot, cloneRoot, sourceClones) {
    if (!sourceRoot || !cloneRoot) return cloneRoot;
    var sourceAnchors = articleGoogleSourcePreferenceAnchors(sourceRoot);
    var cloneAnchors = articleGoogleSourcePreferenceAnchors(cloneRoot);
    if (sourceAnchors.length !== 1 || cloneAnchors.length !== 1 ||
        !sourceAnchors[0].isConnected || !sourceAnchors[0].isEqualNode(cloneAnchors[0]) ||
        (sourceClones && sourceClones.get(sourceAnchors[0]) !== cloneAnchors[0])) return cloneRoot;
    cloneAnchors[0].remove();
    if (sourceClones) sourceClones.delete(sourceAnchors[0]);
    return cloneRoot;
  }

  function stripSourceOwnedArticleActions(root) {
    var sourceOwner = articleActionSourceOwner(root);
    if (!sourceOwner) return root;
    root.querySelectorAll("div, section").forEach(function(node) {
      if (articleActionCluster(node, sourceOwner)) node.remove();
      else if (articleReactionControl(node, sourceOwner)) node.remove();
    });
    root.querySelectorAll("p, div, span, a").forEach(function(node) {
      if (articlePublicationPromoControl(node, sourceOwner)) node.remove();
      else if (articleCitationActionControl(node, sourceOwner)) node.remove();
    });
    root.querySelectorAll("a[href]").forEach(function(node) {
      if (articleNewsFollowControl(node, sourceOwner)) node.remove();
    });
    return root;
  }

  function articleCitationActionControl(node, sourceOwner) {
    if (node.children.length || !node.matches("p, div, span") ||
        !/\b(?:citation|citations|download|downloads|document actions)\b/.test(visibleMetadataOwnerText(node))) return false;
    var text = normalizeText(node.textContent || "");
    var parts = text.split(/\s*\|\s*/);
    var action = /^(?:download\s+(?:pdf|text|word|docx?)|cited by\s+[\d,]+)$/i;
    if (parts.filter(function(part) { return action.test(part); }).length < 2) return false;
    if (!parts.every(function(part) {
      return action.test(part) || /^\d+\s+[A-Z][A-Za-z.\s]*\s+\d+(?:\s+\(\d{4}\))?$/.test(part);
    })) return false;
    var sources = Array.from(sourceOwner.querySelectorAll(node.tagName.toLowerCase())).filter(function(source) {
      return !elementSubtreeHidden(source) && source.className === node.className &&
        normalizeText(source.textContent || "") === text;
    });
    if (sources.length !== 1) return false;
    var paragraphs = Array.from(sourceOwner.querySelectorAll("p")).filter(function(paragraph) {
      return !elementSubtreeHidden(paragraph) && paragraph !== sources[0] &&
        normalizeText(paragraph.textContent || "").length >= 50;
    });
    return paragraphs.length >= 3 && paragraphs.every(function(paragraph) {
      return sourceRecordBefore(sources[0], paragraph) || paragraph.closest("header");
    });
  }

  function stripSourceOwnedCitationActions(root) {
    var sourceOwner = articleActionSourceOwner(root);
    if (!sourceOwner) return root;
    root.querySelectorAll("p, div, span").forEach(function(node) {
      if (articleCitationActionControl(node, sourceOwner)) node.remove();
    });
    return root;
  }
