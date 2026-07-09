  function composeProfileArticleRoot(config) {
    config = config || {};

    var scope = profileArticleRootScope(config);
    if (!scope) return null;

    var root = document.createElement("article");
    var seenText = [];
    var hasBody = false;

    profileArticleAppendPart(root, scope, config.titleSelectors, seenText, false);
    profileArticleAppendPart(root, scope, config.leadSelectors, seenText, false);
    profileArticleAppendPart(root, scope, config.summarySelectors, seenText, false);
    profileArticleAppendPart(root, scope, config.captionSelectors || config.mediaCaptionSelectors, seenText, false);
    hasBody = profileArticleAppendPart(root, scope, config.bodySelectors, seenText, true);

    if (config.requireBody !== false && !hasBody) return null;
    return normalizeText(root.textContent || "").length >= (config.minTextLength || 0) ? root : null;
  }

  function leadBodyArticleRoot(lead, body) {
    var root = document.createElement("article");
    if (lead) root.appendChild(safeDeepClone(lead, document));
    if (body) root.appendChild(safeDeepClone(body, document));
    return root;
  }

  function profileArticleRootScope(config) {
    if (typeof config.scope === "function") return config.scope();
    if (config.scope) return config.scope;

    var selectors = config.scopeSelectors || [];
    for (var i = 0; i < selectors.length; i += 1) {
      var node = document.querySelector(selectors[i]);
      if (node) return node;
    }

    return document;
  }

  function profileArticleAppendPart(root, scope, selectors, seenText, appendAll) {
    if (!selectors) return false;

    var selectorList = Array.isArray(selectors) ? selectors : [selectors];
    var appended = false;
    for (var i = 0; i < selectorList.length; i += 1) {
      var node = profileArticlePartNode(scope, selectorList[i]);
      if (!node) continue;

      if (profileArticleAppendNode(root, node, seenText)) appended = true;
      if (appended && !appendAll) return true;
    }
    return appended;
  }

  function profileArticlePartNode(scope, selector) {
    if (typeof selector === "function") return selector(scope, document);
    if (selector && selector.nodeType === 1) return selector;
    if (!selector) return null;
    return (scope.querySelector && scope.querySelector(selector)) || document.querySelector(selector);
  }

  function profileArticleAppendNode(root, node, seenText) {
    var text = normalizeText(node.textContent || "");
    if (!text || seenText.indexOf(text) >= 0) return false;

    seenText.push(text);
    root.appendChild(safeDeepClone(node, document));
    return true;
  }
