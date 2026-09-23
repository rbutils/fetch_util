function articleWidgetTokens(node) {
  var signature = [
    node.getAttribute("id"),
    node.getAttribute("class"),
    node.getAttribute("data-component"),
    node.getAttribute("data-testid"),
    node.getAttribute("data-role"),
    node.getAttribute("role"),
    node.getAttribute("aria-label")
  ].filter(Boolean).join(" ").replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase();

  return signature.split(/[^a-z0-9]+/).filter(Boolean);
}

function articleAudioControlNode(node) {
  if (!node || !node.matches || !node.closest("article, [itemprop~='articleBody' i]")) return false;

  var tokens = articleWidgetTokens(node);
  if (tokens.indexOf("audio") === -1) return false;
  var controls = tokens.some(function(token) {
    return /^(?:control|controls|player|toolbar)$/.test(token);
  }) || (tokens.indexOf("label") !== -1 && tokens.indexOf("bar") !== -1);
  if (!controls) return false;

  if (String(node.localName || "").indexOf("-") !== -1) return false;
  var materialSelector = "article, main, section, h1, h2, h3, h4, h5, h6, p, a[href], ul, ol, dl, table, blockquote, figure, figcaption, pre, code, kbd, samp, label, details, summary, address, cite, time, [itemprop~='duration' i], img, picture, video, audio, iframe, object, embed, svg, canvas, math";
  if (node.matches(materialSelector) || node.querySelector(materialSelector)) return false;
  var controlTags = { b: true, br: true, button: true, div: true, em: true, i: true, small: true, span: true, strong: true };
  var hasStructuredContent = Array.from(node.querySelectorAll("*")).some(function(child) {
    return !controlTags[String(child.localName || "").toLowerCase()];
  });
  if (hasStructuredContent) return false;

  var text = normalizeText([node.textContent, node.getAttribute("aria-label")].filter(Boolean).join(" "));
  if (!text || text.length > 160) return false;
  return /(?:^|[^\d:])(?:\d{1,2}:[0-5]\d:[0-5]\d|\d{1,3}:[0-5]\d)(?![\d:])/.test(text);
}

function articleAudioFallbackNode(node) {
  if (!node || !node.matches || !node.closest("article, [itemprop~='articleBody' i]")) return false;

  var componentMarker = [
    node.getAttribute("id"),
    node.getAttribute("class"),
    node.getAttribute("data-component"),
    node.getAttribute("data-testid"),
    node.getAttribute("data-role"),
    node.getAttribute("role")
  ].filter(Boolean).some(function(value) {
    return String(value).split(/\s+/).some(function(part) {
      var normalized = part.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean).join(" ");
      return normalized === "audio player" || normalized === "article audio player";
    });
  });
  if (!componentMarker) return false;
  if (String(node.localName || "").indexOf("-") !== -1) return false;

  var materialSelector = "article, main, section, h1, h2, h3, h4, h5, h6, p, a[href], ul, ol, dl, table, blockquote, figure, figcaption, pre, code, kbd, samp, label, details, summary, address, cite, time, [itemprop], img, picture, video, audio, iframe, object, embed, svg, canvas, math, button, input, select, textarea, output";
  if (node.matches(materialSelector) || node.querySelector(materialSelector)) return false;

  var text = normalizeText(node.textContent);
  if (!text || text.length > 240 || node.children.length) return false;
  var englishFallback = /^(?:(?:your|this|the|our)\s+)?browser\s+(?:does\s+not|doesn['’]t|cannot|can['’]t|is\s+unable\s+to)\s+(?:support|play|reproduce)(?:\s+(?:the\s+)?(?:audio|sound|media)(?:\s+(?:element|file|playback|content|document))?)?[.!]?$/i;
  var germanFallback = /^(?:(?:ihr|dieser|der|ein|mein|dein)\s+)?browser\s+(?:(?:kann|k[oö]nnen)\s+(?:dieses?\s+)?(?:audio|tondokument|audiodokument|medium)?\s*(?:nicht|kein(?:e|en)?)\s+(?:wiedergeben|abspielen|unterst[uü]tzen)|unterst[uü]tzt\s+(?:die\s+)?(?:audio|tondokument|wiedergabe)\s+(?:nicht|kein(?:e|en)?))[.!]?$/i;
  return englishFallback.test(text) || germanFallback.test(text);
}

function articleAudioPromptNode(node) {
  if (!node || !node.matches || !node.closest("article, [itemprop~='articleBody' i]")) return false;
  if (!node.matches("[class~='audio-player' i], [id='audio-player' i], [data-component='audio-player' i], [data-testid='audio-player' i], [data-role='audio-player' i]")) return false;
  if (String(node.localName || "").indexOf("-") !== -1 || node.children.length !== 1) return false;

  var title = node.firstElementChild;
  if (!title || !title.matches("[class~='audio-player--title' i], [data-role='audio-player-title' i]") || title.children.length) return false;
  var text = normalizeText(title.textContent || "");
  if (!text || text.length > 80) return false;
  return /^(?:(?:listen(?:\s+to)?|play|slu[sš]aj)\s+(?:(?:this|the)\s+)?(?:article|story|news|report|vest)|read\s+(?:(?:(?:this|the)\s+)?(?:article|story|news|report|vest)\s+aloud|(?:it\s+)?aloud\s+(?:(?:this|the)\s+)?(?:article|story|news|report|vest)))[.!]?$/i.test(text);
}

