  function drupalPlatformPage() {
    var generator = document.querySelector("meta[name='Generator' i], meta[name='generator' i]");
    var generatorContent = normalizeText(generator && generator.getAttribute("content"));
    if (/\bDrupal\b/i.test(generatorContent)) return true;
    if (document.querySelector(".field--name-body, [class*='field--name-' i], [class*='node--type-' i]")) return true;
    return /(?:^|\s)(?:path-[\w-]+|node-[\w-]+)(?:\s|$)/i.test((document.body && document.body.className) || "");
  }

  function institutionalArticleResult(metadata, root, options) {
    options = options || {};
    if (!root || textLength(root) < (options.minText || 200)) return null;

    var clone = options.preserveContentNav ? safeDeepClone(root, document) : cleanClone(root);
    if (options.preserveContentNav) {
      clone.querySelectorAll("nav.contents, nav[class*='contents' i]").forEach(function(nav) {
        var section = document.createElement("section");
        section.innerHTML = nav.innerHTML;
        nav.replaceWith(section);
      });
      cleanupAgentRoot(clone);
      clone.querySelectorAll("a").forEach(function(el) {
        var href = el.getAttribute("href");
        if (href) el.setAttribute("href", absoluteUrl(href));
      });
    }
    if (options.strip) options.strip(clone);

    var markdown = markdownFor(clone.innerHTML);
    var text = normalizeText(markdown || clone.textContent || "");
    if (text.length < (options.minText || 200)) return null;

    var titleRoot = options.titleRoot || document;
    var title = normalizeText(((titleRoot.querySelector("h1") || {}).textContent) || options.title || metadata.title || document.title);
    if (title && !markdownStartsWithTitle(markdown, title)) markdown = "# " + title + "\n\n" + markdown;

    return {
      title: title || metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt || text.slice(0, 280),
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime || null,
      html: clone.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: options.contentType || "article",
      hostAware: true,
      docsLike: !!options.docsLike
    };
  }

  function eurLexDocumentContent(metadata) {
    var root = document.querySelector("#MainContent .EurlexContent #document1") ||
      document.querySelector("#MainContent .EurlexContent #textTabContent") ||
      document.querySelector("#MainContent .EurlexContent #PP1Contents") ||
      document.querySelector("#MainContent .EurlexContent");
    if (!root || !document.querySelector("#MainContent .EurlexContent")) return null;
    if (!document.querySelector("#op-header") && !document.querySelector(".PageShare")) return null;

    return institutionalArticleResult(metadata, root, {
      minText: 300,
      docsLike: true,
      title: normalizeText(((document.querySelector("#MainContent .EurlexContent #PP1Contents #title, #MainContent .EurlexContent #PP1Contents #englishTitle") || {}).textContent) || ""),
      titleRoot: document.querySelector("#MainContent") || document,
      strip: function(clone) {
        clone.querySelectorAll("#translatedTitle.hidden, #originalTitle.hidden, .hidden, .PageShare, .AffixSidebarWrapper").forEach(function(el) { el.remove(); });
      }
    });
  }

  function governmentProgramMicrositeContent(metadata) {
    var root = document.querySelector("main#main-content .group--type--microsite.microsite--type--programs") ||
      document.querySelector("main[role='main'] .group--type--microsite.microsite--type--programs") ||
      document.querySelector("main#main-content .node-intro") ||
      null;
    if (!root) return null;
    if (!document.querySelector(".usa-megamenu, .usa-nav__submenu") && !document.querySelector(".usa-banner")) return null;
    if (!root.querySelector("h1, .microsite-title, .field--name--field-intro, .field--name-field-intro")) return null;

    return institutionalArticleResult(metadata, root, {
      minText: 350,
      titleRoot: root,
      strip: function(clone) {
        clone.querySelectorAll(".group-menu, [class*='group-menu'], .usa-breadcrumb, [id*='breadcrumb' i], .slick-dots, .slick-arrow").forEach(function(el) { el.remove(); });
      }
    });
  }

  function europaServiceLandingContent(metadata) {
    var root = document.querySelector("main#main-content #main-article") ||
      document.querySelector("main#main-content") ||
      document.querySelector("main[role='main']");
    if (!root || !document.querySelector("#feedback-form")) return null;
    if (!document.querySelector("main#main-content") || !root.querySelector("nav.contents, .contents, h1")) return null;
    if (!/\bYour Europe\b/i.test([metadata.siteName || "", metadata.title || "", document.title || "", document.body.textContent || ""].join(" "))) return null;

    return institutionalArticleResult(metadata, root, {
      minText: 150,
      preserveContentNav: true,
      titleRoot: document.querySelector("main#main-content") || root,
      strip: function(clone) {
        clone.querySelectorAll("#feedback-form, [id*='feedback' i], [class*='feedback' i], .share, [id^='sh-']").forEach(function(el) { el.remove(); });
      }
    });
  }

  function standardsRecordContent(metadata) {
    var designation = document.querySelector("#stnd-designation, [id*='standard' i][id*='designation' i], [class*='standard' i][class*='designation' i]");
    var title = document.querySelector("#stnd-title, [id*='standard' i][id*='title' i], [class*='standard' i][class*='title' i]");
    var details = document.querySelector("#standard-details, [id*='standard' i][id*='details' i], [class*='standard' i][class*='details' i]");
    var description = document.querySelector("#stnd-description, [id*='standard' i][id*='description' i], [class*='standard' i][class*='description' i]");
    var titleSection = document.querySelector("#page-title.standard, [class*='standard' i][id*='title' i]");
    var main = document.querySelector("#content.standard #main-content, main #main-content, main");

    if (!designation || !title || !details || !description || !main || !titleSection) return null;

    var root = document.createElement("article");
    if (titleSection) root.appendChild(safeDeepClone(titleSection, document));
    root.appendChild(safeDeepClone(description, document));
    root.appendChild(safeDeepClone(details, document));

    var workingGroup = main.querySelector("#working-group-details");
    if (workingGroup) {
      var workingGroupClone = safeDeepClone(workingGroup, document);
      workingGroupClone.querySelectorAll("#working-group-projects-standards, .tab-content, .nav-tabs, [role='tablist']").forEach(function(el) { el.remove(); });
      root.appendChild(workingGroupClone);
    }

    return institutionalArticleResult(metadata, root, {
      minText: 250,
      title: normalizeText([designation.textContent, title.textContent].join(" - ")),
      strip: function(clone) {
        clone.querySelectorAll("script, style, form, .osano-cm-window, [class*='cookie' i], [class*='newsletter' i]").forEach(function(el) { el.remove(); });
      }
    });
  }

  function legalConventionIndexContent(metadata) {
    var roots = Array.prototype.slice.call(document.querySelectorAll(".page-content .container, main .container, main, .content"));
    var best = null;

    roots.forEach(function(root) {
      var conventionLists = Array.prototype.slice.call(root.querySelectorAll("ul.arrows, ol.arrows, ul, ol")).filter(function(list) {
        var links = Array.prototype.slice.call(list.querySelectorAll("a[href]"));
        if (links.length < 4) return false;
        var conventionLinks = links.filter(function(link) {
          var text = normalizeText(link.textContent || "");
          var href = link.getAttribute("href") || "";
          return /\b(?:convention|protocol|principles?|instrument)\b/i.test(text) && /\b(?:conventions?|instruments?|full-text|specialised-sections)\b/i.test(href);
        });
        return conventionLinks.length >= Math.min(4, links.length);
      });
      var context = normalizeText([root.querySelector("h1, h2") && root.querySelector("h1, h2").textContent, root.textContent].join(" "));
      var score = textLength(root) + conventionLists.length * 1000;

      if (conventionLists.length < 2) return;
      if (!/\bConventions? and (?:other )?Instruments?\b/i.test(context) && !/\bCore Conventions?\b/i.test(context)) return;
      if (!best || score > best.score) best = { root: root, score: score };
    });

    if (!best) return null;

    return institutionalArticleResult(metadata, best.root, {
      docsLike: true,
      minText: 400,
      titleRoot: best.root,
      strip: function(clone) {
        clone.querySelectorAll(".breadcrumb, [class*='breadcrumb' i], .navbar, [class*='nav' i], form, script, style").forEach(function(el) { el.remove(); });
      }
    });
  }

  function drupalInstitutionalContent(metadata) {
    if (!drupalPlatformPage()) return null;

    var candidates = Array.prototype.slice.call(document.querySelectorAll([
      "article[class*='overview' i]",
      "article[class*='listing' i]",
      ".overview-inner-container",
      ".content-main",
      "main article",
      "section.node--view-mode-full",
      ".node--view-mode-full",
      "[itemprop='articleBody']",
      ".field--name-body",
      ".field--name-field-paragraphs",
      ".field--name-field-entity-block",
      "[class*='field--name-body' i]"
    ].join(", ")));
    var best = null;

    candidates.forEach(function(candidate) {
      var paragraphRoot = candidate.querySelector && candidate.querySelector(".field--name-field-paragraphs");
      if (paragraphRoot && textLength(paragraphRoot) >= 200) candidate = paragraphRoot;

      var length = textLength(candidate);
      var componentCount = candidate.querySelectorAll([
        ".views-element-container",
        "[class*='views-row' i]",
        "[class*='view-component' i]",
        "[class*='tab-content' i]",
        "[class*='blocktab' i]",
        "[class*='entity-block' i]",
        "[class*='content-link' i]",
        "[class*='content-data' i]",
        "[class*='block-toggle' i]",
        "[class*='field--name-field-entity-block' i]",
        "[class*='field--name-field-key-figures' i]",
        "[class*='field--name-field-toggle' i]",
        "[class*='paragraph--type--cards' i]",
        "[class*='card-list' i]",
        "[class*='card-heading-list' i]",
        "[class*='card-headline' i]",
        "[class*='image-besides-text' i]",
        "[data-trk*='cards' i]"
      ].join(", ")).length;
      var score = length + componentCount * 400;

      if (length < 200) return;
      if (componentCount < 1 && !candidate.matches(".field--name-body, .field--name-field-paragraphs, [class*='field--name-body' i], [itemprop='articleBody']")) return;
      if (!best || score > best.score) best = { root: candidate, score: score, componentCount: componentCount };
    });

    var root = best && best.root;
    if (!root || textLength(root) < 200) return null;

    return institutionalArticleResult(metadata, root, {
      docsLike: best.componentCount >= 2,
      titleRoot: document,
      strip: function(clone) {
        clone.querySelectorAll([
          ".side-navigation",
          "[class*='side-navigation' i]",
          "[class*='language' i]",
          "[class*='breadcrumb' i]",
          ".left-column",
          ".sharing",
          ".add-on",
          "[class*='search' i]",
          "article.entity-block.content-link .content-desc > a[href]",
          "form",
          "script",
          "style",
          ".visually-hidden",
          ".hidden"
        ].join(", ")).forEach(function(el) { el.remove(); });
      }
    });
  }

  function institutionalTopicCardListContent(metadata) {
    var roots = Array.prototype.slice.call(document.querySelectorAll("[id*='listView' i], [role='list'], [class*='topic' i][class*='list' i], [class*='card' i][class*='grid' i]"));
    var best = null;

    roots.forEach(function(root) {
      var seen = {};
      var items = [];
      var topicishRoot = /topic|taxonomy|listview/i.test((root.id || "") + " " + (root.className || "") + " " + root.getAttribute("data-sf-element"));

      root.querySelectorAll("a[href]").forEach(function(link) {
        if (items.length >= 240) return;
        var href = link.getAttribute("href") || "";
        var url = absoluteUrl(href);
        var title = normalizeText(link.getAttribute("aria-label") || ((link.querySelector("h2, h3, h4") || {}).textContent) || "");
        var paragraphs = Array.prototype.slice.call(link.querySelectorAll("p"));
        var detail = "";

        if (!title && paragraphs.length) title = normalizeText(paragraphs[paragraphs.length - 1].textContent || link.textContent || "");
        if (paragraphs.length > 1) detail = normalizeText(paragraphs[0].textContent || "");
        if (!detail && title) detail = searchItemDetail(link, title);

        if (!title || !url || title.length < 3 || title.length > 180 || seen[url]) return;
        if (!topicishRoot && !/\btopics?\b/i.test(url + " " + title + " " + detail)) return;
        if (/^(home|health topics|topics|news|headlines|menu|search|more)$/i.test(title)) return;

        seen[url] = true;
        items.push({ text: title, url: url, detail: detail });
      });

      if (items.length < 8) return;
      var score = items.length * 100 + (topicishRoot ? 1000 : 0);
      if (!best || score > best.score) best = { root: root, items: items, score: score };
    });

    if (!best) return null;
    var title = normalizeText(((document.querySelector("h1") || {}).textContent) || metadata.title || document.title || "Topics");

    return listContentResult({
      title: title,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      items: best.items,
      html: cleanClone(best.root).innerHTML,
      textContent: title + "\n" + listMarkdown(best.items)
    });
  }

  function institutionalSubsectionCardHubContent(metadata) {
    var cardGrid = document.querySelector("main [class*='card--with-subsections' i], main [class*='cards--with-subsections' i]");
    if (!cardGrid) return null;

    var cards = Array.prototype.slice.call(cardGrid.querySelectorAll("[class*='grid__item' i] > .card, [class*='grid__item' i] > [class~='card']")).filter(function(card) {
      return card.querySelector("h2, h3, h4, a[href]") && textLength(card) >= 60;
    });
    if (cards.length < 4) return null;

    var root = cardGrid.closest("main") || cardGrid.closest("[class*='page-content' i]") || cardGrid;
    if (!root || textLength(root) < 600) return null;

    return institutionalArticleResult(metadata, root, {
      docsLike: true,
      minText: 500,
      titleRoot: document,
      strip: function(clone) {
        clone.querySelectorAll("[class*='card--with-subsections' i] [class*='grid__item' i] > .card, [class*='card--with-subsections' i] [class*='grid__item' i] > [class~='card']").forEach(function(card) {
          var titleLink = card.querySelector("h2 a[href], h3 a[href], h4 a[href], a[href]");
          var title = normalizeText(((card.querySelector("h2, h3, h4") || {}).textContent) || (titleLink && titleLink.textContent) || "");
          var summary = normalizeText(((card.querySelector("[class*='summary' i], p") || {}).textContent) || "");
          if (!title || !summary) return;

          var article = document.createElement("article");
          var heading = document.createElement("h3");
          if (titleLink && titleLink.getAttribute("href")) {
            var link = document.createElement("a");
            link.setAttribute("href", absoluteUrl(titleLink.getAttribute("href")));
            link.textContent = title;
            heading.appendChild(link);
          } else {
            heading.textContent = title;
          }
          article.appendChild(heading);

          var paragraph = document.createElement("p");
          paragraph.textContent = summary;
          article.appendChild(paragraph);

          var subcategoryLinks = Array.prototype.slice.call(card.querySelectorAll("ul a[href]")).filter(function(link) {
            return normalizeText(link.textContent || "").length >= 3;
          });
          if (subcategoryLinks.length) {
            var list = document.createElement("ul");
            subcategoryLinks.forEach(function(sourceLink) {
              var item = document.createElement("li");
              var link = document.createElement("a");
              link.setAttribute("href", absoluteUrl(sourceLink.getAttribute("href")));
              link.textContent = normalizeText(sourceLink.textContent || "");
              item.appendChild(link);
              list.appendChild(item);
            });
            article.appendChild(list);
          }
          card.replaceWith(article);
        });
        clone.querySelectorAll([
          "[class*='breadcrumb' i]",
          "[class*='social' i]",
          "[class*='share' i]",
          "[class*='embed' i]",
          "[class*='newsletter' i]",
          "form",
          "script",
          "style"
        ].join(", ")).forEach(function(el) { el.remove(); });
      }
    });
  }

  function institutionalBlockTeaserHubContent(metadata) {
    var roots = Array.prototype.slice.call(document.querySelectorAll("main .page-document, main [class*='content-area' i], main"));
    var best = null;

    roots.forEach(function(root) {
      var teasers = Array.prototype.slice.call(root.querySelectorAll(".block.teaser, [class*='grid-block-teaser' i], [class*='grid-teaser-item' i]")).filter(function(teaser) {
        return teaser.querySelector("h2, h3, a[href]") && textLength(teaser) >= 80;
      });
      var sectionBlocks = root.querySelectorAll("[class*='block __grid' i], [class*='block heading' i]").length;
      var length = textLength(root);
      var score = length + teasers.length * 500 + sectionBlocks * 150;

      if (teasers.length < 4 || sectionBlocks < 2 || length < 1200) return;
      if (!root.querySelector("h1")) return;
      if (!best || score > best.score) best = { root: root, score: score };
    });

    if (!best) return null;

    return institutionalArticleResult(metadata, best.root, {
      docsLike: true,
      minText: 900,
      titleRoot: document,
      strip: function(clone) {
        clone.querySelectorAll(".block.teaser").forEach(function(teaser) {
          var titleEl = teaser.querySelector("h2, h3, h4");
          var title = normalizeText(titleEl && titleEl.textContent);
          if (!title) return;

          var linkEl = teaser.querySelector("a[href]");
          var summary = normalizeText(((teaser.querySelector("p") || {}).textContent) || "");
          var article = document.createElement("article");
          var heading = document.createElement("h2");
          if (linkEl && linkEl.getAttribute("href")) {
            var link = document.createElement("a");
            link.setAttribute("href", absoluteUrl(linkEl.getAttribute("href")));
            link.textContent = title;
            heading.appendChild(link);
          } else {
            heading.textContent = title;
          }
          article.appendChild(heading);
          if (summary) {
            var paragraph = document.createElement("p");
            paragraph.textContent = summary;
            article.appendChild(paragraph);
          }
          teaser.replaceWith(article);
        });
        clone.querySelectorAll([
          "[class*='breadcrumb' i]",
          "[class*='social' i]",
          "[class*='share' i]",
          "[class*='cookie' i]",
          "form",
          "script",
          "style"
        ].join(", ")).forEach(function(el) { el.remove(); });
      }
    });
  }

  function customElementTileDataUrl(tile) {
    var raw = tile && tile.getAttribute("data-cmp-data-layer");
    var found = "";
    var data;
    if (!raw) return "";

    try {
      data = JSON.parse(raw);
      Object.keys(data).some(function(key) {
        var item = data[key] || {};
        found = item["xdm:linkURL"] || item.linkURL || item.url || "";
        return !!found;
      });
    } catch (_error) {
      found = "";
    }

    return found;
  }

  function institutionalCustomElementTileContent(metadata) {
    var roots = Array.prototype.slice.call(document.querySelectorAll("gui-tile-list, [role='list']"));
    var best = null;
    var aemPage = !!document.querySelector(".aem-Grid, [class*='aem-GridColumn'], [data-cmp-data-layer]");

    roots.forEach(function(root) {
      var tiles = Array.prototype.slice.call(root.querySelectorAll("gui-tile, [class*='tile' i]"));
      var seen = {};
      var items = [];
      var customTileRoot = root.tagName && /-/.test(root.tagName.toLowerCase());

      tiles.forEach(function(tile) {
        if (items.length >= 120) return;

        var heading = tile.querySelector("gui-tile-heading, [heading-text], [class*='tile-heading' i]");
        var content = tile.querySelector("gui-tile-content, [content-text], [class*='tile-content' i]");
        var link = tile.querySelector("a[href]");
        var title = normalizeText((heading && heading.getAttribute("heading-text")) || (heading && heading.textContent) || tile.getAttribute("heading-text") || "");
        var detail = normalizeText((content && content.getAttribute("content-text")) || (content && content.textContent) || tile.getAttribute("content-text") || "");
        var href = (link && link.getAttribute("href")) || customElementTileDataUrl(tile);
        var url = absoluteUrl(href || "");
        var key = title + "|" + (url || "");

        if (!title || title.length < 3 || title.length > 180 || seen[key]) return;
        if (!detail && textLength(tile) < 20) return;

        seen[key] = true;
        items.push({ text: title, url: url || location.href, detail: detail });
      });

      if (items.length < 3) return;
      if (!aemPage && !customTileRoot && tiles.length < 4) return;

      var score = items.length * 100 + (customTileRoot ? 500 : 0) + (aemPage ? 500 : 0);
      if (!best || score > best.score) best = { root: root, items: items, score: score };
    });

    if (!best) return null;
    var title = normalizeText(((document.querySelector("h1") || {}).textContent) || metadata.title || document.title || "Services");

    return listContentResult({
      title: title,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      items: best.items,
      html: cleanClone(best.root).innerHTML,
      textContent: title + "\n" + listMarkdown(best.items)
    });
  }

  function institutionalPlatformContent(metadata) {
    return eurLexDocumentContent(metadata) ||
      governmentProgramMicrositeContent(metadata) ||
      europaServiceLandingContent(metadata) ||
      standardsRecordContent(metadata) ||
      legalConventionIndexContent(metadata) ||
      drupalInstitutionalContent(metadata) ||
      institutionalSubsectionCardHubContent(metadata) ||
      institutionalBlockTeaserHubContent(metadata) ||
      institutionalCustomElementTileContent(metadata) ||
      institutionalTopicCardListContent(metadata);
  }
