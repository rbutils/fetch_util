function listMarkdownImageCounts(markdown) {
  var counts = new Map();
  var pending = [String(markdown || "")];
  while (pending.length) {
    var value = pending.pop();
    var position = 0;
    while (position < value.length) {
      if (markdownLineStart(value, position)) {
        var fence = markdownFencedCodeAt(value, position);
        if (fence) {
          position = fence.end;
          continue;
        }
        // This scanner never rewrites the preceding source. The container
        // predicate only needs its unchanged terminal newline.
        var indented = markdownIndentedCodeAt(value, position, position ? "\n" : "");
        if (indented) {
          position = indented.end;
          continue;
        }
      }
      var code = markdownCodeSpanAt(value, position);
      if (code) {
        position = code.end;
        continue;
      }
      var link = inlineMarkdownLinkAt(value, position);
      if (link) {
        if (link.image) {
          var url = materializedHttpUrl(link.url);
          if (url) counts.set(url, (counts.get(url) || 0) + 1);
        } else {
          pending.push(link.label);
        }
        position = link.end;
        continue;
      }
      position += 1;
    }
  }
  return counts;
}

function listImageCountsOmitted(expected, actual) {
  var omitted = false;
  expected.forEach(function(count, url) {
    if ((actual.get(url) || 0) < count) omitted = true;
  });
  return omitted;
}

function convertListBodyMarkdown(service, root) {
  var escape = service.escape;
  service.escape = function(text) {
    // Entity-shaped source text must stay literal after CommonMark parsing.
    // Ordinary ampersands and code nodes retain their existing conversions.
    return escape.call(this, text).replace(/&(?=(?:#[0-9]+|#x[0-9a-f]+|[a-z][a-z0-9]*);)/gi, "\\&");
  };
  return service.turndown(root);
}

function listBodyMarkdownHtml(root) {
  var clone = root.cloneNode(true);
  var literalOwners = "pre, code, kbd, samp, svg, math";
  // Wrapper preparation can unwrap DIVs. Retain their physical word boundary
  // in this disposable representation, without changing literal program text.
  clone.querySelectorAll("div").forEach(function(node) {
    if (node.closest(literalOwners)) return;
    node.insertBefore(node.ownerDocument.createTextNode(" "), node.firstChild);
    node.appendChild(node.ownerDocument.createTextNode(" "));
  });
  clone.querySelectorAll("a[href]").forEach(function(link) {
    if (link.closest(literalOwners)) return;
    if (!materializedHttpUrl(link.getAttribute("href"))) return;
    var blockOwned = !!link.querySelector("div");
    var empty = !normalizeText(link.textContent) && !link.querySelector("img, svg, math, video, audio, input, button");
    if (!blockOwned && !empty) return;
    // Whitespace collapse discards spaces beside a link containing a block.
    // Preserve that physical break; an empty inline destination only needs space.
    var before = blockOwned ? link.ownerDocument.createElement("br") : link.ownerDocument.createTextNode(" ");
    var after = blockOwned ? link.ownerDocument.createElement("br") : link.ownerDocument.createTextNode(" ");
    link.parentNode.insertBefore(before, link);
    link.parentNode.insertBefore(after, link.nextSibling);
  });
  return listHtmlWithoutUnsafeDestinations(clone);
}

function preserveListBodyImageMarkdown(extraction) {
  var root = extraction.root;
  var structuredOwners = "article, ul, ol, [role~='article' i], [role~='list' i], " +
    "[role~='listitem' i], [role='tabpanel'], [aria-roledescription='slide' i]";
  if (extraction.sourceTableMarkdown || root.matches(structuredOwners) || root.querySelector(structuredOwners)) return;
  if (!root.querySelector("h1, h2, h3, h4, h5, h6") || !root.querySelector("p")) return;

  var images = new Map();
  root.querySelectorAll("img").forEach(function(image) {
    if (image.closest("pre, code, kbd, samp")) return;
    var url = materializedHttpUrl(image.getAttribute("src"));
    if (url) images.set(url, (images.get(url) || 0) + 1);
  });
  if (!images.size) return;
  var represented = listMarkdownImageCounts(extraction.markdown);
  if (!listImageCountsOmitted(images, represented)) return;

  var complete = markdownFor(listBodyMarkdownHtml(root), false, false, true, convertListBodyMarkdown);
  // The ordinary converter applies disclosure and program semantics. A closed
  // body or literal image syntax must not trigger a synthetic representation.
  if (!listImageCountsOmitted(listMarkdownImageCounts(complete), represented)) return;
  extraction.sourceBodyMarkdown = complete;
  extraction.markdown = complete;
}
