  function articleResourceOwner(content) {
    var selected = document.createElement("div");
    selected.innerHTML = content.html || "";
    var evidence = Array.prototype.map.call(selected.querySelectorAll("p"), function(paragraph) {
      return normalizeText(paragraph.textContent || "");
    }).filter(function(text) { return text.length >= 80; });
    if (normalizeText(selected.textContent || "").length < 500 || evidence.length < 2) return null;

    evidence = [evidence[0], evidence[evidence.length - 1]];
    var candidates = Array.prototype.filter.call(document.querySelectorAll("article, main, [role='main']"), function(owner) {
      if (elementSubtreeHidden(owner) || normalizeText(owner.textContent || "").length < 500) return false;
      var paragraphs = new Set(Array.prototype.map.call(owner.querySelectorAll("p"), function(paragraph) {
        return normalizeText(paragraph.textContent || "");
      }));
      return evidence.every(function(text) { return paragraphs.has(text); });
    });
    candidates = candidates.filter(function(candidate) {
      return !candidates.some(function(other) { return other !== candidate && candidate.contains(other); });
    });
    return candidates.length === 1 ? candidates[0] : null;
  }

  function articleResourceNodeHardHidden(node, cache) {
    if (cache.has(node)) return cache.get(node);
    var hardHidden = node.matches("[hidden], [inert], [aria-hidden='true']") ||
      /^(template|noscript)$/.test(node.localName || "") ||
      (node.localName === "details" && !node.hasAttribute("open"));
    if (!hardHidden && window.getComputedStyle) {
      try {
        var style = window.getComputedStyle(node);
        hardHidden = style.display === "none" || style.contentVisibility === "hidden";
      } catch (_error) {
        hardHidden = true;
      }
    }
    cache.set(node, hardHidden);
    return hardHidden;
  }

  function articleResourceContainer(node, owner, hiddenCache) {
    if (!node || !owner.contains(node)) return false;
    if (node.closest("nav, header, footer, aside, form, dialog, menu, [role='navigation'], [role='menu'], [role='toolbar'], [role='dialog'], [role='contentinfo']")) return false;
    var current = node;
    var explicit = false;
    while (current && current !== owner) {
      if (articleResourceNodeHardHidden(current, hiddenCache)) return false;
      var signal = normalizeText([
        current.id || "", current.getAttribute && current.getAttribute("class") || "", current.getAttribute && current.getAttribute("role") || "",
        current.getAttribute && current.getAttribute("aria-label") || "", current.getAttribute && current.getAttribute("data-component") || "",
        current.getAttribute && current.getAttribute("data-testid") || "", current.getAttribute && current.getAttribute("data-section") || ""
      ].join(" ")).toLowerCase();
      if (/(?:^|[\s_-])(?:related|recommend|share|promo|advert|comment|newsletter|subscription|paywall)(?:[\s_-]|$)/.test(signal)) return false;
      if (/(?:^|[\s_-])(?:asset[-_]?viewer|additional[-_]?asset|supplement(?:ary)?(?:[-_]?(?:asset|material))?|article[-_]?(?:video|media)|video[-_]?(?:container|player)|media[-_]?(?:container|player))(?:[\s_-]|$)/.test(signal)) explicit = true;
      current = current.parentElement;
    }
    return explicit;
  }

  function articleResourceDescendantHardHidden(node, container, cache) {
    var current = node;
    while (current && current !== container) {
      if (articleResourceNodeHardHidden(current, cache)) return true;
      current = current.parentElement;
    }
    return current !== container;
  }

  function articleResourceLabel(node, fallback) {
    var label = normalizeText(node.textContent || node.getAttribute("aria-label") || node.getAttribute("title") || "");
    if (!label && node.querySelector) {
      var image = node.querySelector("img[alt]");
      label = normalizeText(image && image.getAttribute("alt"));
    }
    return label || fallback;
  }

  function articleVideoResourceLabel(source, index) {
    var type = normalizeText(source.getAttribute("type") || "").toLowerCase();
    var url = materializedHttpUrl(source.getAttribute("src"));
    var extension = url ? new URL(url).pathname.split(".").pop().toLowerCase() : "";
    if (type.indexOf("webm") >= 0 || extension === "webm") return "Download as WebM";
    if (type.indexOf("ogg") >= 0 || extension === "ogv" || extension === "ogg") return "Download as Ogg";
    if (type.indexOf("mp4") >= 0 || extension === "mp4") return "Download as MPEG-4";
    return "Download video source " + (index + 1);
  }

  function representedArticleResourceUrls(content) {
    var root = document.createElement("div");
    root.innerHTML = sanitizedHtml(content.html || "");
    var represented = new Set();
    root.querySelectorAll("a[href]").forEach(function(link) {
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (url && articleResourceLabel(link, "")) represented.add(url);
    });
    root.querySelectorAll("img[src]").forEach(function(image) {
      var url = materializedHttpUrl(image.getAttribute("src"));
      if (url) represented.add(url);
    });
    root.querySelectorAll("video[poster]").forEach(function(video) {
      var url = materializedHttpUrl(video.getAttribute("poster"));
      if (url) represented.add(url);
    });
    root.querySelectorAll("video source[src]").forEach(function(source) {
      var url = materializedHttpUrl(source.getAttribute("src"));
      if (url) represented.add(url);
    });
    return represented;
  }

  function articleOwnedResourceContent(content) {
    var owner = articleResourceOwner(content);
    if (!owner) return null;

    var seen = representedArticleResourceUrls(content);

    var groups = [];
    var claimedVideos = new Set();
    var hiddenCache = new WeakMap();
    owner.querySelectorAll("[class*='asset-viewer' i], [class*='additional-asset' i], [class*='supplementary' i], " +
      "[class*='article-video' i], [class*='article-media' i], [class*='video-container' i], [class*='video-player' i], " +
      "[class*='media-container' i], [class*='media-player' i], video").forEach(function(node) {
      var video = node.localName === "video" ? node : node.querySelector("video");
      if (video && claimedVideos.has(video)) return;
      if (!articleResourceContainer(node, owner, hiddenCache)) return;
      if (video) claimedVideos.add(video);

      var scope = node.closest("figure, section") || node;
      var heading = scope.querySelector("h1, h2, h3, h4, h5, h6, figcaption");
      var group = { title: normalizeText(heading && heading.textContent), resources: [] };
      var orderedResources = [];
      if (node.matches("video[poster]")) orderedResources.push(node);
      Array.prototype.push.apply(orderedResources, node.querySelectorAll("a[href], video[poster], video source[src]"));
      orderedResources.forEach(function(resource) {
        if (articleResourceDescendantHardHidden(resource, node, hiddenCache)) return;
        var url;
        var label;
        if (resource.localName === "a") {
          url = materializedHttpUrl(resource.getAttribute("href"));
          label = articleResourceLabel(resource, "Open article asset");
          if (genericListControlText(articleResourceLabel(resource, ""))) return;
        } else if (resource.localName === "video") {
          url = materializedHttpUrl(resource.getAttribute("poster"));
          label = "Video poster";
        } else {
          url = materializedHttpUrl(resource.getAttribute("src"));
          var sources = Array.prototype.slice.call(resource.parentElement.querySelectorAll("source[src]"));
          label = articleVideoResourceLabel(resource, sources.indexOf(resource));
        }
        if (!url || seen.has(url)) return;
        seen.add(url);
        group.resources.push({ label: label, url: url });
      });
      if (group.resources.length) groups.push(group);
    });
    if (!groups.length) return null;

    var section = document.createElement("section");
    section.setAttribute("data-fetchutil-article-resources", "true");
    var title = document.createElement("h2");
    title.textContent = "Article resources";
    section.appendChild(title);
    groups.forEach(function(group) {
      if (group.title) {
        var heading = document.createElement("h3");
        heading.textContent = group.title;
        section.appendChild(heading);
      }
      var list = document.createElement("ul");
      group.resources.forEach(function(resource) {
        var item = document.createElement("li");
        var link = document.createElement("a");
        link.href = resource.url;
        link.textContent = resource.label;
        item.appendChild(link);
        list.appendChild(item);
      });
      section.appendChild(list);
    });
    return { html: section.outerHTML, textContent: normalizeText(section.textContent || "") };
  }

  function supplementOwnedArticleResources(content) {
    var resources = articleOwnedResourceContent(content);
    if (!resources) return content;
    return Object.assign({}, content, {
      html: (content.html || "") + resources.html,
      textContent: normalizeText((content.textContent || "") + " " + resources.textContent)
    });
  }
