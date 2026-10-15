  function physicalTechnicalOwnerChrome(node, root) {
    if (node.closest("nav, aside, footer, form, menu, [role~='navigation' i], [role~='menu' i], [role~='complementary' i]")) return true;
    var component = node.closest("[class*='sidebar' i], [id*='sidebar' i], [class*='sidemenu' i], [id*='sidemenu' i], " +
      "[class*='side-menu' i], [id*='side-menu' i], [class*='recommend' i], [id*='recommend' i], [class*='related-posts' i], [id*='related-posts' i]");
    return !!component && root.contains(component);
  }

  function physicalTechnicalDocsContext(metadata) {
    var roots = document.querySelectorAll("main, [role='main']");
    if (!roots.length) roots = Array.prototype.filter.call(document.querySelectorAll("article"), function(node) {
      return !node.parentElement.closest("article") && !commentRecordMarker(node);
    });
    if (!roots.length) roots = Array.prototype.filter.call(document.querySelectorAll("div.book"), function(node) {
      var titlepages = Array.prototype.filter.call(node.children, function(child) { return child.matches("div.titlepage"); });
      var chapters = Array.prototype.filter.call(node.children, function(child) { return child.matches("div.chapter"); });
      return !node.parentElement.closest("div.book") && titlepages.length === 1 &&
        titlepages[0].querySelectorAll("h1.title").length === 1 && chapters.length > 0 &&
        chapters.every(function(chapter) { return chapter.querySelector("div.titlepage h2.title"); }) &&
        !!node.querySelector("div.chapter pre.programlisting, div.chapter pre.screen");
    });
    if (roots.length !== 1) return null;
    var root = roots[0];
    var headings = root.querySelectorAll("h1");
    if (headings.length !== 1) return null;
    var title = cleanDocsHeadingText(headings[0].textContent);
    if (!title) return null;
    var titles = [document.title, metadata && metadata.title].concat(Array.prototype.map.call(
      document.querySelectorAll("meta[property='og:title']"), function(node) { return node.getAttribute("content"); }
    )).map(function(value) { return normalizeText(value || ""); }).filter(Boolean);
    if (!titles.length || !titles.every(function(value) {
      if (value === title) return true;
      return value.indexOf(title) === 0 && /^(?:-|\||\u2013|\u2014)\s+\S/.test(normalizeText(value.slice(title.length)));
    })) return null;

    var declarations = root.querySelectorAll("[itemscope][itemtype~='http://schema.org/TechArticle'], " +
      "[itemscope][itemtype~='https://schema.org/TechArticle']");
    if (declarations.length > 1) return null;
    var declared = declarations.length === 1;
    var generatedBook = root.matches("div.book") && /\b\d+\.\d+(?:\.\d+)*\b/.test(title);
    if (!declared && !generatedBook && !/\b(?:reference|manual|documentation|handbook|tutorial|specification|api)\b/i.test(title)) return null;
    if (elementSubtreeHidden(root) || physicalTechnicalOwnerChrome(root, root) ||
        elementSubtreeHidden(headings[0]) || physicalTechnicalOwnerChrome(headings[0], root)) return null;
    if (declared && (elementSubtreeHidden(declarations[0]) || physicalTechnicalOwnerChrome(declarations[0], root))) return null;
    var prose = Array.prototype.find.call(root.querySelectorAll("p"), function(node) {
      return !elementSubtreeHidden(node) && !physicalTechnicalOwnerChrome(node, root) && normalizeText(node.textContent);
    });
    var sections = Array.prototype.some.call(root.querySelectorAll("h2, h3"), function(node) {
      return !elementSubtreeHidden(node) && !physicalTechnicalOwnerChrome(node, root) && normalizeText(node.textContent);
    });
    var examples = Array.prototype.some.call(root.querySelectorAll("pre code[class*='language-'], pre code[data-lang], .highlight pre, pre.literal-block, div.book pre.programlisting, div.book pre.screen"), function(node) {
      return !elementSubtreeHidden(node) && !physicalTechnicalOwnerChrome(node, root) && normalizeText(node.textContent);
    });
    return prose && sections && examples ? {
      root: root, title: title, generatedBook: generatedBook, lead: normalizeText(prose.textContent)
    } : null;
  }

  function physicalTechnicalDocsContent(metadata) {
    var context = physicalTechnicalDocsContext(metadata);
    if (!context) return null;
    if (context.generatedBook || context.root.matches("article")) {
      var sections = physicalManualRenderedSections(metadata, context);
      if (sections) return sections;
    }
    var content = docsContentForNode(metadata, context.root, {
      title: context.title,
      hostAware: false,
      focusFragment: false,
      pruneSourceVisibility: true,
      preserveAuthoredSections: true
    });
    if (content) content.sourceOwnedGeneratedDocs = true;
    return content;
  }

  function physicalStandaloneManualContent(metadata) {
    if (document.querySelector("main, [role='main']:not(article)")) return null;
    var context = physicalTechnicalDocsContext(metadata);
    return context && (context.generatedBook || context.root.matches("article")) ?
      physicalManualRenderedSections(metadata, context) : null;
  }
