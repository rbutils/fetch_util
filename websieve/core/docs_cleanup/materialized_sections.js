  function physicalManualRenderedSections(metadata, context) {
    if (!context || nodeHasShadowContent(context.root) || elementSubtreeHidden(context.root)) return null;
    return withInertDomWork(function() {
      return renderPhysicalManualInertOwner(metadata, context);
    })();
  }

  function renderPhysicalManualInertOwner(metadata, context) {
    var visible = physicalManualVisibilityClone(context.root);
    if (context.generatedBook) {
      var callouts = Array.prototype.slice.call(visible.querySelectorAll("div.sidebar"));
      if (visible.matches("div.sidebar")) callouts.unshift(visible);
      callouts.forEach(function(callout) {
        if (callout.querySelector("div.titlepage h3.title") && callout.querySelector("p, pre") &&
            !callout.querySelector("form, input, button, select, textarea, [role='dialog']")) {
          callout.setAttribute("data-fetchutil-editorial-aside", "true");
        }
      });
      callouts.length = 0;
    }
    // Keep the proved document owner at the cleanup boundary. An invented
    // wrapper hides its article identity from ordinary consent classification.
    var cleanedOwner = cleanDisposableClone(visible);
    if (cleanedOwner !== visible) visible.replaceChildren();
    var clean = document.createElement("div");
    clean.appendChild(cleanedOwner);
    cleanupAgentRoot(clean);
    materializeHttpAttributes(clean, false, false);
    try {
      var renderedHtml = clean.innerHTML;
      // Public HTML is complete before the private working tree is consumed.
      // Neither Markdown preparation nor block conversion needs another whole
      // document representation alongside this already-owned inert root.
      var renderedMarkdown = markdownFromDisposableRoot(clean, false, true, true, turndownBlockUnits).trim();
      if (!renderedMarkdown) return null;
      return {
        title: context.title,
        byline: null,
        publishedTime: null,
        excerpt: context.lead,
        siteName: metadata.siteName || location.hostname,
        html: renderedHtml,
        markdown: renderedMarkdown,
        textContent: normalizeText(renderedMarkdown),
        docsLike: true,
        hostAware: false,
        readerMode: false,
        contentType: "article",
        sourceOwnedGeneratedDocs: true,
        sourceOwnedUnattributedManual: true,
        sourceOwnedCleanedManualHtml: renderedHtml,
        sourceOwnedMaterializedManualHtml: renderedHtml,
        sourceOwnedManualTitle: context.title,
        sourceOwnedArticlePublicationResolved: true
      };
    } finally {
      clean.replaceChildren();
      visible.replaceChildren();
    }
  }
