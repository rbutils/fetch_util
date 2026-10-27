  function sourceOwnedFallbackSections(primary, fallback, primaryRoot, fallbackRoot, primaryText, fallbackText) {
    if (!document.body || primary.contentType !== "article" || fallback.contentType !== "article" ||
        articleRouteFocalContent(primary) || fallbackText.length < Math.max(400, primaryText.length * 2)) return false;

    var mains = Array.prototype.filter.call(document.querySelectorAll("main, [role='main']"), function(node) {
      return !elementSubtreeHidden(node);
    });
    if (mains.length !== 1) return false;

    var owner = visibilityPrunedClone(mains[0], document);
    if (normalizeText(owner.textContent || "").length < fallbackText.length * 0.85) return false;

    var readerParagraphs = Array.prototype.map.call(primaryRoot.querySelectorAll("p"), function(node) {
      return normalizeText(node.textContent || "");
    }).filter(function(text) { return text.length >= 45; });
    if (readerParagraphs.length < 2 || !readerParagraphs.every(function(text) {
      return fallbackText.indexOf(text) !== -1;
    })) return false;

    var readerHeadings = Array.prototype.map.call(primaryRoot.querySelectorAll("h1, h2, h3"), function(node) {
      return normalizeText(node.textContent || "");
    });
    var ownerHeadings = new Set(Array.prototype.map.call(owner.querySelectorAll("h1, h2, h3"), function(node) {
      return normalizeText(node.textContent || "");
    }).filter(Boolean));
    var newHeadings = Array.prototype.filter.call(fallbackRoot.querySelectorAll("h1, h2, h3"), function(node) {
      var text = normalizeText(node.textContent || "");
      return text && ownerHeadings.has(text) && readerHeadings.indexOf(text) === -1;
    });
    if (newHeadings.length < 3) return false;

    var newParagraphs = Array.prototype.filter.call(fallbackRoot.querySelectorAll("p"), function(node) {
      var text = normalizeText(node.textContent || "");
      return text.length >= 45 && primaryText.indexOf(text) === -1;
    });
    if (newParagraphs.length >= 2) return true;

    var readerUrls = new Set(Array.prototype.map.call(primaryRoot.querySelectorAll("a[href]"), function(link) {
      return materializedHttpUrl(link.getAttribute("href"));
    }).filter(Boolean));
    var ownerUrls = new Set(Array.prototype.map.call(owner.querySelectorAll("a[href]"), function(link) {
      return materializedHttpUrl(link.getAttribute("href"));
    }).filter(Boolean));
    var newUrls = new Set(Array.prototype.map.call(fallbackRoot.querySelectorAll("a[href]"), function(link) {
      if (!normalizeText(link.textContent || link.getAttribute("aria-label") || "")) return null;
      var url = materializedHttpUrl(link.getAttribute("href"));
      return url && ownerUrls.has(url) && !readerUrls.has(url) ? url : null;
    }).filter(Boolean));
    return newHeadings.length >= 4 && newUrls.size >= 4;
  }

  function sourceOwnedPublicationMaterial(root, preserveTargets) {
    var reading = root.cloneNode(true);
    reading.querySelectorAll("h1, h2, h3, h4, h5, h6, p, div, section, article, li, pre, table, tr, th, td, blockquote, figcaption, br").forEach(function(node) {
      node.parentNode.insertBefore(document.createTextNode(" "), node);
      node.parentNode.insertBefore(document.createTextNode(" "), node.nextSibling);
    });
    var events = [];
    var pending = "";
    function materialAttributes(node) {
      return Array.from(node.attributes).map(function(attribute) { return attribute.name; }).filter(function(name) {
        return name !== "class" && (preserveTargets !== false || (name !== "id" && name !== "name"));
      }).sort();
    }
    function flush(literal) {
      var value = literal ? pending : normalizeText(pending);
      if (value) events.push(["text", value]);
      pending = "";
    }
    var stack = Array.from(root.childNodes).reverse().map(function(node) {
      return { node: node, literal: false, closing: false };
    });
    while (stack.length) {
      var entry = stack.pop();
      var node = entry.node;
      if (entry.closing) {
        flush(entry.literal);
        events.push(["end", node.localName]);
      } else if (node.nodeType === Node.TEXT_NODE) {
        pending += node.nodeValue;
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        if (node.namespaceURI !== "http://www.w3.org/1999/xhtml") {
          flush(entry.literal);
          events.push(["foreign", node.namespaceURI, node.outerHTML]);
          continue;
        }
        var literal = entry.literal || node.matches("pre, code, kbd, samp");
        var attributes = materialAttributes(node);
        var represented = !node.matches("div, span") || attributes.some(function(name) { return name !== "href"; });
        if (represented) {
          flush(entry.literal);
          var values = attributes.map(function(name) {
            var value = node.getAttribute(name);
            if (/^(?:href|src|poster|data)$/.test(name)) {
              try { value = new URL(value, location.href).href; } catch (_error) { /* Preserve the literal attribute. */ }
            }
            return [name, value];
          });
          events.push(["start", node.localName, values, node.namespaceURI,
            node.matches("pre, code, kbd, samp") ? node.getAttribute("class") : null]);
          stack.push({ node: node, literal: literal, closing: true });
        }
        for (var index = node.childNodes.length - 1; index >= 0; index -= 1) {
          stack.push({ node: node.childNodes[index], literal: literal, closing: false });
        }
      }
    }
    flush(false);
    return JSON.stringify([normalizeText(reading.textContent), events]);
  }

  function sourceOwnedLinkedPublicationSections(primary, fallback, primaryRoot, fallbackRoot) {
    if (!document.body || primary.contentType !== "article" || fallback.contentType !== "article" ||
        fallback.sourceOwnedFocalArticle) return false;
    var headlines = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
      return !elementVisuallyHidden(heading) && !sourceOwnershipInChrome(heading);
    });
    if (headlines.length !== 1 || headlines[0].closest("a[href]") ||
        !sourceOwnedReaderHeadlineTitleMatches(headlines[0].textContent, fallback, null)) return false;
    var owner = headlines[0].closest("article");
    if (!owner || sourceOwnershipInChrome(owner)) return false;
    var sourceClones = new WeakMap();
    var visibleOwner = visibilityPrunedClone(owner, document, sourceClones);
    if (sourceOwnedPublicationMaterial(visibleOwner) !== sourceOwnedPublicationMaterial(fallbackRoot)) return false;
    var primaryMaterial = sourceOwnedPublicationMaterial(primaryRoot, false);
    var currentUrls = new Set([location.href].concat(Array.from(document.querySelectorAll("link[rel~='canonical'], meta[property='og:url']")).map(function(node) {
      return node.getAttribute("href") || node.getAttribute("content");
    }).filter(Boolean)).map(focalCanonicalUrl).filter(Boolean));
    var groups = new Map();
    owner.querySelectorAll("a[href]").forEach(function(link) {
      var visible = sourceClones.get(link);
      if (!visible || !visibleOwner.contains(visible) ||
          link.closest("nav, aside, footer, form, button, pre, code, [role='button'], [role='navigation'], [role='complementary'], [role='toolbar'], [role='dialog']")) return;
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (!url || currentUrls.has(focalCanonicalUrl(url))) return;
      var headings = visible.querySelectorAll("h1, h2, h3, h4, h5, h6");
      if (headings.length !== 1 || !normalizeText(headings[0].textContent) ||
          visible.querySelector("form, button, input, select, textarea, nav, aside, [role='button'], [role='navigation']")) return;
      if (!Array.from(visible.querySelectorAll("p")).some(function(paragraph) {
        return !!normalizeText(paragraph.textContent);
      })) return;
      var parent = link.parentElement;
      if (!groups.has(parent)) groups.set(parent, []);
      groups.get(parent).push({ source: link, visible: visible });
    });
    return Array.from(groups.entries()).some(function(entry) {
      var parent = entry[0];
      var records = entry[1];
      if (records.length < 2) return false;
      var sources = new Set(records.map(function(record) { return record.source; }));
      var visibleChildren = Array.from(parent.children).filter(function(child) {
        var clone = sourceClones.get(child);
        return !!clone && visibleOwner.contains(clone);
      });
      if (visibleChildren.length !== records.length || !visibleChildren.every(function(child) {
        return sources.has(child);
      })) return false;
      if (Array.from(parent.childNodes).some(function(node) {
        return node.nodeType === Node.TEXT_NODE && !!normalizeText(node.textContent);
      })) return false;
      return records.some(function(record) {
        return sourceOwnedPublicationMaterial(record.visible, false) === primaryMaterial;
      });
    });
  }

  function sourceOwnedFallbackContent(primary, fallback, primaryRoot, fallbackRoot, primaryText, fallbackText) {
    if (!sourceOwnedLinkedResourceSections(primary, fallback, primaryRoot, fallbackRoot) &&
        !sourceOwnedLinkedPublicationSections(primary, fallback, primaryRoot, fallbackRoot) &&
        !sourceOwnedFallbackSections(primary, fallback, primaryRoot, fallbackRoot, primaryText, fallbackText)) return null;
    fallback.sourceOwnedSections = true;
    return fallback;
  }

  function sourceOwnedFallbackListLoss(content, candidate) {
    if (!content || !content.sourceOwnedSections || !candidate || candidate.contentType !== "list") return false;
    var root = document.createElement("div");
    root.innerHTML = sanitizedHtml(content.html || "");
    var rendered = normalizeText(candidate.markdown || candidate.textContent || "");
    return Array.prototype.some.call(root.querySelectorAll("h2, h3"), function(heading) {
      var text = normalizeText(heading.textContent || "");
      return text && rendered.indexOf(text) === -1;
    });
  }
