  function wordpressArticleHeader(body, article) {
    var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
      return !elementSubtreeHidden(node);
    });
    if (headings.length !== 1) return null;

    var heading = headings[0];
    var header = heading.closest("header, .entry-header, .post-header");
    if (!header || body.contains(header) || header.contains(body)) return null;
    if (!(header.compareDocumentPosition(body) & Node.DOCUMENT_POSITION_FOLLOWING)) return null;
    if (header.closest("article") === article) return header;

    var owner = article.closest("main, [role='main']") || article;
    if (header.nextElementSibling !== owner) return null;

    var bodies = Array.from(owner.querySelectorAll(WORDPRESS_ARTICLE_BODY_SELECTORS.concat([
      ".wp-block-post-content"
    ]).join(", "))).filter(function(node) { return !elementSubtreeHidden(node); });
    if (bodies.some(function(candidate) {
      return candidate !== body && !body.contains(candidate) && !candidate.contains(body) &&
        !candidate.closest("aside, nav, [role='complementary']");
    })) return null;
    return header;
  }

  function wordpressArticleHeaderLeads(body, article) {
    var header = wordpressArticleHeader(body, article);
    if (!header) return [];

    var heading = header.querySelector("h1");
    var leads = Array.from(header.querySelectorAll(
      ".article-excerpt, .entry-summary, .post-excerpt, [itemprop='description']"
    )).filter(function(node) {
      return !elementSubtreeHidden(node) && normalizeText(node.textContent || "") &&
        (heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) &&
        !node.closest("nav, aside, [role='navigation'], [role='complementary']");
    });
    return leads.filter(function(node) {
      return !leads.some(function(other) { return other !== node && other.contains(node); });
    });
  }

  function wordpressArticleHeaderContext(body) {
    var article = body && body.closest("article");
    if (!article || !body.isConnected) return body;

    var leads = wordpressArticleHeaderLeads(body, article);
    if (!leads.length) return body;

    var root = document.createElement("article");
    leads.forEach(function(lead) { root.appendChild(safeDeepClone(lead, document)); });
    root.appendChild(safeDeepClone(body, document));
    return root;
  }
