  function leadActionText(text) {
    return /^(?:read|learn|see) more$/i.test(normalizeText(text || ""));
  }

  function leadVisibleClone(node) {
    if (!node || elementSubtreeHidden(node)) return null;
    var clone = visibilityPrunedClone(node, document);
    var text = normalizeText(clone.textContent || "");
    var media = clone.querySelector("img[src], picture source[srcset], video[src], svg");
    return text || media ? clone : null;
  }

  function leadCardNode(link) {
    return link.closest("article, li, [class*='card'], [class*='tile'], [class*='item'], [class*='listing'], [class*='result'], [class*='destination'], [class*='route'], [class*='story']");
  }

  function leadActionHeading(link) {
    if (!materializedHttpUrl(link.getAttribute("href") || "")) return "";
    var card = leadCardNode(link);
    if (!card) return "";

    var destinations = {};
    Array.prototype.forEach.call(card.querySelectorAll("a[href]"), function(candidate) {
      if (!leadVisibleClone(candidate)) return;
      var href = candidate.getAttribute("href") || "";
      var url = materializedHttpUrl(href);
      if (url) destinations[homepageCanonicalUrl(url)] = true;
    });
    if (Object.keys(destinations).length !== 1) return "";

    var title = "";
    Array.prototype.some.call(card.querySelectorAll("h1, h2, h3, h4"), function(heading) {
      var visibleHeading = leadVisibleClone(heading);
      title = normalizeText((visibleHeading && visibleHeading.textContent) || "");
      return !!title;
    });
    return title;
  }

  function leadTitle(link) {
    if (!link || elementSubtreeHidden(link)) return "";
    if (link.closest("header, nav, footer, aside, form, [role='navigation'], [role='banner'], [role='contentinfo']")) return "";

    var href = link.getAttribute("href") || "";
    var visibleLink = visibilityPrunedClone(link, document);
    var titleNode = visibleLink && visibleLink.querySelector("h1, h2, h3, h4");
    var accessibleTitle = elementVisuallyHidden(link) ? "" : link.getAttribute("aria-label");
    var title = normalizeText((titleNode && titleNode.textContent) || (visibleLink && visibleLink.textContent) || accessibleTitle || "");
    if (leadActionText(title)) title = leadActionHeading(link);
    if (rejectedHomepageLeadText(title, href)) return "";
    if (title.length < 12 && !/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u.test(title)) return "";
    return title;
  }

  function homepageLeadResourceLabel(node, fallback) {
    return normalizeText(
      (node && (node.getAttribute("alt") || node.getAttribute("aria-label") || node.getAttribute("title"))) ||
      fallback || ""
    ).replace(/[\[\]]/g, "");
  }

  function homepageLeadResource(markdown, seen, type, label, value) {
    var url = materializedHttpUrl(value || "");
    var key = type + "\n" + url;
    if (!url || seen[key]) return;
    seen[key] = true;
    markdown.push((type === "image" ? "!" : "") + "[" + label + "](" + url + ")");
  }

  function homepageLeadSrcset(markdown, seen, label, value) {
    srcsetCandidates(value).forEach(function(candidate) {
      if (!validSrcsetDescriptor(candidate.descriptor)) return;
      homepageLeadResource(markdown, seen, "image", label, candidate.url);
    });
  }

  function homepageLeadResourceVisible(node, owner, sourceClones) {
    if (!sourceClones) return true;
    if (!node) return false;

    for (var current = node; current; current = current.parentElement) {
      if (current.hasAttribute("hidden") || current.hasAttribute("inert") || current.getAttribute("aria-hidden") === "true") return false;
      if (current.classList && current.classList.contains("hidden")) return false;
      var style = current.style;
      if (style && (style.display === "none" || /^(?:hidden|collapse)$/.test(style.visibility) || Number(style.opacity) === 0)) return false;
      if (current !== owner) continue;
      if (!sourceClones || node.tagName === "SOURCE" || sourceClones.get(node)) return true;
      if (elementVisuallyHidden(node)) return false;
      var computed = window.getComputedStyle ? window.getComputedStyle(node) : null;
      return !horizontallyClippedElement(node, computed, ancestorHorizontalClipBounds(node));
    }
    return false;
  }

  function homepageLeadImageResources(markdown, seen, image, fallbackLabel, owner, sourceClones) {
    if (!homepageLeadResourceVisible(image, owner, sourceClones)) return;
    var label = homepageLeadResourceLabel(image, fallbackLabel);
    ["src", "data-src", "data-lazy-src"].forEach(function(attribute) {
      homepageLeadResource(markdown, seen, "image", label, image.getAttribute(attribute));
    });
    ["srcset", "data-srcset", "data-lazy-srcset"].forEach(function(attribute) {
      homepageLeadSrcset(markdown, seen, label, image.getAttribute(attribute));
    });
  }

  function homepageLeadMediaMarkdown(media, fallbackLabel, sourceClones) {
    var markdown = [];
    var seen = {};

    media.forEach(function(candidate) {
      if (candidate.tagName === "PICTURE") {
        var pictureImage = candidate.querySelector("img");
        var pictureLabel = homepageLeadResourceLabel(pictureImage, fallbackLabel);
        Array.prototype.forEach.call(candidate.querySelectorAll("source, img"), function(resource) {
          homepageLeadImageResources(markdown, seen, resource, pictureLabel, candidate, sourceClones);
        });
      } else if (candidate.tagName === "IMG") {
        homepageLeadImageResources(markdown, seen, candidate, fallbackLabel, candidate, sourceClones);
      } else if (candidate.tagName === "VIDEO") {
        var videoLabel = homepageLeadResourceLabel(candidate, "Video");
        ["poster", "data-poster"].forEach(function(attribute) {
          homepageLeadResource(markdown, seen, "image", videoLabel, candidate.getAttribute(attribute));
        });
        ["src", "data-src", "data-lazy-src"].forEach(function(attribute) {
          homepageLeadResource(markdown, seen, "link", videoLabel, candidate.getAttribute(attribute));
        });
        Array.prototype.forEach.call(candidate.querySelectorAll("source"), function(source) {
          if (!homepageLeadResourceVisible(source, candidate, sourceClones)) return;
          ["src", "data-src", "data-lazy-src"].forEach(function(attribute) {
            homepageLeadResource(markdown, seen, "link", videoLabel, source.getAttribute(attribute));
          });
        });
      } else {
        var svgLabel = homepageLeadResourceLabel(candidate, fallbackLabel);
        Array.prototype.forEach.call(candidate.querySelectorAll("image"), function(image) {
          if (image.matches("[hidden], [inert], [aria-hidden='true'], .hidden")) return;
          if (!homepageLeadResourceVisible(image, candidate, sourceClones)) return;
          ["href", "xlink:href"].forEach(function(attribute) {
            homepageLeadResource(
              markdown,
              seen,
              "image",
              homepageLeadResourceLabel(image, svgLabel),
              image.getAttribute(attribute)
            );
          });
        });
      }
    });
    return markdown.join(" ");
  }

  function homepageLeadTopMedia(node) {
    return Array.prototype.filter.call(
      node.querySelectorAll("picture, img[src], img[srcset], img[data-src], img[data-srcset], img[data-lazy-src], img[data-lazy-srcset], video, svg"),
      function(candidate) {
        var owner = candidate.closest && candidate.closest("picture, video, svg");
        return !owner || owner === candidate || !node.contains(owner);
      }
    );
  }

  function cleanupHomepageLeadMediaClone(node) {
    node.querySelectorAll("[hidden], [inert], [aria-hidden='true'], .hidden").forEach(function(descendant) {
      descendant.remove();
    });
    Array.prototype.slice.call(node.querySelectorAll("*")).forEach(function(descendant) {
      var style = descendant.style;
      if (
        descendant.hasAttribute("hidden") ||
        descendant.hasAttribute("inert") ||
        descendant.getAttribute("aria-hidden") === "true" ||
        (descendant.classList && descendant.classList.contains("hidden")) ||
        (style && (style.display === "none" || /^(?:hidden|collapse)$/.test(style.visibility) || Number(style.opacity) === 0))
      ) descendant.remove();
    });
  }

  function preserveHomepageLeadTitleMedia(node, sourceNode, sourceClones) {
    if (!node || !node.parentNode) return "";

    var clonedMedia = homepageLeadTopMedia(node);
    var sourceMedia = sourceNode && sourceClones ? homepageLeadTopMedia(sourceNode).filter(function(candidate) {
      if (homepageLeadResourceVisible(candidate, candidate, sourceClones)) return true;
      return Array.prototype.some.call(candidate.querySelectorAll("img, video, svg"), function(descendant) {
        return homepageLeadResourceVisible(descendant, candidate, sourceClones);
      });
    }) : [];
    var markdown = homepageLeadMediaMarkdown(
      sourceMedia.length ? sourceMedia : clonedMedia,
      normalizeText(node.textContent || ""),
      sourceMedia.length ? sourceClones : null
    );
    clonedMedia.forEach(function(candidate) {
      cleanupHomepageLeadMediaClone(candidate);
      node.parentNode.insertBefore(candidate, node);
    });
    return markdown;
  }
