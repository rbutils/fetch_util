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
    var descriptors = new WeakMap();
    var best = candidates.reduce(function(current, node) {
      var result = buildListExtraction(node, pageTitles, options);
      var descriptor = { sourceNode: result.sourceNode, descText: result.descText };
      extractions.push(descriptor);
      descriptors.set(result, descriptor);
      var selected = nestedListMaterialCoverage(current, result) || (listExtractionIsBetter(current, result) ? result : current);
      retireUnselectedListRoots([current, result], selected);
      return selected;
    }, null) || buildListExtraction(document.body, pageTitles, options);
    var selectedDescriptor = descriptors.get(best);
    var ancestorDescription = extractions.find(function(extraction) {
      return extraction !== selectedDescriptor && extraction.descText && extraction.sourceNode.contains(best.sourceNode);
    });
    if (ancestorDescription) {
      best.ancestorDescription = ancestorDescription.descText;
      best.ancestorDescriptionSourceNode = ancestorDescription.sourceNode;
    }
    return best;
  }

  function retireUnselectedListRoots(extractions, selected) {
    extractions.forEach(function(extraction) {
      if (!extraction) return;
      var root = extraction.root;
      if (!root || root === selected.root || root === extraction.sourceNode || root.isConnected) return;
      if (root.contains(selected.root) || (selected.items || []).some(function(item) {
        return item.card && root.contains(item.card);
      })) return;
      root.replaceChildren();
    });
  }
