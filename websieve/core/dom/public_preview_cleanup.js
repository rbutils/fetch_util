  var verifiedFocalPublicPreviewNodes = new WeakSet();

  function markVerifiedFocalPublicPreview(node) {
    verifiedFocalPublicPreviewNodes.add(node);
    node.setAttribute("data-fetchutil-public-preview-owned", "");
  }

  function stashVerifiedPublicPreviews(root, allowSerializedOwnedPublicPreviews) {
    var publicPreviews = [];
    root.querySelectorAll("[data-fetchutil-public-preview-owned]").forEach(function(node) {
      if (!verifiedFocalPublicPreviewNodes.has(node) && !allowSerializedOwnedPublicPreviews) return;
      var marker = document.createComment("fetchutil-public-preview");
      node.replaceWith(marker);
      publicPreviews.push({ marker: marker, node: node });
    });
    return publicPreviews;
  }

  function restoreVerifiedPublicPreviews(root, publicPreviews) {
    publicPreviews.forEach(function(preview) {
      if (root.contains(preview.marker)) preview.marker.replaceWith(preview.node);
      else preview.node.remove();
    });
  }
