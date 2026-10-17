  function ordinaryOwnedExtractionTask(options) {
    var consumed = false;
    return {
      owned: false,
      finish: function() {
        if (consumed) throw new Error("Extraction work has already been consumed");
        consumed = true;
        return fetchUtilExtractApi.extract(options);
      },
      dispose: function() { consumed = true; }
    };
  }

  function prepareOwnedExtractionWork(options) {
    var manualEligible = standaloneManualPreparationEligible() && !structuredDataNodes().length;
    var frameworkEligible = generatedReferencePreparationEligible() && generatedReferenceDeclarationsAgree();
    var tableEligible = canonicalDataTablePreparationEligible();
    if (!manualEligible && !frameworkEligible && !tableEligible) {
      return ordinaryOwnedExtractionTask(options);
    }
    var state = ownedExtractionSourceState();
    if (!state) return ordinaryOwnedExtractionTask(options);
    var metadata = collectMetadata();
    var context = standaloneManualPreparationContext(metadata) || generatedReferencePreparationContext(metadata) ||
      canonicalDataTableContext(metadata);
    if (!context) return ordinaryOwnedExtractionTask(options);
    var framework = context.framework === "mkdocs";
    var dataTable = context.kind === "canonical-data-table";
    var prepared = false;
    var fallback = false;
    var selected = null;
    var pageText = null;
    var disposed = false;
    function dispose() {
      disposed = true;
      state = null;
      metadata = null;
      context = null;
      selected = null;
      pageText = null;
    }
    function prepare() {
      if (disposed) throw new Error("Extraction work has already been consumed");
      if (prepared) return;
      prepared = true;
      withComposedDomRead(function() {
        if (!ownedExtractionSourceUnchanged(state) || (framework ? !generatedReferenceDeclarationsAgree() : structuredDataNodes().length)) {
          fallback = true;
          return;
        }
        resetTerminalArticleCollectionMarker();
        var manual = dataTable ? canonicalDataTableContent(metadata, context) :
          (framework ? mkdocsMaterialContent(metadata, context.info) : physicalManualRenderedSections(metadata, context));
        context = null;
        var earlyOwnership = manual && (framework || dataTable ? { content: manual } : sourceOwnedEarlyPageContent(metadata, manual));
        selected = earlyOwnership && earlyOwnership.content;
        fallback = !selected;
        if (selected) pageText = pageReadableText();
      })();
    }
    return {
      owned: true,
      prepare: prepare,
      dispose: dispose,
      finish: function() {
        if (disposed) throw new Error("Extraction work has already been consumed");
        try {
          prepare();
          return withComposedDomRead(function(currentOptions) {
            if (fallback || !ownedExtractionSourceUnchanged(state) || (framework ? !generatedReferenceDeclarationsAgree() : structuredDataNodes().length)) {
              dispose();
              return fetchUtilExtractApi.extract(currentOptions);
            }
            return finalizeExtractResult(selected, metadata, pageText, null, null);
          })(options);
        } finally {
          dispose();
        }
      }
    };
  }
