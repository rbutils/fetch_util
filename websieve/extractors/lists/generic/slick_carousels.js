  function slickCarouselClass(node, token) {
    return !!(node && node.classList && node.classList.contains(token));
  }

  function slickCarouselDirectChild(node, token) {
    var matches = Array.from(node ? node.children : []).filter(function(child) {
      return slickCarouselClass(child, token);
    });
    return matches.length === 1 ? matches[0] : null;
  }

  function slickCarouselInlineHidden(node) {
    var current = node;
    while (current && current.nodeType === 1) {
      if (current.hasAttribute("hidden") || current.hasAttribute("inert")) return true;
      var style = normalizeText(current.getAttribute("style")).toLowerCase();
      if (/(?:^|;)\s*(?:display\s*:\s*none|visibility\s*:\s*hidden|content-visibility\s*:\s*hidden)(?:\s*!important)?\s*(?:;|$)/.test(style)) {
        return true;
      }
      current = current.parentElement;
    }
    return false;
  }

  function slickCarouselComputedHardHidden(node) {
    if (!node) return true;
    try {
      var style = getComputedStyle(node);
      return style.display === "none" || style.visibility === "hidden" || style.visibility === "collapse" ||
        style.contentVisibility === "hidden";
    } catch (_error) {
      return true;
    }
  }

  function slickCarouselRuntimeLayout(list, track) {
    try {
      var listStyle = getComputedStyle(list);
      var trackStyle = getComputedStyle(track);
      var overflow = normalizeText(listStyle.overflowX || listStyle.overflow).toLowerCase();
      var transform = normalizeText(trackStyle.transform).toLowerCase();
      var bounds = list.getBoundingClientRect();
      return /^(?:hidden|clip)$/.test(overflow) && transform && transform !== "none" &&
        bounds.width > 0 && bounds.height > 0;
    } catch (_error) {
      return false;
    }
  }

  function slickCarouselFieldHidden(node, slide) {
    var current = node;
    while (current && current !== slide) {
      if (current.hasAttribute("hidden") || current.hasAttribute("inert") ||
          normalizeText(current.getAttribute("aria-hidden")).toLowerCase() === "true" ||
          slickCarouselComputedHardHidden(current)) return true;
      var style = normalizeText(current.getAttribute("style")).toLowerCase();
      if (/(?:^|;)\s*(?:display\s*:\s*none|visibility\s*:\s*hidden|content-visibility\s*:\s*hidden)(?:\s*!important)?\s*(?:;|$)/.test(style)) {
        return true;
      }
      current = current.parentElement;
    }
    return current !== slide;
  }

  function slickCarouselSameOrigin(url) {
    try {
      return new URL(url).origin === location.origin;
    } catch (_error) {
      return false;
    }
  }

  function slickCarouselSlideRecord(slide) {
    if (!slide || slide.querySelector("button, input, select, textarea, form, [contenteditable='true']")) return null;
    var anchors = Array.from(slide.querySelectorAll("a[href]")).filter(function(anchor) {
      return !slickCarouselFieldHidden(anchor, slide);
    });
    if (!anchors.length) return null;
    var urls = [];
    var canonicalUrls = new Set();
    var titles = [];
    var titleValues = new Set();
    for (var i = 0; i < anchors.length; i += 1) {
      var url = materializedHttpUrl(anchors[i].href);
      if (!url || !slickCarouselSameOrigin(url)) return null;
      var canonicalUrl = listCanonicalKey(url);
      if (!canonicalUrls.has(canonicalUrl)) {
        canonicalUrls.add(canonicalUrl);
        urls.push(url);
      }
      var text = normalizeText(anchors[i].textContent);
      if (text && !titleValues.has(text)) {
        titleValues.add(text);
        titles.push(text);
      }
    }
    if (urls.length !== 1 || titles.length !== 1 || titles[0].length < 12 || titles[0].length > 320) return null;
    var images = Array.from(slide.querySelectorAll("img[src], img[srcset], picture img")).filter(function(image) {
      return !slickCarouselFieldHidden(image, slide);
    });
    if (images.length !== 1) return null;
    return {title: titles[0], text: titles[0], url: urls[0], detail: "", card: slide, sourceNode: slide};
  }

  function slickCarouselCollection(root) {
    if (!slickCarouselClass(root, "slick-slider") || !slickCarouselClass(root, "slick-initialized")) return null;
    if (slickCarouselInlineHidden(root) || slickCarouselComputedHardHidden(root) || elementVisuallyHidden(root)) return null;
    var list = slickCarouselDirectChild(root, "slick-list");
    var track = list && slickCarouselDirectChild(list, "slick-track");
    if (!list || !track || !slickCarouselClass(list, "draggable") || !slickCarouselRuntimeLayout(list, track)) return null;
    var slides = Array.from(track.children).filter(function(child) {
      return slickCarouselClass(child, "slick-slide");
    });
    if (slides.length !== track.children.length) return null;
    var originals = slides.filter(function(slide) { return !slickCarouselClass(slide, "slick-cloned"); });
    var clones = slides.filter(function(slide) { return slickCarouselClass(slide, "slick-cloned"); });
    if (originals.length < 4 || clones.length < 2) return null;
    var firstOriginalPosition = slides.indexOf(originals[0]);
    var lastOriginalPosition = slides.indexOf(originals[originals.length - 1]);
    if (firstOriginalPosition < 1 || lastOriginalPosition !== firstOriginalPosition + originals.length - 1 ||
        lastOriginalPosition >= slides.length - 1) return null;
    if (slides.slice(0, firstOriginalPosition).some(function(slide) {
      return !slickCarouselClass(slide, "slick-cloned") || Number(slide.getAttribute("data-slick-index")) >= 0;
    }) || slides.slice(firstOriginalPosition, lastOriginalPosition + 1).some(function(slide) {
      return slickCarouselClass(slide, "slick-cloned");
    }) || slides.slice(lastOriginalPosition + 1).some(function(slide) {
      return !slickCarouselClass(slide, "slick-cloned") ||
        Number(slide.getAttribute("data-slick-index")) < originals.length;
    })) return null;
    var records = [];
    var originalUrls = new Set();
    var originalTitles = new Set();
    var activeCount = 0;
    var inactiveStarted = false;
    for (var i = 0; i < originals.length; i += 1) {
      if (Number(originals[i].getAttribute("data-slick-index")) !== i || slickCarouselInlineHidden(originals[i]) ||
          slickCarouselComputedHardHidden(originals[i])) return null;
      var active = slickCarouselClass(originals[i], "slick-active") &&
        normalizeText(originals[i].getAttribute("aria-hidden")).toLowerCase() === "false";
      var inactive = !slickCarouselClass(originals[i], "slick-active") &&
        normalizeText(originals[i].getAttribute("aria-hidden")).toLowerCase() === "true";
      if (!active && !inactive) return null;
      if (active) {
        if (inactiveStarted) return null;
        activeCount += 1;
      } else {
        inactiveStarted = true;
      }
      var record = slickCarouselSlideRecord(originals[i]);
      if (!record) return null;
      var canonicalUrl = listCanonicalKey(record.url);
      if (originalUrls.has(canonicalUrl) || originalTitles.has(record.title)) return null;
      originalUrls.add(canonicalUrl);
      originalTitles.add(record.title);
      records.push(record);
    }
    if (activeCount < 3 || activeCount >= records.length) return null;
    var leadingClone = false;
    var trailingClone = false;
    for (var j = 0; j < clones.length; j += 1) {
      var index = Number(clones[j].getAttribute("data-slick-index"));
      if (!Number.isInteger(index) || (index >= 0 && index < records.length)) return null;
      if (slickCarouselInlineHidden(clones[j]) || slickCarouselComputedHardHidden(clones[j])) return null;
      leadingClone = leadingClone || index < 0;
      trailingClone = trailingClone || index >= records.length;
      var cloneRecord = slickCarouselSlideRecord(clones[j]);
      var originalIndex = ((index % records.length) + records.length) % records.length;
      var expected = records[originalIndex];
      if (!cloneRecord || listCanonicalKey(cloneRecord.url) !== listCanonicalKey(expected.url) ||
          cloneRecord.title !== expected.title) return null;
    }
    if (!leadingClone || !trailingClone) return null;
    return {root: root, records: records, representedCount: activeCount};
  }

  function materializedSlickCarouselCollections(root) {
    var candidates = [];
    if (root.matches && root.matches(".slick-slider.slick-initialized")) candidates.push(root);
    candidates = candidates.concat(Array.from(root.querySelectorAll(".slick-slider.slick-initialized")));
    return candidates.map(slickCarouselCollection).filter(Boolean);
  }

  function unambiguousSlickCarouselCollections(collections) {
    var urls = new Set();
    for (var i = 0; i < collections.length; i += 1) {
      for (var j = 0; j < collections[i].records.length; j += 1) {
        var url = listCanonicalKey(collections[i].records[j].url);
        if (urls.has(url)) return [];
        urls.add(url);
      }
    }
    return collections;
  }

  function slickCarouselMarkdownUrlLines(lines) {
    var urlLines = Object.create(null);
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
      var line = lines[lineIndex];
      for (var position = 0; position < line.length; position += 1) {
        var link = inlineMarkdownLinkAt(line, position);
        if (!link) continue;
        var url = materializedHttpUrl(link.url);
        if (url) {
          var key = listCanonicalKey(url);
          if (!urlLines[key]) urlLines[key] = {lines: new Set(), labels: Object.create(null)};
          urlLines[key].lines.add(lineIndex);
          if (!link.image) {
            if (!urlLines[key].labels[lineIndex]) urlLines[key].labels[lineIndex] = new Set();
            urlLines[key].labels[lineIndex].add(normalizeText(link.label));
          }
        }
        position = link.end - 1;
      }
    }
    return urlLines;
  }

  function slickCarouselMarkdownPlan(urlLines, collection) {
    var records = collection.records;
    var representedCount = collection.representedCount;
    var representedLines = [];
    for (var i = 0; i < representedCount; i += 1) {
      var matching = urlLines[listCanonicalKey(records[i].url)];
      if (!matching || matching.lines.size !== 1) return null;
      var matchingLine = Array.from(matching.lines)[0];
      var labels = matching.labels[matchingLine];
      if ((representedLines.length && matchingLine <= representedLines[representedLines.length - 1]) || !labels ||
          !labels.has(normalizeText(records[i].title))) return null;
      representedLines.push(matchingLine);
    }
    var missing = records.slice(representedCount);
    if (!missing.length) return null;
    for (var j = 0; j < missing.length; j += 1) {
      if (urlLines[listCanonicalKey(missing[j].url)]) return null;
    }
    return {afterLine: representedLines[representedLines.length - 1], records: missing};
  }

  function listMarkdownWithMaterializedSlickCarousels(root, currentMarkdown) {
    var collections = unambiguousSlickCarouselCollections(materializedSlickCarouselCollections(root));
    if (!collections.length) return null;
    var lines = String(currentMarkdown || "").split("\n");
    var urlLines = slickCarouselMarkdownUrlLines(lines);
    var plans = [];
    for (var i = 0; i < collections.length; i += 1) {
      var plan = slickCarouselMarkdownPlan(urlLines, collections[i]);
      if (!plan) continue;
      if (plans.length && plan.afterLine <= plans[plans.length - 1].afterLine) return null;
      plans.push(plan);
    }
    for (var j = plans.length - 1; j >= 0; j -= 1) {
      lines.splice(plans[j].afterLine + 1, 0, listMarkdown(plans[j].records));
    }
    return plans.length ? lines.join("\n") : null;
  }
