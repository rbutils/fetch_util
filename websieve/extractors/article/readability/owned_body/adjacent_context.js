  function readerAdjacentContextOwnership(content, root) {
    var sources = content.sourceOwnedReaderBodyParagraphSources;
    var selected = Array.from(root.querySelectorAll("p"));
    if (!Array.isArray(sources) || sources.length < 2 || selected.length !== sources.length ||
        (content.sourceOwnedReaderUnmappedHeaderParagraphs || []).length ||
        (content.sourceOwnedReaderUnmappedTrailingParagraphs || []).length) return null;
    if (!sources.every(function(source, index) {
      return source && source.ownerDocument === document && source.isConnected &&
        !elementSubtreeHidden(source) && !sourceOwnershipInChrome(source) &&
        normalizeText(source.textContent) === normalizeText(selected[index].textContent) &&
        (!index || (sources[index - 1].compareDocumentPosition(source) & Node.DOCUMENT_POSITION_FOLLOWING));
    })) return null;
    var owner = sources[0].parentElement;
    var headings = [];
    while (owner && owner !== document.body) {
      headings = Array.from(owner.querySelectorAll("h1")).filter(function(heading) {
        return !elementSubtreeHidden(heading) && !sourceOwnershipInChrome(heading) &&
          (heading.compareDocumentPosition(sources[0]) & Node.DOCUMENT_POSITION_FOLLOWING) &&
          (!normalizeText(content.title) || normalizeText(heading.textContent) === normalizeText(content.title) ||
           normalizeText(heading.textContent).startsWith(normalizeText(content.title) + ". "));
      });
      if (headings.length && sources.every(function(source) { return owner.contains(source); })) break;
      owner = owner.parentElement;
    }
    if (!owner || owner === document.body || headings.length !== 1 ||
        (!owner.matches("article, main, [role='main']") &&
         !/(?:^|[\s_-])(?:article|post|story|entry)(?:$|[\s_-])/i.test(String(owner.className || "")))) return null;
    if (Array.from(owner.querySelectorAll("h1")).filter(function(heading) {
      return !elementSubtreeHidden(heading);
    }).length !== 1 || Array.from(owner.querySelectorAll("article")).filter(function(article) {
      return !elementSubtreeHidden(article) && readerHeaderParagraphs(article).length;
    }).length > 1) return null;
    return {owner: owner, heading: headings[0], sources: sources};
  }

  function readerAdjacentContextDateText(node) {
    if (!node || elementSubtreeHidden(node) || sourceOwnershipInChrome(node) ||
        node.querySelector("a, button, input, select, textarea, img, video, audio, iframe")) return null;
    var text = normalizeText(node.textContent);
    return /^(?:\d{4}[-\/.]\d{1,2}[-\/.]\d{1,2}|\d{1,2}[-\/.]\d{1,2}[-\/.]\d{4}|\d{1,2}\.?\s+[\p{L}.]+,?\s+\d{4})(?:\s*(?:\/|,|at)?\s*\d{1,2}:\d{2}(?::\d{2})?)?$/iu.test(text) ? text : null;
  }

  function readerAdjacentContextNodes(ownership) {
    var owner = ownership.owner;
    var first = ownership.sources[0];
    var last = ownership.sources[ownership.sources.length - 1];
    var beforeBody = function(node) {
      return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node) &&
        (node.compareDocumentPosition(first) & Node.DOCUMENT_POSITION_FOLLOWING);
    };
    var prefix = Array.from(owner.querySelectorAll("img")).filter(function(image) {
      return beforeBody(image) && !image.closest("a, figure, article") &&
        normalizeText(image.getAttribute("alt")) === normalizeText(ownership.heading.textContent) &&
        !!materializedHttpUrl(image.getAttribute("src"));
    });
    var dates = Array.from(owner.querySelectorAll("time, span, p, div")).filter(function(node) {
      return beforeBody(node) && readerAdjacentContextDateText(node);
    });
    dates = dates.filter(function(node) {
      return !dates.some(function(other) { return other !== node && node.contains(other); });
    });
    prefix = prefix.concat(dates);
    var topics = Array.from(owner.querySelectorAll("a[href]")).filter(function(link) {
      if (elementSubtreeHidden(link) || sourceOwnershipInChrome(link) || !normalizeText(link.textContent) ||
          link.closest("p, li, blockquote, article, figure, header, nav, aside, footer, form") ||
          !(last.compareDocumentPosition(link) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (!url) return false;
      try {
        var destination = new URL(url);
        return destination.origin === window.location.origin &&
          ((link.getAttribute("rel") || "").split(/\s+/).includes("tag") || /^\/(?:tag|tags|topic|topics)\//i.test(destination.pathname));
      } catch (_error) { return false; }
    });
    return {prefix: prefix, topics: topics};
  }

  function sourceOwnedReaderAdjacentContext(content) {
    if (!content || !content.readerMode || content.hostAware || content.contentType !== "article" || !content.html) return content;
    var root = document.createElement("div");
    root.innerHTML = content.html;
    var ownership = readerAdjacentContextOwnership(content, root);
    if (!ownership) return content;
    var nodes = readerAdjacentContextNodes(ownership);
    if (!nodes.prefix.length && !nodes.topics.length) return content;
    var prefix = document.createElement("header");
    nodes.prefix.concat([ownership.heading]).sort(function(left, right) {
      return left.compareDocumentPosition(right) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1;
    }).forEach(function(source) {
      if (source.localName === "img") {
        var src = materializedHttpUrl(source.getAttribute("src"));
        if (Array.from(root.querySelectorAll("img")).some(function(image) {
          return materializedHttpUrl(image.getAttribute("src")) === src;
        })) return;
      }
      var date = readerAdjacentContextDateText(source);
      if (date && ownership.sources.includes(source)) return;
      var copy = cleanClone(visibilityPrunedClone(source));
      if (date) {
        var paragraph = document.createElement("p");
        paragraph.textContent = date;
        copy = paragraph;
      }
      if (copy) prefix.appendChild(copy);
    });
    root.querySelectorAll("h1").forEach(function(heading) {
      if (normalizeText(heading.textContent) === normalizeText(ownership.heading.textContent)) heading.remove();
    });
    if (prefix.childNodes.length) root.insertBefore(prefix, root.firstChild);
    nodes.topics.forEach(function(source) {
      var destination = materializedHttpUrl(source.getAttribute("href"));
      if (Array.from(root.querySelectorAll("a[href]")).some(function(link) {
        return materializedHttpUrl(link.getAttribute("href")) === destination && normalizeText(link.textContent) === normalizeText(source.textContent);
      })) return;
      var paragraph = document.createElement("p");
      paragraph.appendChild(cleanClone(visibilityPrunedClone(source)));
      root.appendChild(paragraph);
    });
    return Object.assign(content, {
      title: normalizeText(ownership.heading.textContent),
      html: root.innerHTML, markdown: markdownFor(root.innerHTML), textContent: root.textContent
    });
  }
