  function editorialFrameInterface(node) {
    return node.closest("aside, nav, footer, form, button, pre, code, kbd, samp, script, style, noscript, template, svg, " +
      "[role~='complementary'], [role~='navigation'], [role~='dialog'], [role~='menu'], [role~='toolbar'], " +
      "[role~='button'], [hidden], [inert], [aria-hidden='true'], details:not([open])");
  }

  function editorialFrameSectionHeading(frame, source) {
    var selector = "article, [itemprop~='articleBody'], main, [role~='main']";
    var owner = frame.closest(selector);
    if (!owner || !Array.from(source.querySelectorAll("p")).some(function(paragraph) {
      return paragraph.closest(selector) === owner && !editorialFrameInterface(paragraph) &&
        !elementVisuallyHidden(paragraph) && !!normalizeText(paragraph.textContent);
    })) return null;

    for (var branch = frame; branch && branch !== owner; branch = branch.parentElement) {
      for (var previous = branch.previousElementSibling; previous; previous = previous.previousElementSibling) {
        if (previous.matches("h2, h3, h4, h5, h6")) {
          return source.contains(previous) && !editorialFrameInterface(previous) &&
            !elementVisuallyHidden(previous) && normalizeText(previous.textContent) ? previous : null;
        }
        if (previous.matches("h1, section, article, main, nav, aside") ||
            previous.querySelector("h1, h2, h3, h4, h5, h6, section, article, main")) return null;
      }
      if (branch.matches("section, article, main")) return null;
    }
    return null;
  }

  function editorialFrameLabel(original, source) {
    if (original.hasAttribute("srcdoc") || editorialFrameInterface(original) || elementVisuallyHidden(original)) return null;
    for (var current = original; current && current !== source; current = current.parentElement) {
      var signal = normalizeText((current.id || "") + " " + (current.getAttribute("class") || ""));
      if (/(?:^|[\s_-])(?:ads?|advert|advertisement|related|recommend|share|promo|comment)(?:[\s_-]|$)/i.test(signal)) return null;
    }

    var figure = original.closest("figure");
    var title = normalizeText(original.getAttribute("title") || "");
    if (figure && source.contains(figure) && title) return title;
    if (original.closest("a[href]") || !editorialFrameSectionHeading(original, source)) return null;
    return normalizeText(original.getAttribute("aria-label") || title) || "Embedded content";
  }

  function materializeEditorialFrameLinks(source, clone, elementMap) {
    var originals = Array.from(source.querySelectorAll("iframe"));
    if (!originals.length) return;
    var sourceClones = elementMap || new WeakMap();
    if (!sourceClones.has(source)) mapDomCloneElements(source, clone, sourceClones);

    originals.forEach(function(original) {
      var frame = sourceClones.get(original);
      if (!frame || frame.localName !== "iframe" || !clone.contains(frame)) return;
      if (!["src", "srcdoc", "title", "aria-label"].every(function(attribute) {
        return original.getAttribute(attribute) === frame.getAttribute(attribute);
      })) return;
      var url = materializedHttpUrl(original.getAttribute("src"));
      var label = url && editorialFrameLabel(original, source);
      if (!label) return;

      var link = clone.ownerDocument.createElement("a");
      link.href = url;
      link.textContent = label;
      frame.replaceWith(link);
    });
  }
