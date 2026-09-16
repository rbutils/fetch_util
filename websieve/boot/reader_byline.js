function readerBylineInitials(value) {
  var initials = [];
  normalizeText(value || "").split(/\s+/).filter(Boolean).forEach(function(word, index) {
    word.split(/['’\-‐-―]+/u).filter(Boolean).forEach(function(part) {
      if (index > 0 && /\p{Ll}/u.test(part) && !/\p{Lu}/u.test(part)) return;
      var initial = Array.from(part).find(function(character) { return /[\p{L}\p{N}]/u.test(character); });
      if (initial) initials.push(initial.toLocaleLowerCase());
    });
  });
  return initials.join("");
}

function readerBylineSourceContext(content) {
  var selected = document.createElement("div");
  selected.innerHTML = content.html || "";
  var sourceParagraphs = Array.from(document.querySelectorAll("article p")).filter(function(paragraph) {
    return !elementSubtreeHidden(paragraph);
  });
  var owners = [];
  var matchedParagraphs = [];
  var ambiguous = Array.from(selected.querySelectorAll("p")).some(function(paragraph) {
    var text = normalizeText(paragraph.textContent || "");
    if (text.length < 80) return false;
    var matches = sourceParagraphs.filter(function(source) {
      return normalizeText(source.textContent || "") === text;
    });
    if (matches.length > 1) return true;
    if (matches.length === 1) {
      owners.push(matches[0].closest("article"));
      matchedParagraphs.push(matches[0]);
    }
    return false;
  });
  var uniqueOwners = new Set(owners.filter(Boolean));
  if (ambiguous || owners.length < 2 || uniqueOwners.size !== 1) return null;
  matchedParagraphs.sort(function(left, right) {
    return left === right ? 0 : (left.compareDocumentPosition(right) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1);
  });
  return { root: owners[0], firstParagraph: matchedParagraphs[0] };
}

function readerBylineSourceAuthorLink(content, metadataByline) {
  var metadataName = normalizeText(metadataByline || "");
  var metadataWords = metadataName.split(/\s+/).filter(Boolean);
  if (!metadataName || metadataWords.length < 2 || metadataWords.length > 8) return null;
  var initials = readerBylineInitials(metadataName);

  var context = readerBylineSourceContext(content);
  if (!context) return null;
  var root = context.root;
  for (var outer = root; outer && outer !== document.body; outer = outer.parentElement) {
    if (relatedMetadataOwner(outer)) return null;
  }
  var links = [];
  var ambiguousIdentity = false;
  Array.prototype.forEach.call(root.querySelectorAll("a[rel~='author'][href][title]"), function(link) {
    if (elementVisuallyHidden(link) || link.closest("nav, footer, aside")) return false;
    if (link.closest("article") !== root) return null;
    if (!(link.compareDocumentPosition(context.firstParagraph) & Node.DOCUMENT_POSITION_FOLLOWING)) return null;
    var owner = link.parentElement;
    while (owner && owner !== root) {
      if (relatedMetadataOwner(owner)) return null;
      owner = owner.parentElement;
    }
    var sourceName = sanitizeByline(link.textContent);
    var compactSourceName = sourceName.replace(/[^\p{L}\p{N}]+/gu, "").toLowerCase();
    var sameName = sourceName.toLowerCase() === metadataName.toLowerCase();
    if (sanitizeByline(link.getAttribute("title")) !== metadataName || (!sameName && compactSourceName !== initials)) return null;
    var url = materializedHttpUrl(link.getAttribute("href"));
    if (!url || new URL(url).origin !== location.origin) {
      ambiguousIdentity = true;
      return null;
    }
    links.push({ url: url, sourceName: sourceName });
  });
  if (ambiguousIdentity) return null;
  var urls = new Set(links.map(function(link) { return link.url; }));
  if (urls.size !== 1) return null;
  return {
    name: metadataName,
    url: Array.from(urls)[0],
    sourceNames: Array.from(new Set(links.map(function(link) { return link.sourceName; })))
  };
}

function readerBylineCanExpand(content, author) {
  var contentName = normalizeText(content.byline || "");
  if (!contentName || !author || contentName.toLowerCase() === author.name.toLowerCase()) return false;
  var compactContentName = contentName.replace(/[^\p{L}\p{N}]+/gu, "").toLowerCase();
  var sourceNames = author.sourceNames.map(function(name) { return normalizeText(name).toLowerCase(); });
  return sourceNames.indexOf(contentName.toLowerCase()) !== -1 && compactContentName === readerBylineInitials(author.name);
}

