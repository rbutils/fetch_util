  function articleActionSourceOwner(root) {
    if (!document.body || root.querySelectorAll("h1").length !== 1) return null;
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementSubtreeHidden(heading);
    });
    if (headings.length !== 1 ||
        normalizeText(headings[0].textContent) !== normalizeText(root.querySelector("h1").textContent)) return null;

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
        node.querySelector("p, article, main, h1, h2, h3, h4, a[href], img, picture, video, audio, blockquote, pre, code, table, ul, ol, form")) return false;
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

  function stripSourceOwnedArticleActions(root) {
    var sourceOwner = articleActionSourceOwner(root);
    if (!sourceOwner) return root;
    root.querySelectorAll("div, section").forEach(function(node) {
      if (articleActionCluster(node, sourceOwner)) node.remove();
      else if (articleReactionControl(node, sourceOwner)) node.remove();
    });
    root.querySelectorAll("a[href]").forEach(function(node) {
      if (articleNewsFollowControl(node, sourceOwner)) node.remove();
    });
    return root;
  }
