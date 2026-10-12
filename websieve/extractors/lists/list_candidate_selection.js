  function bestListExtraction(metadata, pageTitles, options) {
    return withSourceVisibilityRead(function() {
      return computeBestListExtraction(metadata, pageTitles, options);
    });
  }

  function computeBestListExtraction(metadata, pageTitles, options) {
    options = options || {};
    if (options.repeatedRecordCollection) {
      return buildListExtraction(options.sourceOwner || options.repeatedRecordCollection.primaryMain || options.repeatedRecordCollection.owner,
        pageTitles, options);
    }
    if (options.sourceOwner) return buildListExtraction(options.sourceOwner, pageTitles, options);
    var candidates = [];
    function pushCandidate(node) {
      if (!node || candidates.indexOf(node) !== -1) return;
      candidates.push(node);
    }

    pushCandidate(listCandidateRoot(metadata));
    contextualListCandidates(metadata).forEach(pushCandidate);
    pushCandidate(document.querySelector("main, [role='main']"));
    pushCandidate(document.body);

    var tableIndexRoot = linkedTableIndexRoot();
    if (tableIndexRoot) return buildListExtraction(tableIndexRoot, pageTitles, options);

    var extractions = [];
    var best = candidates.reduce(function(current, node) {
      var result = buildListExtraction(node, pageTitles, options);
      extractions.push(result);
      return nestedListMaterialCoverage(current, result) || (listExtractionIsBetter(current, result) ? result : current);
    }, null) || buildListExtraction(document.body, pageTitles, options);
    var ancestorDescription = extractions.find(function(extraction) {
      return extraction !== best && extraction.descText && extraction.sourceNode.contains(best.sourceNode);
    });
    if (ancestorDescription) {
      best.ancestorDescription = ancestorDescription.descText;
      best.ancestorDescriptionSourceNode = ancestorDescription.sourceNode;
    }
    return best;
  }
