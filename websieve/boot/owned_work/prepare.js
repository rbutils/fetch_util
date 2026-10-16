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
    if (!standaloneManualPreparationEligible() || structuredDataNodes().length) {
      return ordinaryOwnedExtractionTask(options);
    }
    var state = ownedExtractionSourceState();
    if (!state) return ordinaryOwnedExtractionTask(options);
    var metadata = collectMetadata();
    var context = standaloneManualPreparationContext(metadata);
    if (!context) return ordinaryOwnedExtractionTask(options);
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
        if (!ownedExtractionSourceUnchanged(state) || structuredDataNodes().length) {
          fallback = true;
          return;
        }
        resetTerminalArticleCollectionMarker();
        var manual = physicalManualRenderedSections(metadata, context);
        context = null;
        var earlyOwnership = manual && sourceOwnedEarlyPageContent(metadata, manual);
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
            if (fallback || !ownedExtractionSourceUnchanged(state) || structuredDataNodes().length) {
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
