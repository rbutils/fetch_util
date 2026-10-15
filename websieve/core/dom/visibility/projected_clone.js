  function visibilityPrunedPhysicalClone(source, sourceProjection, collectionFlow) {
    // Stateful properties and template contents keep the ordinary native deep
    // copy contract. Other physical nodes are copied only after the ordinary
    // pruner has accepted their parent, without reparsing their source topology.
    if (source.querySelector("input, select, textarea, template, canvas")) return null;
    var clone = source.cloneNode(false);
    pruneHiddenClone(source, clone, null, null, false, null, null,
      collectionFlow === true, sourceProjection, true, true);
    return clone;
  }
