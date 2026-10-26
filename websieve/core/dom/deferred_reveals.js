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

  function activeSourceRevealOwner(node) {
    var owner = node.closest("[data-slide-id]");
    var root = owner && owner.parentElement && owner.parentElement.closest("[data-active-slide]");
    if (!root) return null;
    var identity = owner.getAttribute("data-slide-id");
    if (!identity || root.getAttribute("data-active-slide") !== identity) return null;
    var peers = Array.from(root.querySelectorAll("[data-slide-id]")).filter(function(peer) {
      return peer.getAttribute("data-slide-id") === identity;
    });
    if (peers.length !== 1 || peers[0] !== owner) return null;

    for (var current = node; current && current.nodeType === 1; current = current.parentElement) {
      if (current.hidden || current.hasAttribute("inert") || current.getAttribute("aria-hidden") === "true") return null;
      if (current.matches("nav, header, footer, aside, form, button, dialog, pre, code, kbd, samp, " +
        "[role='dialog'], [aria-modal='true'], [role='navigation'], [role='menu'], [role='menubar'], " +
        "[role='tooltip'], [role='complementary'], [role='contentinfo'], [role='tab'], [role='tablist'], " +
        "[role='tabpanel'], [role='listbox'], details:not([open]), [aria-expanded='false'], " +
        "[aria-selected='false'], [data-state='closed'], [data-state='locked'], " +
        "[data-auth-required='true'], [data-members-only]")) return null;
      var style = window.getComputedStyle ? window.getComputedStyle(current) : null;
      if (style && (style.display === "none" || style.visibility === "hidden" || style.visibility === "collapse")) return null;
    }
    return owner;
  }

  function finiteSourceOpacityReveal(node) {
    if (!node.getAnimations || !document.timeline) return false;
    try {
      var opacityAnimations = node.getAnimations().filter(function(animation) {
        return animation.effect && animation.effect.target === node && animation.effect.getKeyframes().some(function(frame) {
          return Object.prototype.hasOwnProperty.call(frame, "opacity");
        });
      });
      return opacityAnimations.length > 0 && opacityAnimations.every(function(animation) {
        var timing = animation.effect.getTiming();
        var frames = animation.effect.getKeyframes();
        if (animation.timeline !== document.timeline || animation.playbackRate <= 0 ||
          (animation.playState !== "running" && animation.playState !== "finished")) return false;
        if (!Number.isFinite(timing.duration) || timing.duration <= 0 ||
          !Number.isFinite(timing.iterations) || timing.iterations <= 0 ||
          !Number.isFinite(timing.delay) || timing.delay < 0 || timing.direction !== "normal" ||
          (timing.fill !== "both" && timing.fill !== "forwards")) return false;
        if (frames.length < 2 || frames[0].computedOffset !== 0 || frames[frames.length - 1].computedOffset !== 1) return false;
        if (Number(frames[0].opacity) !== 0 || Number(frames[frames.length - 1].opacity) !== 1) return false;
        return frames.every(function(frame) { return frame.composite === "auto" || frame.composite === "replace"; });
      });
    } catch (_) {
      return false;
    }
  }

  function activeSourceOpacityReveal(node, style) {
    if (!node || !node.matches || !node.isConnected || node.ownerDocument !== document) return false;
    style = style || (window.getComputedStyle ? window.getComputedStyle(node) : null);
    if (!style || style.opacity === "" || Number(style.opacity) !== 0 || !activeSourceRevealOwner(node)) return false;
    var heading = node.querySelector("h1, h2, h3, h4, h5, h6");
    var paragraph = node.querySelector("p");
    if (!heading || !normalizeText(heading.textContent) || !paragraph || !normalizeText(paragraph.textContent)) return false;
    // Retain only the declared active narrative during an autonomous initial reveal.
    return finiteSourceOpacityReveal(node);
  }

  function declaredProfileOpacityReveal(node, style) {
    var root = sourceVisibilityReadContext && sourceVisibilityReadContext.profileRoot;
    if (!root || !root.isConnected || root.ownerDocument !== document || !root.contains(node)) return false;
    if (!node || !node.matches || node.matches("html, body") || !deferredRevealSafeContext(node)) return false;
    if (node.closest("form, button, pre, code, kbd, samp, [role='tab'], [role='tablist']")) return false;
    if (!style || style.opacity === "" || Number(style.opacity) !== 0 || style.animationName !== "none") return false;
    if (node.getAttribute("data-animation-style") !== "fade" ||
      !node.hasAttribute("data-animation-repeat") || node.getAttribute("data-animation-repeat") !== "") return false;
    var duration = /^(\d+(?:\.\d+)?)(ms|s)$/.exec(node.getAttribute("data-animation-duration") || "");
    var delay = /^(\d+(?:\.\d+)?)(ms|s)$/.exec(node.getAttribute("data-animation-delay") || "");
    var initial = node.getAttribute("data-animation-starting-opacity") || "";
    if (!duration || !Number.isFinite(Number(duration[1])) || Number(duration[1]) <= 0 ||
      !delay || !Number.isFinite(Number(delay[1])) || !/^0(?:\.0+)?%?$/.test(initial)) return false;
    return Array.from(node.querySelectorAll("p")).some(function(paragraph) {
      return normalizeText(paragraph.textContent) && deferredRevealSafeContext(paragraph);
    });
  }

  function deferredRevealContentNode(node, style) {
    if (activeSourceOpacityReveal(node, style)) return true;
    if (declaredProfileOpacityReveal(node, style)) return true;
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
