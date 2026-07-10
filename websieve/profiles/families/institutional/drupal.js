  function drupalPlatformPage() {
    var signatureInfo = platformSignature(null, [function() {
      var generator = document.querySelector("meta[name='Generator' i], meta[name='generator' i]");
      return normalizeText(generator && generator.getAttribute("content"));
    }]);
    var generatorContent = signatureInfo.signature;
    if (/\bDrupal\b/i.test(generatorContent)) return true;
    if (document.querySelector(".field--name-body, [class*='field--name-' i], [class*='node--type-' i]")) return true;
    return /(?:^|\s)(?:path-[\w-]+|node-[\w-]+)(?:\s|$)/i.test((document.body && document.body.className) || "");
  }

  function drupalInstitutionalContent(metadata) {
    if (!drupalPlatformPage()) return null;

    var candidates = Array.prototype.slice.call(document.querySelectorAll("article[class*='overview' i], article[class*='listing' i], .overview-inner-container, .content-main, main article, section.node--view-mode-full, .node--view-mode-full, [itemprop='articleBody'], .field--name-body, .field--name-field-paragraphs, .field--name-field-entity-block, [class*='field--name-body' i]"));
    var best = null;

    candidates.forEach(function(candidate) {
      var paragraphRoot = candidate.querySelector && candidate.querySelector(".field--name-field-paragraphs");
      if (paragraphRoot && textLength(paragraphRoot) >= 200) candidate = paragraphRoot;

      var length = textLength(candidate);
      var componentCount = candidate.querySelectorAll(".views-element-container, [class*='views-row' i], [class*='view-component' i], [class*='tab-content' i], [class*='blocktab' i], [class*='entity-block' i], [class*='content-link' i], [class*='content-data' i], [class*='block-toggle' i], [class*='field--name-field-entity-block' i], [class*='field--name-field-key-figures' i], [class*='field--name-field-toggle' i], [class*='paragraph--type--cards' i], [class*='card-list' i], [class*='card-heading-list' i], [class*='card-headline' i], [class*='image-besides-text' i], [data-trk*='cards' i]").length;
      var score = length + componentCount * 400;

      if (length < 200) return;
      if (componentCount < 1 && !candidate.matches(".field--name-body, .field--name-field-paragraphs, [class*='field--name-body' i], [itemprop='articleBody']")) return;
      if (!best || score > best.score) best = { root: candidate, score: score, componentCount: componentCount };
    });

    var root = best && best.root;
    if (!root || textLength(root) < 200) return null;

    return normalizeComponentHub(metadata, root, {
      docsLike: best.componentCount >= 2,
      titleRoot: document,
      cardSelector: "article.entity-block.content-link, .card-list article, [class*='card-headline' i], [class*='card' i] article, [class*='paragraph--type--cards' i] .card",
      headingSelector: "h2, h3, h4, [class*='card-headline' i], [class*='title' i]",
      detailSelector: "[class*='field--name-field-desc' i], [class*='field--name-field-body' i], [class*='summary' i], [class*='description' i], p",
      strip: function(clone) {
        removeAll(clone, COMMON_INSTITUTIONAL_CHROME_SELECTOR + ", .side-navigation, [class*='side-navigation' i], [class*='language' i], [class*='breadcrumb' i], .left-column, .sharing, .add-on, [class*='search' i], article.entity-block.content-link .content-desc > a[href], form, .visually-hidden, .hidden");
      }
    });
  }