function articleSyntheticSummaryControl(node) {
  if (!node.closest("article, [itemprop~='articleBody' i]") || codeContentNode(node)) return false;
  if (node.querySelector("p, article, h1, h2, h3, h4, a[href], button, img, video, audio, pre, code, table, ul, ol")) return false;
  var text = normalizeText(node.textContent || "");
  if (!text || text.length > 240) return false;
  return /^(?:ver resumen|view summary)(?=\s|tiempo|reading|$)/i.test(text) &&
    /(?:tiempo de lectura|reading time)/i.test(text) &&
    /(?:inteligencia artificial|artificial intelligence)/i.test(text);
}

function articleSourceOwnedActionPrompt(node) {
  if (!node.matches("p, div, span") || !node.closest("article") || codeContentNode(node)) return false;
  if (node.querySelector("p, article, h1, h2, h3, h4, a[href], button, img, picture, video, audio, pre, code, table, ul, ol, time")) return false;

  var text = normalizeText(node.textContent || "");
  var save = /^(?:save (?:this )?article|uložiť článok)$/i.test(text);
  var listen = /^listen to (?:this|the) (?:article|story) \d{1,3} (?:min(?:ute)?s?|sec(?:ond)?s?)$/i.test(text);
  if (!save && !listen) return false;

  var selectedArticle = node.closest("article");
  var sourceArticle = selectedArticle.id ? document.getElementById(selectedArticle.id) : document.querySelector("article");
  if (!sourceArticle || !sourceArticle.matches("article") ||
      (!selectedArticle.id && document.querySelectorAll("article").length !== 1)) return false;

  var matches = Array.from(sourceArticle.querySelectorAll("div, p, span")).filter(function(source) {
    return !elementSubtreeHidden(source) && normalizeText(source.textContent || "") === text;
  });
  if (matches.length !== 1) return false;
  var original = matches[0];
  if (original.querySelector("p, article, h1, h2, h3, h4, a[href], button, img, picture, video, audio, pre, code, table, ul, ol, time")) return false;
  var classes = original.getAttribute("class") || "";
  return save ? /(?:^|\s)(?:save-article|article-save)(?:\s|$)/i.test(classes) :
    /(?:^|[\s_-])player(?:[\s_-]|$)/i.test(classes);
}

function articlePlaceholderOwner(node, context) {
  var path = [];
  var current = node;
  var owner = null;
  while (current && current.nodeType === 1) {
    if (context && context.owners.has(current)) {
      owner = context.owners.get(current);
      break;
    }
    path.push(current);
    if (current.tagName === "ARTICLE") {
      owner = current;
      break;
    }
    var itemprop = String(current.getAttribute("itemprop") || "").toLowerCase().split(/\s+/);
    if (itemprop.indexOf("articlebody") !== -1) {
      owner = current;
      break;
    }
    current = current.parentElement;
  }
  if (context) path.forEach(function(ancestor) { context.owners.set(ancestor, owner); });
  return owner;
}

function articlePlaceholderSourceNode(node, context) {
  if (!node || !context) return null;
  var anchors = [node].concat(Array.from(node.querySelectorAll("[id]"))).filter(function(child) {
    return !!String(child.getAttribute("id") || "");
  });
  if (!anchors.length || anchors.some(function(anchor) {
    var sources = context.sourcesById.get(anchor.getAttribute("id")) || [];
    return sources.length !== 1;
  })) return null;

  for (var i = 0; i < anchors.length; i += 1) {
    var cloneAnchor = anchors[i];
    var source = context.sourcesById.get(cloneAnchor.getAttribute("id"))[0];
    var clone = cloneAnchor;
    while (clone && clone !== node && source) {
      clone = clone.parentElement;
      source = source.parentElement;
    }
    if (clone !== node || !source || source === node || !source.isConnected) continue;
    if (!source.isEqualNode(node)) continue;
    if ([source].concat(Array.from(source.querySelectorAll("*"))).some(function(child) {
      return !!composedDomShadowRoot(child) || String(child.localName || "").indexOf("-") !== -1;
    })) continue;
    return source;
  }
  return null;
}

