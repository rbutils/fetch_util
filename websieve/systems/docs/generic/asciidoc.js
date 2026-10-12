function asciidocDocsContext(metadata) {
  var generators = Array.prototype.map.call(document.querySelectorAll("meta[name='generator' i]"), function(node) {
    return normalizeText(node.getAttribute("content")).toLowerCase();
  }).filter(Boolean);
  if (generators.length !== 1 || !/^asciidoctor(?:\s|$)/.test(generators[0])) return null;
  if (!/(?:^|\/)(?:docs?|documentation|manuals?|reference|api|tutorials?|guides?)(?:\/|$)/i.test(location.pathname || "")) return null;

  var headers = document.querySelectorAll("#header");
  var bodies = document.querySelectorAll("#content");
  if (headers.length !== 1 || bodies.length !== 1) return null;
  var header = headers[0];
  var body = bodies[0];
  if (header.parentElement !== body.parentElement || header.nextElementSibling !== body ||
      elementSubtreeHidden(header) || elementSubtreeHidden(body) ||
      sourceOwnershipInChrome(header) || sourceOwnershipInChrome(body)) return null;
  var headings = header.querySelectorAll("h1");
  if (headings.length !== 1 || body.querySelector("h1") || elementSubtreeHidden(headings[0])) return null;
  var title = normalizeText(headings[0].textContent);
  var pageTitle = normalizeText(document.title || metadata && metadata.title || "");
  if (!title || pageTitle !== title) return null;
  var sections = Array.prototype.some.call(body.querySelectorAll(".sect1 h2, .sect2 h3"), function(node) {
    return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node) && normalizeText(node.textContent);
  });
  var examples = Array.prototype.some.call(body.querySelectorAll(".listingblock pre code[data-lang], .listingblock pre code[class*='language-']"), function(node) {
    return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node) && normalizeText(node.textContent);
  });
  var prose = Array.prototype.some.call(body.querySelectorAll("p"), function(node) {
    return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node) && normalizeText(node.textContent);
  });
  return sections && examples && prose ? { header: header, body: body, title: title } : null;
}

function asciidocHeaderToc(header, body) {
  var candidates = header.querySelectorAll("#toc");
  if (candidates.length !== 1) return null;
  var toc = candidates[0];
  if (toc.querySelector("p, pre, code, table, dl, blockquote")) return null;
  var targets = new Set(Array.prototype.map.call(body.querySelectorAll("[id]"), function(node) {
    return node.getAttribute("id");
  }));
  var links = Array.prototype.slice.call(toc.querySelectorAll("a[href]"));
  if (!links.length || !links.every(function(link) {
    var href = link.getAttribute("href");
    if (!samePageFragmentLink(href)) return false;
    try { return targets.has(decodeURIComponent(href.slice(href.indexOf("#") + 1))); } catch (_error) { return false; }
  })) return null;
  var remaining = toc.cloneNode(true);
  remaining.querySelectorAll("a, #toctitle").forEach(function(node) { node.remove(); });
  return normalizeText(remaining.textContent) ? null : toc;
}

function asciidocDocsContent(metadata, info) {
  if (info && info.system !== "asciidoc") return null;
  var context = asciidocDocsContext(metadata);
  if (!context || structuredSourceRecordOwnership(metadata)) return null;
  var toc = asciidocHeaderToc(context.header, context.body);
  var content = docsContentForNode(metadata, context.body, {
    title: context.title,
    focusFragment: false,
    hostAware: false,
    preserveAuthoredSections: true,
    rewriteRoot: function(root) {
      var header = cleanClone(context.header);
      if (toc) header.querySelectorAll("#toc").forEach(function(node) { node.remove(); });
      cleanupAgentRoot(header);
      root.insertBefore(header, root.firstChild);
    }
  });
  if (content) content.sourceOwnedGeneratedDocs = true;
  return content;
}