function readerBylineMarkdownHasAuthor(markdown, author) {
  var names = [author.name].concat(author.sourceNames || []).map(function(name) { return normalizeText(name).toLowerCase(); });
  for (var position = 0; position < markdown.length; position += 1) {
    if (markdownLineStart(markdown, position)) {
      var fence = markdownFencedCodeAt(markdown, position);
      if (fence) {
        position = fence.end - 1;
        continue;
      }
    }
    var code = markdownCodeSpanAt(markdown, position);
    if (code) {
      position = code.end - 1;
      continue;
    }
    if (markdown[position] !== "[" && markdown[position] !== "!") continue;
    var link = inlineMarkdownLinkAt(markdown, position);
    if (!link) continue;
    var label = normalizeText(link.label.replace(/[`*_]/g, "")).toLowerCase();
    if (!link.image && names.indexOf(label) !== -1 && materializedHttpUrl(link.url) === author.url) return true;
    position = link.end - 1;
  }
  return false;
}

function readerBylineHtmlHidden(link, root) {
  for (var current = link; current; current = current.parentElement) {
    if (current.hidden || current.getAttribute("aria-hidden") === "true") return true;
    var style = current.style;
    if (style && (style.display === "none" || style.visibility === "hidden" || style.visibility === "collapse" || (style.opacity !== "" && Number(style.opacity) === 0))) return true;
    if (current === root) break;
  }
  return false;
}

function readerBylineHtmlHasAuthor(root, author) {
  var names = [author.name].concat(author.sourceNames || []).map(function(name) { return normalizeText(name).toLowerCase(); });
  return Array.prototype.some.call(root.querySelectorAll("a[rel~='author'][href]"), function(link) {
    if (readerBylineHtmlHidden(link, root) || link.closest("nav, footer, aside")) return false;
    for (var owner = link.parentElement; owner; owner = owner.parentElement) {
      if (relatedMetadataOwner(owner)) return false;
      if (owner === root) break;
    }
    var name = normalizeText(sanitizeByline(link.textContent) || "").toLowerCase();
    return names.indexOf(name) !== -1 && materializedHttpUrl(link.getAttribute("href")) === author.url;
  });
}

function readerBylineMarkdownHeadingLine(markdown) {
  for (var position = 0; position < markdown.length;) {
    var fence = markdownFencedCodeAt(markdown, position);
    if (fence) {
      position = fence.end;
      if (markdown[position] === "\n") position += 1;
      continue;
    }
    var lineEnd = markdown.indexOf("\n", position);
    if (lineEnd === -1) lineEnd = markdown.length;
    if (/^#\s+/.test(markdown.slice(position, lineEnd))) {
      return markdown.slice(0, position).split("\n").length - 1;
    }
    position = lineEnd + 1;
  }
  return -1;
}

function supplementReaderBylineLink(content, author) {
  if (!author) return content;
  var root = document.createElement("div");
  root.innerHTML = content.html || "";
  var htmlRepresented = readerBylineHtmlHasAuthor(root, author);
  if (!htmlRepresented) {
    var paragraph = document.createElement("p");
    var link = document.createElement("a");
    link.setAttribute("href", author.url);
    link.setAttribute("rel", "author");
    link.textContent = author.name;
    paragraph.appendChild(link);
    var heading = root.querySelector("h1");
    if (heading) heading.insertAdjacentElement("afterend", paragraph);
    else root.insertBefore(paragraph, root.firstChild);
  }

  var markdown = content.markdown;
  if (markdown && !readerBylineMarkdownHasAuthor(markdown, author)) {
    var authorMarkdown = markdownLink(author.name, author.url);
    var lines = markdown.split("\n");
    var headingLine = readerBylineMarkdownHeadingLine(markdown);
    if (headingLine >= 0) {
      lines.splice(headingLine + 1, 0, "", authorMarkdown);
    } else {
      lines.unshift(authorMarkdown, "");
    }
    markdown = lines.join("\n");
  }

  var textContent = normalizeText(content.textContent || "");
  if (textContent.indexOf(author.name) === -1) textContent = normalizeText(author.name + " " + textContent);
  if (htmlRepresented && markdown === content.markdown && textContent === normalizeText(content.textContent || "")) return content;
  return Object.assign({}, content, { html: root.innerHTML, markdown: markdown, textContent: textContent });
}