function articlePlaceholderHasGeneratedVisual(source) {
  var view = source && source.ownerDocument && source.ownerDocument.defaultView;
  if (!source || !view || !view.getComputedStyle) return true;

  return [source].concat(Array.from(source.querySelectorAll("div, span"))).some(function(child) {
    try {
      if (normalizeText(child.innerText || "") || child.shadowRoot) return true;
      var rect = child.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) return true;
      var style = view.getComputedStyle(child);
      if (style && [style.backgroundImage, style.maskImage, style.borderImageSource, style.listStyleImage].some(function(value) {
        return value && value !== "none";
      })) return true;
      if (style && [style.boxShadow, style.filter].some(function(value) {
        return value && value !== "none";
      })) return true;
      if (style && style.outlineStyle && style.outlineStyle !== "none" && parseFloat(style.outlineWidth || "0") > 0) return true;
      return ["::before", "::after", "::marker"].some(function(pseudo) {
        var pseudoStyle = view.getComputedStyle(child, pseudo);
        var content = pseudoStyle && String(pseudoStyle.content || "");
        return !!(content && content !== "none" && content !== "normal");
      });
    } catch (_error) {
      return true;
    }
  });
}

function articlePlaceholderReferenced(node, context) {
  if (context.uncertain) return true;
  return [node].concat(Array.from(node.querySelectorAll("[id]"))).some(function(child) {
    var id = String(child.getAttribute("id") || "");
    return !!id && context.referencedIds.has(id);
  });
}

function articleEmptyAdPlaceholderNode(node, context) {
  if (!node || !node.matches || !node.matches("[data-placeholder-caption]")) return false;
  if (context.nestedPlaceholders.has(node) || !articlePlaceholderOwner(node, context)) return false;
  if (!/^(?:div|span)$/i.test(String(node.localName || ""))) return false;
  if (String(node.localName || "").indexOf("-") !== -1 || normalizeText(node.textContent || "")) return false;

  var descendants = [node].concat(Array.from(node.querySelectorAll("*")));
  if (node.querySelector("[data-placeholder-caption]")) return false;
  if (descendants.some(function(child) {
    if (!/^(?:div|span)$/i.test(String(child.localName || ""))) return true;
    return Array.from(child.attributes || []).some(function(attribute) {
      return !/^(?:id|class|data-placeholder-caption)$/i.test(attribute.name);
    });
  })) return false;
  var source = articlePlaceholderSourceNode(node, context);
  if (!source || articlePlaceholderHasGeneratedVisual(source) || articlePlaceholderReferenced(node, context)) return false;

  return descendants.some(function(child) {
    return articleAdStructureTokens(child).some(function(token) {
      return /^(?:ad|ads|advert|advertisement)$/.test(token);
    });
  });
}

function stripArticleWidgets(root) {
  var contentSelector = "article, main, section, h1, h2, h3, h4, h5, h6, p, blockquote, pre, table, figure";
  root.querySelectorAll("div, section, aside").forEach(function(node) {
    if (articleSyntheticSummaryControl(node)) node.remove();
  });
  var placeholders = Array.from(root.querySelectorAll("[data-placeholder-caption]"));
  if (root.matches && root.matches("[data-placeholder-caption]")) placeholders.unshift(root);
  var placeholderContext = placeholders.length ? articlePlaceholderContext(document) : null;
  if (placeholderContext) placeholderContext.nestedPlaceholders = articleNestedPlaceholderNodes(root);
  placeholders.forEach(function(node) {
    if (articleEmptyAdPlaceholderNode(node, placeholderContext)) node.remove();
  });

  root.querySelectorAll("[class*='audio' i], [id*='audio' i], [data-component*='audio' i], [data-testid*='audio' i], [data-role*='audio' i], [role*='audio' i], [aria-label*='audio' i]").forEach(function(node) {
    if (articleAudioControlNode(node) || articleAudioFallbackNode(node) || articleAudioPromptNode(node)) node.remove();
  });

  root.querySelectorAll("article p, article div, article span").forEach(function(node) {
    if (articleSourceOwnedActionPrompt(node)) node.remove();
  });

  root.querySelectorAll(".article-call-to-action, .article-cta, [data-role='article-call-to-action']").forEach(function(node) {
    if (!node.closest("article") || codeContentNode(node)) return;
    if (textLength(node) >= 600 || node.querySelector(contentSelector)) return;
    if (node.querySelector("a[href], button")) node.remove();
  });

  root.querySelectorAll(".loader, .main-loader, [role='status'][aria-busy='true']").forEach(function(node) {
    if (codeContentNode(node)) return;
    if (textLength(node) >= 300 || node.querySelector(contentSelector + ", a[href], time, img, picture, video, audio, [itemprop='author'], [itemprop='comment'], .author, .byline, .comment-body, .reply-body")) return;
    var owner = node.parentElement;
    while (owner) {
      var signature = [owner.id, owner.getAttribute("class"), owner.getAttribute("data-role")].filter(Boolean).join(" ");
      if (/(?:^|[\s_-])(?:comments?|recommendations?|related|read-more)(?:$|[\s_-])/i.test(signature)) {
        node.remove();
        return;
      }
      if (owner === root || owner.tagName === "ARTICLE") break;
      owner = owner.parentElement;
    }
  });
  return root;
}
