function ownedHomepageMarkdown(service, root) {
  Array.from(root.querySelectorAll("h1 br, h2 br, h3 br, h4 br, h5 br, h6 br")).forEach(function(br) {
    if (!br.closest("code, pre")) br.replaceWith(root.ownerDocument.createTextNode(" "));
  });
  var listItem = service.rules.forNode(root.ownerDocument.createElement("li"));
  service.addRule("completeHomepageListItem", {
    filter: "li",
    replacement: function(content, node, options) {
      return listItem.replacement(content.replace(/^(?:[ \t]*\n)+/, ""), node, options);
    }
  });
  return service.turndown(root);
}

function homepagePeerSectionsContext(metadata) {
  if (!document.body || !homepageRootPath() || location.hash ||
      structuredDataNodes().some(structuredDataFocalRecord)) return null;
  var current = sourceOwnershipPageUrl(location.href);
  var types = Array.from(document.querySelectorAll("meta[property='og:type' i]"));
  var titles = Array.from(document.querySelectorAll("meta[property='og:title' i]"));
  if (!current || !types.length || !titles.length || !types.every(function(node) {
    return normalizeText(node.getAttribute("content")).toLowerCase() === "website";
  })) return null;
  var title = normalizeText(titles[0].getAttribute("content"));
  var documentTitle = normalizeText(document.title);
  if (!title || !titles.every(function(node) { return normalizeText(node.getAttribute("content")) === title; }) ||
      (documentTitle !== title && (documentTitle.indexOf(title) !== 0 ||
        !/^\s*[|·:–—-]\s*\S/u.test(documentTitle.slice(title.length))))) return null;
  if (metadata && metadata.title && ![title, documentTitle].includes(normalizeText(metadata.title))) return null;
  if (Array.from(document.querySelectorAll("link[rel~='canonical' i], meta[property='og:url' i]")).some(function(node) {
    return sourceOwnershipPageUrl(node.getAttribute("href") || node.getAttribute("content")) !== current;
  })) return null;

  return withSourceVisibilityRead(function() {
    var mains = Array.from(document.querySelectorAll("main, [role~='main' i]")).filter(function(node) {
      return !elementSubtreeHidden(node);
    });
    if (mains.length !== 1) return null;
    var main = mains[0];
    if (main.querySelector("article, form, input, select, textarea, [itemprop~='articleBody' i], " +
        "[rel~='author' i], [itemprop~='datePublished' i], time[pubdate]")) return null;
    var headings = Array.from(main.querySelectorAll("h1")).filter(function(node) {
      return normalizeText(node.textContent) && !homepageLandingChrome(node) && !elementSubtreeHidden(node);
    });
    if (headings.length < 2 || new Set(headings.map(function(node) { return normalizeText(node.textContent); })).size !== headings.length) {
      return null;
    }
    var groups = headings.map(function(heading) {
      for (var owner = heading.parentElement; owner && owner !== main; owner = owner.parentElement) {
        if (headings.some(function(other) { return other !== heading && owner.contains(other); })) return null;
        if (Array.from(owner.querySelectorAll("p")).some(function(paragraph) {
          return !homepageLandingChrome(paragraph) && !elementSubtreeHidden(paragraph) &&
            readerSectionParagraphNarrative(paragraph);
        })) return owner;
      }
      return null;
    });
    if (groups.some(function(group) { return !group; }) || new Set(groups).size !== headings.length) return null;
    var chrome = "header, footer, nav, aside, form, button, dialog, [role='navigation'], " +
      "[role='complementary'], [role='contentinfo'], [role='banner'], [role='dialog'], script, style, noscript, template";
    var outsideMedia = Array.from(document.querySelectorAll("img, figure, video, audio, iframe, pre, table, blockquote"));
    if (outsideMedia.some(function(node) {
      return !main.contains(node) && !node.closest(chrome) && !elementVisuallyHidden(node);
    })) return null;
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    for (var text = walker.nextNode(); text; text = walker.nextNode()) {
      if (!normalizeText(text.nodeValue) || main.contains(text) || text.parentElement.closest(chrome)) continue;
      if (!elementSubtreeHidden(text.parentElement)) return null;
    }
    return { root: main, title: title };
  });
}

function homepagePeerSectionsContent(metadata) {
  var context = homepagePeerSectionsContext(metadata);
  if (!context) return null;
  var clone = visibilityPrunedClone(context.root, document);
  removeAll(clone, "script, style, noscript, template");
  return profileHtmlContent(metadata, clone, {
    cloneRoot: false,
    cleanupRoot: false,
    cleanupMarkdown: false,
    preserveCleanedRoot: true,
    convertRoot: ownedHomepageMarkdown,
    title: context.title,
    excerpt: metadata.description || metadata.excerpt || null,
    byline: null,
    publishedTime: null,
    contentType: "list",
    hostAware: false,
    extra: { sourceOwnedHomepageCollection: true }
  });
}
