  function preserveReadabilityOwnedCardSelection(reader, root, ownership, sourceClones, sourceIdentities, headingRoles) {
    var publication = readabilityOwnedCardCohorts(ownership, root, sourceClones, sourceIdentities);
    if (!publication) return;
    var blocks = new WeakSet();
    var paragraphs = new WeakSet();
    blocks.add(publication.root);
    for (var source = publication.source.parentElement; source && source !== document.body; source = source.parentElement) {
      var ancestor = sourceClones.get(source);
      if (!ancestor || !root.contains(ancestor) || !ancestor.contains(publication.root)) break;
      blocks.add(ancestor);
    }
    publication.cohorts.forEach(function(cohort) {
      blocks.add(cohort.clone);
      cohort.records.forEach(function(record) {
        blocks.add(record.clone);
        record.prose.forEach(function(source) {
          var mapped = sourceClones.get(source);
          paragraphs.add(mapped);
          for (var parent = source.parentElement; parent && parent !== record.source; parent = parent.parentElement) {
            var wrapper = sourceClones.get(parent);
            if (wrapper && record.clone.contains(wrapper) && wrapper.contains(mapped)) blocks.add(wrapper);
          }
        });
      });
    });
    var setNodeTag = reader._setNodeTag;
    reader._setNodeTag = function(node, tag) {
      var protectedBlock = blocks.has(node);
      var replacement = setNodeTag.apply(this, arguments);
      if (protectedBlock) blocks.add(replacement);
      if (node === publication.root) publication.root = replacement;
      return replacement;
    };
    var ancestors = reader._getNodeAncestors;
    reader._getNodeAncestors = function(node, maxDepth) {
      var result = ancestors.apply(this, arguments);
      if (typeof maxDepth !== "number" || !paragraphs.has(node) ||
          !root.contains(publication.root) || !publication.root.contains(node)) return result;
      return [publication.root].concat(result.filter(function(ancestor) {
        return ancestor !== publication.root && !publication.root.contains(ancestor);
      }));
    };
    var duplicateTitle = reader._headerDuplicatesTitle;
    reader._headerDuplicatesTitle = function(node) {
      return node === publication.heading ? false : duplicateTitle.apply(this, arguments);
    };
    headingRoles.set(ownership.heading, readabilityHeadingRoleSignature(publication.heading));
    protectReadabilitySourceBlocks(reader, blocks);
  }
