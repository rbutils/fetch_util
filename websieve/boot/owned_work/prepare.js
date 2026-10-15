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
    resetTerminalArticleCollectionMarker();
    var prepared = metadataWithPreparedStandaloneManual();
    if (!prepared.manual) return ordinaryOwnedExtractionTask(options);
    var earlyOwnership = sourceOwnedEarlyPageContent(prepared.metadata, prepared.manual);
    var selected = earlyOwnership.content;
    if (!selected) return ordinaryOwnedExtractionTask(options);
    var pageText = pageReadableText();
    var disposed = false;
    function dispose() {
      disposed = true;
      state = null;
      prepared = null;
      selected = null;
      pageText = null;
    }
    return {
      owned: true,
      dispose: dispose,
      finish: function() {
        if (disposed) throw new Error("Extraction work has already been consumed");
        try {
          return withComposedDomRead(function(currentOptions) {
            if (!ownedExtractionSourceUnchanged(state) || structuredDataNodes().length) {
              dispose();
              return fetchUtilExtractApi.extract(currentOptions);
            }
            return finalizeExtractResult(selected, prepared.metadata, pageText, null, null);
          })(options);
        } finally {
          dispose();
        }
      }
    };
  }
