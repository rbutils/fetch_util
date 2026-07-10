  function componentHubCardLinkUrl(card, options) {
    var link = card.querySelector("a[href]");
    var href = (link && link.getAttribute("href")) || (options.dataUrl && options.dataUrl(card)) || "";
    return href ? absoluteUrl(href) : "";
  }

  function componentHubCardItem(card, options) {
    options = options || {};
    var heading = card.querySelector(options.headingSelector || "h2, h3, h4, [heading-text], [class*='title' i], [class*='heading' i]");
    var link = card.querySelector("h2 a[href], h3 a[href], h4 a[href], a[href]");
    var title = normalizeText(
      (heading && heading.getAttribute("heading-text")) ||
      (heading && heading.textContent) ||
      card.getAttribute("heading-text") ||
      card.getAttribute("aria-label") ||
      (link && link.textContent) ||
      ""
    );
    var detailEl = card.querySelector(options.detailSelector || "[content-text], [class*='summary' i], [class*='description' i], [class*='desc' i], [class*='body' i], [class*='text' i], p");
    var detail = normalizeText(
      (detailEl && detailEl.getAttribute("content-text")) ||
      (detailEl && detailEl.textContent) ||
      card.getAttribute("content-text") ||
      ""
    );
    var url = componentHubCardLinkUrl(card, options) || (options.fallbackUrl || location.href);
    var childLinks = Array.prototype.slice.call(card.querySelectorAll(options.childLinkSelector || "ul a[href]")).map(function(sourceLink) {
      var text = normalizeText(sourceLink.textContent || "");
      if (text.length < 3) return null;
      return { text: text, url: absoluteUrl(sourceLink.getAttribute("href")) };
    }).filter(Boolean);

    if (!title || title.length < 3 || title.length > (options.maxTitleLength || 180)) return null;
    if (options.requireDetail && !detail) return null;
    if (options.minCardText && !detail && textLength(card) < options.minCardText) return null;

    return { text: title, url: url, detail: detail, childLinks: childLinks };
  }

  function componentHubItems(root, options) {
    options = options || {};
    var selector = options.cardSelector || "article, .card, [class*='card' i], [class*='teaser' i], [class*='tile' i]";
    var seen = {};
    var items = [];

    Array.prototype.slice.call(root.querySelectorAll(selector)).forEach(function(card) {
      if (options.cardFilter && !options.cardFilter(card)) return;
      var item = componentHubCardItem(card, options);
      var key;
      if (!item) return;
      key = item.text + "|" + (item.url || "");
      if (seen[key]) return;
      seen[key] = true;
      items.push(item);
    });

    return items;
  }

  function componentHubTitle(metadata, root, options) {
    var optionTitle = options && options.title;
    if (typeof optionTitle === "function") return normalizeText(optionTitle(metadata, root) || "");
    return normalizeText(((document.querySelector("h1") || {}).textContent) || optionTitle || metadata.title || document.title || "Items");
  }

  function normalizeComponentHubCards(root, options) {
    options = options || {};
    var selector = options.cardSelector || "article, .card, [class*='card' i], [class*='teaser' i]";
    Array.prototype.slice.call(root.querySelectorAll(selector)).forEach(function(card) {
      if (options.cardFilter && !options.cardFilter(card)) return;
      var item = componentHubCardItem(card, options);
      var article;
      var heading;
      var paragraph;
      var list;

      if (!item) return;
      article = document.createElement("article");
      heading = document.createElement(options.headingTag || "h3");
      if (item.url && item.url !== location.href) {
        var link = document.createElement("a");
        link.setAttribute("href", item.url);
        link.textContent = item.text;
        heading.appendChild(link);
      } else {
        heading.textContent = item.text;
      }
      article.appendChild(heading);

      if (item.detail) {
        paragraph = document.createElement("p");
        paragraph.textContent = item.detail;
        article.appendChild(paragraph);
      }

      if (item.childLinks && item.childLinks.length) {
        list = document.createElement("ul");
        item.childLinks.forEach(function(child) {
          var listItem = document.createElement("li");
          var link = document.createElement("a");
          link.setAttribute("href", child.url);
          link.textContent = child.text;
          listItem.appendChild(link);
          list.appendChild(listItem);
        });
        article.appendChild(list);
      }

      card.replaceWith(article);
    });
  }

  function normalizeComponentHub(metadata, root, options) {
    options = options || {};
    if (!root) return null;

    if (options.contentType === "list") {
      var items = componentHubItems(root, options);
      var title;
      if (items.length < (options.minItems || 3)) return null;
      title = componentHubTitle(metadata, root, options);
      return listItemsContentResult(metadata, {
        title: title,
        excerpt: metadata.excerpt,
        items: items,
        html: cleanClone(root).innerHTML,
        textContent: title + "\n" + listMarkdown(items)
      });
    }

    return institutionalArticleResult(metadata, root, {
      docsLike: options.docsLike,
      minText: options.minText,
      titleRoot: options.titleRoot,
      title: options.title,
      strip: function(clone) {
        normalizeComponentHubCards(clone, options);
        removeAll(clone, COMMON_INSTITUTIONAL_CHROME_SELECTOR + ", [class*='breadcrumb' i], [class*='social' i], [class*='share' i], [class*='embed' i], [class*='newsletter' i], form");
        if (options.strip) options.strip(clone);
      }
    });
  }

  function componentHubCandidates(config) {
    var roots = Array.prototype.slice.call(document.querySelectorAll(config.rootSelector));
    return roots.map(function(root) {
      var contentRoot = config.contentRoot ? config.contentRoot(root) : root;
      var cards = Array.prototype.slice.call(root.querySelectorAll(config.cardSelector || "article, .card, [class*='card' i], [class*='teaser' i], [class*='tile' i]"));
      var items = componentHubItems(root, config);
      var length = textLength(contentRoot || root);
      var score = length + items.length * 400;

      if (!contentRoot) return null;
      if (config.candidateFilter && !config.candidateFilter(root, contentRoot, cards, items, length)) return null;
      if (items.length < (config.minItems || 3)) return null;
      if (config.minText && length < config.minText) return null;
      if (config.score) score = config.score(root, contentRoot, cards, items, length);
      return { root: contentRoot, config: config, score: score };
    }).filter(Boolean);
  }

  function genericInstitutionalComponentHubContent(metadata) {
    var configs = [
      {
        rootSelector: "main [class*='card--with-subsections' i], main [class*='cards--with-subsections' i]",
        contentRoot: function(cardGrid) {
          return cardGrid.closest("main") || cardGrid.closest("[class*='page-content' i]") || cardGrid;
        },
        candidateFilter: function(cardGrid, contentRoot, cards) {
          var usefulCards = cards.filter(function(card) {
            return card.querySelector("h2, h3, h4, a[href]") && textLength(card) >= 60;
          });
          return usefulCards.length >= 4 && textLength(contentRoot) >= 600;
        },
        docsLike: true,
        minText: 500,
        titleRoot: document,
        cardSelector: "[class*='grid__item' i] > .card, [class*='grid__item' i] > [class~='card']",
        headingSelector: "h2, h3, h4, [class*='card__title' i]",
        detailSelector: "[class*='summary' i], p",
        requireDetail: true,
        strip: function(clone) {
          clone.querySelectorAll("[class*='embed' i]").forEach(function(el) { el.remove(); });
        }
      },
      {
        rootSelector: "main .page-document, main [class*='content-area' i], main",
        candidateFilter: function(root, _contentRoot, cards, _items, length) {
          var teasers = cards.filter(function(teaser) {
            return teaser.querySelector("h2, h3, a[href]") && textLength(teaser) >= 80;
          });
          var sectionBlocks = root.querySelectorAll("[class*='block __grid' i], [class*='block heading' i]").length;
          return teasers.length >= 4 && sectionBlocks >= 2 && length >= 1200 && !!root.querySelector("h1");
        },
        score: function(root, _contentRoot, cards, _items, length) {
          var sectionBlocks = root.querySelectorAll("[class*='block __grid' i], [class*='block heading' i]").length;
          return length + cards.length * 500 + sectionBlocks * 150;
        },
        docsLike: true,
        minText: 900,
        titleRoot: document,
        cardSelector: ".block.teaser, [class*='grid-block-teaser' i], [class*='grid-teaser-item' i]",
        headingSelector: "h2, h3, h4",
        detailSelector: "p",
        headingTag: "h2",
        strip: function(clone) {
          clone.querySelectorAll("[class*='cookie' i]").forEach(function(el) { el.remove(); });
        }
      },
      {
        rootSelector: "gui-tile-list, [role='list']",
        candidateFilter: function(root, _contentRoot, cards, items) {
          var customTileRoot = root.tagName && /-/.test(root.tagName.toLowerCase());
          var aemPage = !!document.querySelector(".aem-Grid, [class*='aem-GridColumn'], [data-cmp-data-layer]");
          return items.length >= 3 && (aemPage || customTileRoot || cards.length >= 4);
        },
        score: function(root, _contentRoot, _cards, items) {
          var customTileRoot = root.tagName && /-/.test(root.tagName.toLowerCase());
          var aemPage = !!document.querySelector(".aem-Grid, [class*='aem-GridColumn'], [data-cmp-data-layer]");
          return items.length * 100 + (customTileRoot ? 500 : 0) + (aemPage ? 500 : 0);
        },
        contentType: "list",
        title: function(metadata) {
          return ((document.querySelector("h1") || {}).textContent) || metadata.title || document.title || "Services";
        },
        minItems: 3,
        cardSelector: "gui-tile, [class*='tile' i], article, .card, [class*='card' i], [class*='teaser' i], [class*='tile' i]",
        headingSelector: "gui-tile-heading, [heading-text], [class*='tile-heading' i]",
        detailSelector: "gui-tile-content, [content-text], [class*='tile-content' i]",
        dataUrl: customElementTileDataUrl,
        minCardText: 20,
        minItems: 3
      }
    ];
    var best = null;

    configs.forEach(function(config) {
      componentHubCandidates(config).forEach(function(candidate) {
        if (!best || candidate.score > best.score) best = candidate;
      });
    });

    return best ? normalizeComponentHub(metadata, best.root, best.config) : null;
  }
