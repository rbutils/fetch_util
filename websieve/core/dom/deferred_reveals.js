  function deferredRevealSafeContext(node) {
    for (var current = node; current && current.nodeType === 1; current = current.parentElement) {
      if (current.hidden || current.hasAttribute("inert") || current.getAttribute("aria-hidden") === "true") return false;
      if (current.matches("nav, header, footer, aside, dialog, [role='dialog'], [aria-modal='true'], [role='navigation'], [role='menu'], [role='menubar'], [role='tooltip'], [role='listbox'], [role='tabpanel'], [role='tab'], [role='complementary'], [role='contentinfo'], [aria-expanded='false'], [aria-selected='false'], [data-state='closed'], details:not([open]), .slide, .w-slide, [aria-roledescription='slide']")) return false;
      var attrs = (current.id || "") + " " + (current.getAttribute("class") || "");
      if (current.matches("[data-state='locked'], [data-auth-required='true'], [data-members-only]") ||
        /pay[-_ ]?wall|protected|restricted|(?:members?|subscriber|auth)[-_ ]*only|premium[-_ ]*(?:content|article)/i.test(attrs)) return false;
      if (/(?:^|[\s_-])(?:carousel|swiper|slick|slider|slideshow|modal|dialog|popup|popover|tooltip|menu|navbar|accordion|tab(?:[-_]?(?:panel|pane|content))|lightbox|drawer|offcanvas|paywall|gated|restricted|consent|cookie|onetrust)(?:[\s_-]|$)/i.test(attrs)) return false;
      var style = window.getComputedStyle ? window.getComputedStyle(current) : null;
      if (style && (style.display === "none" || style.visibility === "hidden" || style.visibility === "collapse")) return false;
    }
    return true;
  }

  function deferredRevealRecordUrls(node) {
    if (!node || !node.querySelectorAll || !deferredRevealSafeContext(node)) return [];
    var title = node.querySelector("h1, h2, h3, h4, h5, h6, [role='heading'], [class*='title' i], [class$='-name' i]");
    var hasTitle = title && normalizeText(title.textContent) && deferredRevealSafeContext(title);
    var paragraphs = Array.from(node.querySelectorAll("p")).filter(function(paragraph) {
      return normalizeText(paragraph.textContent) && deferredRevealSafeContext(paragraph);
    });
    var media = node.querySelector("img[alt]:not([alt=''])");
    var mediaProse = false;
    if (!hasTitle && paragraphs.length < 2 && media && deferredRevealSafeContext(media)) {
      var description = node.cloneNode(true);
      description.querySelectorAll("a, button, svg, script, style, noscript, template, [hidden], [inert], [aria-hidden='true']").forEach(function(child) { child.remove(); });
      mediaProse = !!normalizeText(description.textContent);
    }
    if (!hasTitle && paragraphs.length < 2 && !mediaProse) return [];
    var links = node.matches("a[href]") ? [node] : Array.from(node.querySelectorAll("a[href]"));
    return links.filter(deferredRevealSafeContext).map(function(link) {
      return materializedHttpUrl(link.getAttribute("href"));
    }).filter(Boolean);
  }

  function deferredRevealContentNode(node, style) {
    if (!node || !node.matches || node.matches("html, body") || !homepageRootPath()) return false;
    var classes = node.getAttribute("class") || "";
    var animation = node.hasAttribute("data-w-id") || /(?:^|[\s_-])(?:reveal|animate|animation)(?:[\s_-]|$)/i.test(classes);
    style = style || (window.getComputedStyle ? window.getComputedStyle(node) : null);
    if (!style || style.opacity === "" || Number(style.opacity) !== 0) return false;
    if (!animation && !(/transform/i.test(node.style.willChange || "") && style.transform && style.transform !== "none")) return false;
    if (!deferredRevealSafeContext(node)) return false;

    // Only recover structured record collections, never arbitrary opacity-zero UI.
    var destinations = new Set();
    node.querySelectorAll("a[href], article, li, [class*='card' i], [class*='item' i]").forEach(function(record) {
      deferredRevealRecordUrls(record).forEach(function(url) { destinations.add(url); });
    });
    if (destinations.size >= 2) return true;
    if (!node.parentElement || !deferredRevealRecordUrls(node).length) return false;
    Array.from(node.parentElement.children).forEach(function(peer) {
      deferredRevealRecordUrls(peer).forEach(function(url) { destinations.add(url); });
    });
    return destinations.size >= 2;
  }
