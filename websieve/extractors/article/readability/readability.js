  function readabilityContent(metadata) {
    if (typeof Readability !== "function") return null;

    try {
      var comments = visibleCommentMarkup(document);
      var clone = safeReadableDocumentClone();
      var sourceClones = new Map();
      pruneHiddenClone(document.documentElement, clone.documentElement, null, null, null, sourceClones);
      materializeArticleOwnedFooters(clone);
      stripSourceOwnedEngagementClusters(document.documentElement, clone.documentElement, sourceClones);
      var ownership = resolveCanonicalArticleBodyOwnership() || sourceOwnedSemanticArticleOwnership(metadata).ownership;
      var selectedOwner = ownership && ownership.titleIdentityProven !== false && sourceClones.get(ownership.ownerRoot);
      if (selectedOwner && clone.body && selectedOwner !== clone.body && clone.body.contains(selectedOwner)) {
        clone.body.replaceChildren(selectedOwner);
      }
      stripSourceOwnedTerminalArticleFurniture(clone.documentElement, sourceClones);
      materializeEditorialFrameLinks(document.documentElement, clone.documentElement, sourceClones);
      clone.querySelectorAll("a[href]").forEach(function(node) {
        if (articleCommentCountControl(node)) node.remove();
      });
      stripGoogleSourcePreferenceControl(document.documentElement, clone.documentElement, sourceClones);
      var conflictingSourceBylines = new Set();
      stripPublisherCtaNotes(clone);
      var excerptMarker = markReadabilityExcerptSources(clone);
      var sourceIdentities = markReadabilitySourceNodeProvenance(clone, sourceClones, excerptMarker);
      var sectionHeadings = readerSectionHeadingSnapshots(clone, metadata, sourceClones, sourceIdentities, excerptMarker);
      var declaredByline = normalizeText(readerTextBylineName(metadata && metadata.declaredByline || ""));
      if (declaredByline) {
        sourceClones.forEach(function(_readableClone, source) {
          if (source.localName !== "p" || elementSubtreeHidden(source)) return;
          var sourceMarker = [source.getAttribute("class"), source.id, source.getAttribute("itemprop"), source.getAttribute("rel")]
            .filter(Boolean).join(" ");
          if (!/(?:^|[\s_-])(?:author|byline|writers?)(?:$|[\s_-])/i.test(sourceMarker)) return;
          var visible = normalizeText(readerTextBylineName(source.textContent || ""));
          if (visible && visible.toLowerCase() !== declaredByline.toLowerCase()) conflictingSourceBylines.add(source);
        });
      }
      normalizeCodeSurfaces(clone);
      if (commentOnlyRoot(clone)) return null;
      prepareInlineArticleProse(clone);
      cleanupCookieChrome(clone);
      markTerminalArticleLinkCollections(clone);
      var mediaWikiLike = !!document.querySelector("#mw-content-text .mw-parser-output, #bodyContent .mw-parser-output, .mw-parser-output");
      if (!mediaWikiLike) cleanupAgentRoot(clone);
      cleanupGenericArticleRoot(clone);
      stripSourceOwnedCitationActions(clone.documentElement);
      var definitionClass = prepareReadabilityOwnedDefinitions(clone, sourceClones, excerptMarker);
      var cardActions = prepareReadabilityOwnedCardActions(clone, sourceClones, excerptMarker);
      var headingRoles = readabilityRetainedHeadingRoleSnapshots(clone, sourceClones, sourceIdentities);
      var reader = new Readability(clone);
      var checkByline = reader._checkByline;
      // Readability removes accepted bylines; linked records own their own attribution.
      reader._checkByline = function(node, matchString) {
        return articleBylineNode(node) && checkByline.call(this, node, matchString);
      };
      preserveReadabilityOwnedReferenceBlocks(reader, selectedOwner, sourceClones);
      preserveReadabilityOwnedNamedSvgBlocks(reader, clone, sourceClones, excerptMarker);
      var tableContext = preserveReadabilityDataTableSelection(reader, clone, sourceClones, metadata, sourceIdentities, headingRoles);
      preserveReadabilityOwnedResources(reader, clone, sourceClones, excerptMarker, cardActions.blocks, tableContext.blocks);
      var article = reader.parse();
      if (!article || !article.content) return null;
      if (normalizeText(article.textContent || "").length < 40) return null;
      article.content = stripReadabilityDefinitionClass(article.content, definitionClass);
      article.content = stripReadabilityDefinitionClass(article.content, cardActions.className);
      article.content = stripReadabilityDefinitionClass(article.content, cardActions.bodyClassName);
      article = sourceOwnedReaderRetainedHeadline(article, metadata, sourceClones, sourceIdentities, excerptMarker) || article;
      article = restoreReadabilityRetainedHeadingRole(article, headingRoles, sourceClones, sourceIdentities, excerptMarker);
      article = sourceOwnedReaderRetainedSections(article, sectionHeadings, sourceClones, sourceIdentities, excerptMarker);
      var sourceParagraphTemplate = document.createElement("template");
      sourceParagraphTemplate.innerHTML = article.content;
      var selectedSourceParagraphs = sourceOwnedReaderParagraphIdentitySources(
        sourceParagraphTemplate.content, sourceClones, sourceIdentities, excerptMarker
      );
      var readerBodyEvidence = sourceOwnedReaderSelectedParagraphs(
        sourceParagraphTemplate.content, sourceClones, sourceIdentities, excerptMarker, true
      );
      var sourceOwnedPublication = readabilityOwnedSelectedPublication(article, metadata, readerBodyEvidence);
      var excerpt = readabilityDataPublicationExcerpt(article, tableContext, sourceParagraphTemplate.content, sourceIdentities) ||
        readerSectionHeaderDateExcerpt(article, readerBodyEvidence, sectionHeadings) ||
        readabilityArticleExcerpt(article, metadata, excerptMarker, readerBodyEvidence);
      if (excerpt === article.excerpt && readerBodyEvidence && readerBodyEvidence.sourceParagraphs) {
        var normalizedExcerpt = normalizeText(excerpt || "");
        var readerBylineExcerpt = normalizedExcerpt &&
          (normalizedExcerpt === normalizeText(article.byline || "") ||
           normalizedExcerpt === normalizeText(metadata && metadata.declaredByline || ""));
        if (!readerBylineExcerpt) {
          excerpt = sourceOwnedReaderAdjacentHeaderExcerpt(article, readerBodyEvidence, metadata) || excerpt;
        }
      }
      if (!excerpt) excerpt = sourceOwnedReaderMissingExcerpt(article, metadata);
      article.content = readerSourceOwnedRestoreConflictingCredits(
        article, metadata, sourceClones, sourceIdentities, excerptMarker,
        readerBodyEvidence, conflictingSourceBylines
      );
      article.content = stripReadabilityExcerptMarkers(article.content, excerptMarker);
      article.content = stripReadabilitySourceNodeMarkers(article.content, excerptMarker, sourceIdentities);
      article.content = stripReadabilityLeadResourceMarkers(article.content, excerptMarker);
      article.content += comments;

      var content = {
        title: article.title || null,
        byline: article.byline || null,
        excerpt: excerpt,
        siteName: article.siteName || null,
        publishedTime: sourceOwnedPublication ? sourceOwnedPublication.publishedTime : article.publishedTime || null,
        html: article.content,
        textContent: article.textContent || "",
        readerMode: true,
        sourceOwnedArticleBoundary: article.sourceOwnedArticleBoundary === true,
        contentType: "article"
      };
      content.sourceOwnedArticlePublicationResolved = !!sourceOwnedPublication;
      Object.defineProperty(content, "sourceOwnedReaderParagraphSources", { value: selectedSourceParagraphs });
      Object.defineProperty(content, "sourceOwnedReaderBodyParagraphSources", {
        value: readerBodyEvidence && readerBodyEvidence.sourceParagraphs
      });
      Object.defineProperty(content, "sourceOwnedReaderUnmappedHeaderParagraphs", {
        value: readerBodyEvidence && readerBodyEvidence.unmappedHeaderParagraphs
      });
      Object.defineProperty(content, "sourceOwnedReaderUnmappedTrailingParagraphs", {
        value: readerBodyEvidence && readerBodyEvidence.unmappedTrailingParagraphs
      });
      return content;
    } catch (_error) {
      // Fall through to the shared article/list heuristics instead of aborting.
      return null;
    }
  }

  function prepareInlineArticleProse(root) {
    root.querySelectorAll("p span, li span, blockquote span, p font, li font, blockquote font").forEach(function(node) {
      if (node.querySelector("p, li, blockquote, div, ul, ol, table, pre")) return;
      node.replaceWith.apply(node, Array.prototype.slice.call(node.childNodes));
    });
  }
