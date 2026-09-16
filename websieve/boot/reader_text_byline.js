function readerTextBylineName(value) {
  return normalizeText(sanitizeByline(value) || "").replace(
    /^(?:by|por|par|von|di|da|door|av|af|de|autor(?:a)?|auteur|redactie|redacción|redacao|redação|penulis|oleh|tác giả|tac gia|بقلم|כתבת?|מאת)\s*:?\s+/i,
    ""
  );
}

function readerTextBylineMarker(node) {
  if (!node || node.nodeType !== 1) return false;
  if (node.matches("[itemprop='author'], [itemprop='author'] [itemprop='name']")) return true;
  var attrs = [node.getAttribute("class"), node.getAttribute("data-testid")].filter(Boolean).join(" ");
  return /(?:^|[\s_-])(?:author|byline)(?:$|[\s_-])/i.test(attrs);
}

function readerTextBylineSourceNode(node, root, metadataName) {
  var current = node;
  var sourceNode = null;
  while (current && current !== root) {
    var currentName = readerTextBylineName(current.textContent || "");
    if (currentName.toLowerCase() !== metadataName.toLowerCase()) {
      if (current.matches("p, address")) return null;
      break;
    }
    if (readerTextBylineMarker(current) || current.matches("p, address")) sourceNode = current;
    current = current.parentElement;
  }
  return sourceNode;
}

function readerTextBylineLocalOwner(node, root) {
  function ownershipAttributes(element) {
    return [
      element.getAttribute("class"),
      element.getAttribute("id"),
      element.getAttribute("itemprop"),
      element.getAttribute("data-testid")
    ].filter(Boolean).join(" ");
  }

  function plainTextDateMetadata(value) {
    var text = normalizeText(value || "").replace(/^[|·•,;:—–-]+\s*/, "");
    return text.length <= 80 && /\b(?:19|20)\d{2}\b/.test(text) && !isNaN(Date.parse(text));
  }

  var narrativePattern = /(?:^|[\s_-])(?:story|narrative|content|body|summary|description)(?:$|[\s_-])/i;
  if (narrativePattern.test(ownershipAttributes(node))) return false;
  var owner = node.parentElement && node.parentElement.closest("p, address, div, header, section");
  if (!owner || owner === root) return node.matches("p, address, div");
  var ownerAttrs = ownershipAttributes(owner);
  if (/(?:^|[\s_-])(?:story|narrative|summary|description)(?:$|[\s_-])/i.test(ownerAttrs)) return false;
  if (!node.matches("p, address, div") && /(?:^|[\s_-])(?:content|body)(?:$|[\s_-])/i.test(ownerAttrs)) return false;
  var inlineContinuation = Array.prototype.some.call(owner.childNodes, function(sibling) {
    if (sibling === node) return false;
    if (sibling.nodeType === Node.TEXT_NODE) {
      var value = sibling.nodeValue || "";
      return /[\p{L}\p{N}]/u.test(value) && !plainTextDateMetadata(value);
    }
    if (sibling.nodeType !== Node.ELEMENT_NODE || !sibling.matches("span, b, strong, em, i, small, sup")) return false;
    var siblingAttrs = ownershipAttributes(sibling);
    if (/(?:^|[\s_-])(?:date|time|published|updated|source|separator)(?:$|[\s_-])/i.test(siblingAttrs)) return false;
    return !!normalizeText(sibling.textContent || "");
  });
  if (inlineContinuation) return false;
  if (node.matches("p, address, div")) return true;
  if (normalizeText(owner.textContent || "") === normalizeText(node.textContent || "")) return true;
  return /(?:^|[\s_-])(?:author|byline|credit|meta)(?:$|[\s_-])/i.test(ownerAttrs);
}

