  function articleCarouselFamily(root) {
    var tokens = (root.getAttribute("class") || "").split(/\s+/).filter(Boolean);
    var families = [
      ["keen-slider", "keen-slider__slide"],
      ["swiper-wrapper", "swiper-slide"],
      ["slick-track", "slick-slide"],
      ["splide__list", "splide__slide"],
      ["glide__slides", "glide__slide"],
      ["carousel-track", "carousel-slide"]
    ];
    return families.find(function(family) { return tokens.indexOf(family[0]) !== -1; }) || null;
  }

  function articleCarouselInactiveState(node) {
    var ariaHidden = normalizeText(node.getAttribute("aria-hidden") || "").toLowerCase();
    var ariaDisabled = normalizeText(node.getAttribute("aria-disabled") || "").toLowerCase();
    var ariaSelected = normalizeText(node.getAttribute("aria-selected") || "").toLowerCase();
    var ariaExpanded = normalizeText(node.getAttribute("aria-expanded") || "").toLowerCase();
    return node.hidden || node.hasAttribute("inert") || node.hasAttribute("disabled") ||
      ariaHidden === "true" || ariaDisabled === "true" || ariaSelected === "false" ||
      ariaExpanded === "false" || /^(?:closed|inactive|disabled)$/i.test(node.getAttribute("data-state") || "");
  }

  function articleCarouselUnavailable(node, root) {
    if (elementVisuallyHiddenWithin(node, root)) return true;
    for (var current = node; current && current !== root; current = current.parentElement) {
      if (articleCarouselInactiveState(current)) return true;
      var roles = normalizeText(current.getAttribute("role") || "").toLowerCase().split(/\s+/);
      if (roles.some(function(role) { return /^(?:dialog|menu|navigation|tab|tablist|tabpanel)$/.test(role); })) return true;
    }
    return false;
  }

  function articleCarouselExcludedContext(root) {
    for (var current = root; current && current !== document.body; current = current.parentElement) {
      if (current.matches("nav, header, footer, aside, [role='navigation'], [role='complementary']")) return true;
      var identity = normalizeText((current.id || "") + " " + (current.getAttribute("class") || "")).toLowerCase();
      if (/(?:^|[\s_-])(?:related|recommend(?:ation|ed)?|more[-_ ]like[-_ ]this|similar(?:[-_ ]articles?)?|read[-_ ]next|further[-_ ]reading|you[-_ ]may[-_ ]also[-_ ]like)(?:[\s_-]|$)/.test(identity)) return true;
      if (current.matches("article, main")) break;
    }
    return false;
  }

  function articleCarouselInteractive(node) {
    var selector = "a[href], button, form, input, select, textarea, summary, audio, video, iframe, embed, object, " +
      "[role='button'], [contenteditable]:not([contenteditable='false']), [tabindex]:not([tabindex='-1'])";
    return node.matches(selector) || !!node.querySelector(selector);
  }

  function articleCarouselRecordValues(node, unavailable) {
    if (articleCarouselInteractive(node)) return null;
    var images = Array.prototype.filter.call(node.querySelectorAll("img[src]"), function(image) {
      return !unavailable(image) && !!materializedHttpUrl(image.getAttribute("src"));
    });
    if (images.length !== 1) return null;

    var titleNodes = Array.prototype.filter.call(node.querySelectorAll("h1, h2, h3, h4, [role='heading']"), function(title) {
      return !unavailable(title) && !!normalizeText(title.textContent || "");
    });
    var paragraphs = Array.prototype.filter.call(node.querySelectorAll("p"), function(paragraph) {
      return !unavailable(paragraph) && !!normalizeText(paragraph.textContent || "");
    });
    var title;
    var descriptions;
    if (titleNodes.length === 1) {
      title = normalizeText(titleNodes[0].textContent || "");
      descriptions = paragraphs.map(function(paragraph) { return normalizeText(paragraph.textContent || ""); });
    } else if (!titleNodes.length && paragraphs.length === 2) {
      title = normalizeText(paragraphs[0].textContent || "");
      descriptions = [normalizeText(paragraphs[1].textContent || "")];
    } else return null;

    var description = normalizeText(descriptions.join(" "));
    var imageUrl = materializedHttpUrl(images[0].getAttribute("src"));
    if (title.length < 3 || title.length > 120 || description.length < 60 || description.length > 1200 || !imageUrl) return null;
    return { title: title, description: description, imageUrl: imageUrl };
  }

  function articleCarouselRecord(node, root, slideToken) {
    var tokens = (node.getAttribute("class") || "").split(/\s+/).filter(Boolean);
    if (tokens.indexOf(slideToken) === -1 || tokens.indexOf("slick-cloned") !== -1 ||
        tokens.indexOf("swiper-slide-duplicate") !== -1 || articleCarouselUnavailable(node, root) ||
        node.querySelector("article")) return null;
    var values = articleCarouselRecordValues(node, function(candidate) {
      return articleCarouselUnavailable(candidate, root);
    });
    return values && Object.assign({ node: node }, values);
  }

  function articleCarouselRecords(root) {
    var family = articleCarouselFamily(root);
    var owner = root.closest("article, main");
    if (!family || !owner || articleCarouselInteractive(root) || articleCarouselUnavailable(root, owner.parentElement) ||
        articleCarouselExcludedContext(root)) return [];
    var children = Array.prototype.slice.call(root.children || []);
    if (children.length < 4) return [];
    var records = children.map(function(child) { return articleCarouselRecord(child, root, family[1]); });
    if (records.some(function(record) { return !record; })) return [];
    var keys = new Set();
    var imageUrls = new Set();
    if (records.some(function(record) {
      var key = JSON.stringify([record.title, record.imageUrl]);
      if (keys.has(key) || imageUrls.has(record.imageUrl)) return true;
      keys.add(key);
      imageUrls.add(record.imageUrl);
      return false;
    })) return [];
    return records;
  }

  function articleCarouselDetachedUnavailable(node, boundary) {
    for (var current = node; current && current !== boundary; current = current.parentElement) {
      if (articleCarouselInactiveState(current)) return true;
      var roles = normalizeText(current.getAttribute("role") || "").toLowerCase().split(/\s+/);
      if (roles.some(function(role) { return /^(?:dialog|menu|navigation|tab|tablist|tabpanel)$/.test(role); })) return true;
      if (current.style && (current.style.display === "none" || current.style.visibility === "hidden" ||
          current.style.visibility === "collapse" ||
          (current.style.opacity !== "" && Number(current.style.opacity) === 0))) return true;
      var identity = normalizeText((current.id || "") + " " + (current.getAttribute("class") || "")).toLowerCase();
      if (/(?:^|[\s_-])(?:related|recommend(?:ation|ed)?|more[-_ ]like[-_ ]this|similar(?:[-_ ]articles?)?|read[-_ ]next|further[-_ ]reading|you[-_ ]may[-_ ]also[-_ ]like)(?:[\s_-]|$)/.test(identity)) return true;
    }
    return false;
  }

  function articleCarouselSelectedRecordMatches(node, record, boundary) {
    if (!node || articleCarouselDetachedUnavailable(node, boundary)) return false;
    var values = articleCarouselRecordValues(node, function(candidate) {
      return articleCarouselDetachedUnavailable(candidate, boundary);
    });
    return !!values && values.title === record.title && values.description === record.description &&
      values.imageUrl === record.imageUrl;
  }

  function articleCarouselSelectedContainer(container, records, selectedImages) {
    var images = [];
    var missing = false;
    for (var index = 0; index < records.length; index += 1) {
      var matches = selectedImages.get(records[index].imageUrl) || [];
      if (matches.length > 1 || (missing && matches.length)) return null;
      if (!matches.length) {
        missing = true;
        continue;
      }
      images.push(matches[0]);
    }
    if (images.length < 3 || images.length >= records.length) return null;

    var range = document.createRange();
    range.setStartBefore(images[0]);
    range.setEndAfter(images[images.length - 1]);
    var parent = range.commonAncestorContainer;
    if (parent.nodeType !== 1) parent = parent.parentElement;
    if (!parent || parent === container || parent.children.length !== images.length ||
        articleCarouselDetachedUnavailable(parent, container)) return null;

    var children = images.map(function(image) {
      var child = image;
      while (child && child.parentElement !== parent) child = child.parentElement;
      return child;
    });
    if (new Set(children).size !== images.length) return null;
    if (!children.every(function(child, childIndex) {
      return child && parent.children[childIndex] === child &&
        articleCarouselSelectedRecordMatches(child, records[childIndex], parent);
    })) return null;
    return { parent: parent, represented: images.length };
  }

  function supplementOwnedArticleCarousels(content) {
    if (!content || !content.readerMode || content.contentType !== "article" || content.hostAware ||
        content.docsLike || content.legalProvision || !content.html) return content;
    var selected = document.createElement("div");
    selected.innerHTML = content.html;
    var changed = false;
    var selectedImages = new Map();
    Array.prototype.forEach.call(selected.querySelectorAll("img[src]"), function(image) {
      var url = materializedHttpUrl(image.getAttribute("src"));
      if (!url) return;
      var matches = selectedImages.get(url) || [];
      matches.push(image);
      selectedImages.set(url, matches);
    });
    var entries = Array.prototype.map.call(document.querySelectorAll(
      "[class~='keen-slider'], [class~='swiper-wrapper'], [class~='slick-track'], " +
      "[class~='splide__list'], [class~='glide__slides'], [class~='carousel-track']"
    ), function(root) {
      var records = articleCarouselRecords(root);
      return records.length ? { records: records } : null;
    }).filter(Boolean);
    var sourceImageCounts = new Map();
    entries.forEach(function(entry) {
      entry.records.forEach(function(record) {
        sourceImageCounts.set(record.imageUrl, (sourceImageCounts.get(record.imageUrl) || 0) + 1);
      });
    });

    entries.forEach(function(entry) {
      var records = entry.records;
      if (records.some(function(record) { return sourceImageCounts.get(record.imageUrl) !== 1; })) return;
      var target = articleCarouselSelectedContainer(selected, records, selectedImages);
      if (!target) return;
      var additions = records.slice(target.represented).map(function(record) {
        var clone = safeDeepClone(record.node, document);
        if (clone) pruneHiddenClone(record.node, clone, [record.node]);
        var cleaned = clone && cleanClone(clone);
        return cleaned && articleCarouselSelectedRecordMatches(cleaned, record, null) ? cleaned : null;
      });
      if (additions.some(function(addition) { return !addition; })) return;
      additions.forEach(function(addition) { target.parent.appendChild(addition); });
      changed = true;
    });

    if (!changed) return content;
    return Object.assign({}, content, {
      html: selected.innerHTML,
      textContent: normalizeText(selected.textContent || "")
    });
  }
