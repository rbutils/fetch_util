  function articleIntroClass(node) {
    return Array.from((node && node.classList) || []).some(function(token) {
      return /^(?:(?:article|story|post|content|header)[-_]+)*(?:lead|lede|dek|deck|standfirst|summary|intro)(?:[-_]+(?:text|copy|content|body))?$/i.test(token);
    });
  }

  function articleIntroMediaClass(node) {
    return Array.from((node && node.classList) || []).some(function(token) {
      var parts = token.toLowerCase().split(/[-_]+/).filter(Boolean);
      return parts.some(function(part) { return /^(?:article|story|lead|hero|primary)$/.test(part); }) &&
        parts.some(function(part) { return /^(?:image|media|photo|picture)$/.test(part); });
    });
  }

  function articleIntroFurniture(node, owner) {
    var cursor = node;
    while (cursor) {
      if (cursor.matches("[hidden], [aria-hidden='true'], blockquote, q, cite, nav, footer, aside, form, menu, [role='blockquote'], [role='navigation'], [role='complementary'], [role='menu'], [role='toolbar'], [role='dialog']")) return true;
      var tokens = [cursor.id || ""].concat(Array.from(cursor.classList || []));
      if (tokens.some(function(token) {
        return /(?:^|[-_])(?:ad|ads|advert|advertisement|advertorial|banner|carousel|commercial|comments?|disclaimers?|gallery|lightbox|newsletters?|partners?|paywalls?|promos?|promotion|promotional|pullquote|quoted|quotes?|recommendations?|related|shares?|slideshow|sponsors?|sponsored|subscriptions?)(?:$|[-_])/i.test(token);
      })) return true;
      if (cursor === owner) break;
      cursor = cursor.parentElement;
    }
    return false;
  }

  function articleIntroItemprop(node, owner) {
    if (!node.matches("[itemprop~='description']")) return false;
    var scope = node.closest("[itemscope]");
    return scope === owner && /(?:Article|BlogPosting)$/i.test(owner.getAttribute("itemtype") || "");
  }

  function articleIntroCollectionNode(node) {
    var tokens = [node.id || ""].concat(Array.from(node.classList || []));
    var semanticTokens = [node.getAttribute("role"), node.getAttribute("data-component"), node.getAttribute("data-testid")]
      .filter(Boolean).join(" ").split(/[^a-z0-9]+/i).filter(Boolean);
    return node.matches("ul, ol") || /^(?:feed|list|listitem)$/i.test(node.getAttribute("role") || "") ||
      tokens.concat(semanticTokens).some(function(token) {
      return /(?:^|[-_])(?:cards?|collection|feed|grid|list|stream|teasers?|tiles?)(?:$|[-_])/i.test(token);
    });
  }

  function articleIntroSubstantiveOwner(owner, firstBodyParagraph) {
    if (owner.parentElement && owner.parentElement.closest("article")) return false;
    if (articleIntroCollectionNode(owner)) return false;
    var bodyAncestor = firstBodyParagraph.parentElement;
    while (bodyAncestor && bodyAncestor !== owner) {
      if (articleIntroCollectionNode(bodyAncestor)) return false;
      bodyAncestor = bodyAncestor.parentElement;
    }
    var ancestor = owner.parentElement;
    while (ancestor) {
      if (articleIntroCollectionNode(ancestor)) return false;
      if (ancestor.matches("main, [role='main'], body")) break;
      ancestor = ancestor.parentElement;
    }
    var paragraphs = Array.from(owner.querySelectorAll("p")).filter(function(paragraph) {
      return paragraph.closest("article") === owner && !elementSubtreeHidden(paragraph) &&
        !articleIntroFurniture(paragraph, owner) && normalizeText(paragraph.textContent || "").length >= 80 &&
        (paragraph === firstBodyParagraph || !!(firstBodyParagraph.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING));
    });
    return paragraphs.length >= 3 && paragraphs.reduce(function(total, paragraph) {
      return total + normalizeText(paragraph.textContent || "").length;
    }, 0) >= 400;
  }

  function articleIntroResourceUrls(root) {
    var urls = [];
    Array.from(root.matches("img") ? [root] : root.querySelectorAll("img")).forEach(function(image) {
      var source = materializedHttpUrl(image.getAttribute("src"));
      if (source) urls.push(source);
      srcsetCandidates(image.getAttribute("srcset")).forEach(function(candidate) {
        var url = materializedHttpUrl(candidate.url);
        if (url && validSrcsetDescriptor(candidate.descriptor)) urls.push(url);
      });
    });
    root.querySelectorAll("source[srcset]").forEach(function(source) {
      srcsetCandidates(source.getAttribute("srcset")).forEach(function(candidate) {
        var url = materializedHttpUrl(candidate.url);
        if (url && validSrcsetDescriptor(candidate.descriptor)) urls.push(url);
      });
    });
    return Array.from(new Set(urls));
  }

  function attachedArticleIntroMedia(lead, owner) {
    var media = lead.previousElementSibling;
    if (!media || media.parentElement !== lead.parentElement || media.closest("article") !== owner ||
        elementSubtreeHidden(media) || articleIntroFurniture(media, owner) ||
        media.querySelector("a[href], button, input, select, textarea, form, video, audio, iframe, object, embed")) return null;
    if (!media.matches("img, picture, figure") && !articleIntroMediaClass(media)) return null;
    if (Array.from(media.querySelectorAll("div, section, figure")).some(articleIntroMediaClass)) return null;
    var mediaHeader = media.parentElement && media.parentElement.closest("header");
    if (media.matches("figure") && !articleIntroMediaClass(media) &&
        (!mediaHeader || mediaHeader.closest("article") !== owner)) return null;

    var images = Array.from(media.matches("img") ? [media] : media.querySelectorAll("img"));
    if (images.length !== 1 || !articleIntroResourceUrls(media).length) return null;
    var text = normalizeText(media.textContent || "");
    if (text && !media.matches("figure")) return null;
    if (text.length > 250) return null;
    return media;
  }

  function articleIntroCandidate(owner, paragraph) {
    var selector = [
      "[itemprop~='description']", "[class*='lead' i]", "[class*='lede' i]", "[class*='dek' i]",
      "[class*='deck' i]", "[class*='standfirst' i]", "[class*='summary' i]", "[class*='intro' i]"
    ].join(", ");
    var candidates = Array.from(owner.querySelectorAll(selector)).filter(function(node) {
      var text = normalizeText(node.textContent || "");
      var emphases = Array.from(node.querySelectorAll("strong, b"));
      return node.closest("article") === owner &&
        (articleIntroItemprop(node, owner) || articleIntroClass(node)) && text.length >= 80 &&
        !node.querySelector("p, h1, h2, h3, h4, h5, h6, a[href], button, input, select, textarea, form") &&
        (emphases.length === 0 || (emphases.length === 1 && normalizeText(emphases[0].textContent || "") === text)) &&
        !elementSubtreeHidden(node) && !articleIntroFurniture(node, owner) &&
        !!(node.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING);
    }).filter(function(node, _index, nodes) {
      return !nodes.some(function(other) { return other !== node && node.contains(other); });
    });
    return candidates.length === 1 ? candidates[0] : null;
  }

  function articleIntroLeadPresent(root, text) {
    var selector = [
      "[itemprop~='description']", "[class*='lead' i]", "[class*='lede' i]",
      "[class*='dek' i]", "[class*='deck' i]", "[class*='standfirst' i]", "[class*='summary' i]", "[class*='intro' i]"
    ].join(", ");
    return Array.from(root.querySelectorAll(selector)).some(function(node) {
      var owner = node.closest("article");
      return (articleIntroClass(node) || (owner && articleIntroItemprop(node, owner))) &&
        normalizeText(node.textContent || "") === text;
    });
  }

  function supplementOwnedArticleIntro(content, selectedContent) {
    var selectedRoot = document.createElement("div");
    selectedRoot.innerHTML = (selectedContent && selectedContent.html) || content.html || "";
    var primaryParagraph = Array.from(selectedRoot.querySelectorAll("p")).find(function(paragraph) {
      return normalizeText(paragraph.textContent || "").length >= 80;
    });
    var primaryText = normalizeText(primaryParagraph && primaryParagraph.textContent);
    if (!primaryText) return content;

    var sourceParagraphs = Array.from(document.querySelectorAll("article p")).filter(function(paragraph) {
      return normalizeText(paragraph.textContent || "") === primaryText && !elementSubtreeHidden(paragraph);
    });
    if (sourceParagraphs.length !== 1) return content;

    var paragraph = sourceParagraphs[0];
    var owner = paragraph.closest("article");
    if (!owner || articleIntroFurniture(paragraph, owner) || !articleIntroSubstantiveOwner(owner, paragraph)) return content;
    var lead = articleIntroCandidate(owner, paragraph);
    if (!lead) return content;

    var mediaCandidate = lead.previousElementSibling;
    var media = attachedArticleIntroMedia(lead, owner);
    if (mediaCandidate &&
        (mediaCandidate.matches("img, picture, figure, video, audio, iframe, object, embed") ||
          mediaCandidate.querySelector("img, picture, video, audio, iframe, object, embed")) && !media) return content;

    var contentRoot = document.createElement("div");
    contentRoot.innerHTML = content.html || "";
    var sourceMedia = media;
    var contentPrimaryParagraph = Array.from(contentRoot.querySelectorAll("p")).find(function(node) {
      return normalizeText(node.textContent || "") === primaryText;
    });
    var mediaInsertion = articleIntroMediaInsertionNode(contentRoot, sourceMedia, contentPrimaryParagraph);
    if (media) {
      var existingUrls = new Set(articleIntroResourceUrls(contentRoot));
      if (articleIntroResourceUrls(media).some(function(url) { return existingUrls.has(url); })) {
        if (!mediaInsertion) return content;
        media = null;
      }
    }
    var contentText = normalizeText(content.textContent || "");
    var leadText = normalizeText(lead.textContent || "");
    var metadataAddedLead = !articleIntroExactTextPresent(selectedRoot, leadText) &&
      articleIntroExactTextPresent(contentRoot, leadText);
    var leadMissing = !articleIntroLeadPresent(contentRoot, leadText) && !metadataAddedLead;
    if (!leadMissing && !media) return content;
    var renderedLead = Array.from(contentRoot.querySelectorAll("p, strong, b, [itemprop~='description']")).find(function(node) {
      return normalizeText(node.textContent || "") === leadText &&
        (metadataAddedLead || articleIntroClass(node) || (node.closest("article") && articleIntroItemprop(node, node.closest("article"))));
    });
    var insertionContext = articleIntroInsertionContext(contentRoot, owner, lead, paragraph, contentPrimaryParagraph);
    var mappedSelected = insertionContext.mapped.slice();
    if (renderedLead) mappedSelected.push(renderedLead);
    if (!articleIntroSourcePrefixOwned(owner, lead, insertionContext.sourceMapped, sourceMedia)) return content;
    if (!articleIntroSelectedPrefixOwned(contentRoot, contentPrimaryParagraph, mappedSelected, mediaInsertion)) return content;
    if (!leadMissing && media) {
      if (!renderedLead || !contentPrimaryParagraph ||
          !(renderedLead.compareDocumentPosition(contentPrimaryParagraph) & Node.DOCUMENT_POSITION_FOLLOWING)) return content;
      renderedLead.parentNode.insertBefore(cleanClone(visibilityPrunedClone(media, document)), renderedLead);
      return Object.assign({}, content, {
        html: contentRoot.innerHTML,
        textContent: normalizeText(contentRoot.textContent || "")
      });
    }

    var context = document.createElement("div");
    if (media) context.appendChild(cleanClone(visibilityPrunedClone(media, document)));
    if (leadMissing) context.appendChild(cleanClone(visibilityPrunedClone(lead, document)));
    var insertion = insertionContext.node;
    var insertBefore = insertionContext.before;
    if (mediaInsertion) {
      insertion = mediaInsertion;
      insertBefore = false;
    }
    var html;
    if (insertion) {
      var reference = insertBefore ? insertion : insertion.nextSibling;
      Array.from(context.childNodes).forEach(function(node) {
        insertion.parentNode.insertBefore(node, reference);
      });
      html = contentRoot.innerHTML;
    } else {
      html = context.innerHTML + (content.html || "");
    }
    var outputRoot = document.createElement("div");
    outputRoot.innerHTML = html;
    return Object.assign({}, content, {
      html: html,
      textContent: normalizeText(outputRoot.textContent || "")
    });
  }