function readerTextBylineSource(content, metadataByline) {
  var metadataName = readerTextBylineName(metadataByline);
  var contentName = readerTextBylineName(content.byline);
  var words = metadataName.split(/\s+/).filter(Boolean);
  if (!metadataName || words.length < 2 || words.length > 8 || contentName.toLowerCase() !== metadataName.toLowerCase()) return null;

  var context = readerBylineSourceContext(content);
  if (!context) return null;
  var root = context.root;
  for (var outer = root; outer && outer !== document.body; outer = outer.parentElement) {
    if (relatedMetadataOwner(outer)) return null;
  }

  var selector = "[itemprop='author'], [itemprop='author'] [itemprop='name'], [class*='byline' i], [data-testid*='author' i], [data-testid*='byline' i]";
  var candidates = [];
  var seen = new Set();
  var ambiguous = false;
  Array.prototype.forEach.call(root.querySelectorAll(selector), function(node) {
    if (!readerTextBylineMarker(node) || node.querySelector(selector)) return;
    var sourceNode = readerTextBylineSourceNode(node, root, metadataName);
    if (!sourceNode || !readerTextBylineLocalOwner(sourceNode, root)) {
      ambiguous = true;
      return;
    }
    if (seen.has(sourceNode)) return;
    seen.add(sourceNode);
    if (readerBylineHtmlHidden(node, root) || readerBylineHtmlHidden(sourceNode, root) || sourceNode.closest("nav, footer, aside") || sourceNode.closest("article") !== root) return;
    if (!(sourceNode.compareDocumentPosition(context.firstParagraph) & Node.DOCUMENT_POSITION_FOLLOWING)) return;
    if (sourceNode.querySelector("a[href], p, ul, ol, dl, table, figure, blockquote, pre, form, details")) {
      ambiguous = true;
      return;
    }
    for (var owner = sourceNode; owner && owner !== root; owner = owner.parentElement) {
      if (relatedMetadataOwner(owner) || /(?:comment|reply)/i.test(visibleMetadataOwnerText(owner))) {
        ambiguous = true;
        return;
      }
    }
    var sourceText = normalizeText(sourceNode.textContent || "");
    var sourceName = readerTextBylineName(sourceText);
    if (!sourceText || sourceText.length > 160 || sourceName.toLowerCase() !== metadataName.toLowerCase()) {
      ambiguous = true;
      return;
    }
    candidates.push({
      name: metadataName,
      text: sourceText,
      firstParagraphText: normalizeText(context.firstParagraph.textContent || ""),
      sourceNode: sourceNode
    });
  });
  if (ambiguous || candidates.length !== 1) return null;
  var candidate = candidates[0];
  var duplicateSourceIdentity = Array.prototype.some.call(root.querySelectorAll("h1, h2, h3, h4, h5, h6, p, address, div, span"), function(node) {
    if (candidate.sourceNode === node || candidate.sourceNode.contains(node) || node.contains(candidate.sourceNode)) return false;
    if (readerBylineHtmlHidden(node, root)) return false;
    if (!(node.compareDocumentPosition(context.firstParagraph) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
    var text = normalizeText(node.textContent || "");
    if (!text || readerTextBylineName(text).toLowerCase() !== metadataName.toLowerCase()) return false;
    return !Array.prototype.some.call(node.children, function(child) {
      return normalizeText(child.textContent || "") === text;
    });
  });
  if (duplicateSourceIdentity) return null;
  return {
    name: candidate.name,
    text: candidate.text,
    firstParagraphText: candidate.firstParagraphText
  };
}

function readerTextBylineHtmlHasText(root, author) {
  var body = Array.prototype.find.call(root.querySelectorAll("p"), function(node) {
    return normalizeText(node.textContent || "") === author.firstParagraphText;
  });
  if (!body) {
    body = Array.prototype.find.call(root.querySelectorAll("p"), function(node) {
      return normalizeText(node.textContent || "").length >= 80;
    });
  }
  return Array.prototype.some.call(root.querySelectorAll("*"), function(node) {
    if (readerBylineHtmlHidden(node, root) || node.closest("nav, footer, aside, pre, code")) return false;
    if (body && !(node.compareDocumentPosition(body) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
    if (!readerTextBylineMarker(node) && !node.matches("p, address, [data-fetchutil-reader-byline]")) return false;
    for (var owner = node; owner && owner !== root; owner = owner.parentElement) {
      if (relatedMetadataOwner(owner) || /(?:comment|reply)/i.test(visibleMetadataOwnerText(owner))) return false;
    }
    var text = normalizeText(node.textContent || "");
    if (text !== author.text) return false;
    if (readerTextBylineMarker(node) || node.hasAttribute("data-fetchutil-reader-byline")) return true;
    return !Array.prototype.some.call(node.children, function(child) {
      return normalizeText(child.textContent || "") === text;
    });
  });
}

function readerTextBylineMarkdownHasText(markdown, author) {
  var represented = false;
  var fenced = false;
  markdown.split("\n").some(function(line) {
    if (/^\s*(?:```|~~~)/.test(line)) {
      fenced = !fenced;
      return false;
    }
    if (fenced) return false;
    var structuredLine = /^\s*(?:#{1,6}\s|>|[-*+]\s|\d+[.)]\s|!?\[|\|)/.test(line);
    var text = normalizeText(line
      .replace(/!\[([^\]]*)\]\([^)]*\)/g, "$1")
      .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
      .replace(/[`*_]/g, ""));
    if (!structuredLine && text === author.text) represented = true;
    if (text === author.firstParagraphText || (!structuredLine && text.length >= 80)) return true;
    return false;
  });
  return represented;
}

function readerTextBylineTextHasText(textContent, author) {
  var byline = normalizeText(author.text || "");
  var fullText = normalizeText(textContent || "");
  if (fullText === byline || fullText.indexOf(byline + " ") === 0) return true;
  return String(textContent || "").split(/\r?\n/).some(function(line) {
    return normalizeText(line) === byline;
  });
}

function supplementReaderTextByline(content, author) {
  if (!author) return content;
  var root = document.createElement("div");
  root.innerHTML = content.html || "";
  var htmlRepresented = readerTextBylineHtmlHasText(root, author);
  if (!htmlRepresented) {
    var paragraph = document.createElement("p");
    paragraph.setAttribute("data-fetchutil-reader-byline", "");
    paragraph.textContent = author.text;
    var heading = root.querySelector("h1");
    if (heading) heading.insertAdjacentElement("afterend", paragraph);
    else root.insertBefore(paragraph, root.firstChild);
  }

  var markdown = content.markdown;
  var markdownRepresented = markdown && readerTextBylineMarkdownHasText(markdown, author);
  if (markdown && !markdownRepresented) {
    var lines = markdown.split("\n");
    var headingLine = readerBylineMarkdownHeadingLine(markdown);
    if (headingLine >= 0) lines.splice(headingLine + 1, 0, "", author.text);
    else lines.unshift(author.text, "");
    markdown = lines.join("\n");
  }

  var textContent = normalizeText(content.textContent || "");
  if (!readerTextBylineTextHasText(content.textContent, author)) textContent = normalizeText(author.text + " " + textContent);
  if (htmlRepresented && markdown === content.markdown && textContent === normalizeText(content.textContent || "")) return content;
  return Object.assign({}, content, { html: root.innerHTML, markdown: markdown, textContent: textContent });
}
