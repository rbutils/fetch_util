  function pruneHiddenClone(source, clone, preservedRoots, preservingRoot, checkedParent, sourceClones, clipBounds, collectionFlow, sourceProjection, physicalTree, constructChildren) {
    if (!source || !clone) return;
    var stack = [{ source: source, clone: clone, preservingRoot: preservingRoot,
      checkedParent: checkedParent, clipBounds: clipBounds, entered: false }];
    while (stack.length) {
      var frame = stack[stack.length - 1];
      var current = frame.source;
      var copied = frame.clone;
      if (!frame.entered) {
        var exactPreservedRoot = !!(preservedRoots && preservedRoots.indexOf(current) !== -1);
        var preservedRoot = exactPreservedRoot ? current : frame.preservingRoot;
        var boundary = frame.checkedParent ? composedDomParent(current) : preservedRoot;
        var style = current.nodeType === 1 && !exactPreservedRoot ? sourceVisibilityStyle(current) : null;
        var subtreeHidden = exactPreservedRoot ? false : frame.checkedParent && current.nodeType === 1 ?
          elementOwnSubtreeHidden(current, style) : elementSubtreeHiddenWithin(current, boundary || null);
        if (current.nodeType === 1 && !exactPreservedRoot && subtreeHidden) {
          copied.remove();
          stack.pop();
          continue;
        }
        var bounds = frame.clipBounds;
        if (exactPreservedRoot || collectionFlow) bounds = null;
        else if (!frame.checkedParent) bounds = ancestorHorizontalClipBounds(current);
        var children = sourceVisibilityChildren(current, physicalTree);
        var clipped = !collectionFlow && horizontallyClippedElement(current, style, bounds);
        var overflowing = clipped && style.overflowX === "visible" &&
          !current.matches("pre, code, kbd, samp, .CodeMirror, .cm-editor") &&
          children.some(function(child) { return child.nodeType === 1; });
        if (clipped && !overflowing) {
          copied.remove();
          stack.pop();
          continue;
        }
        if (sourceClones) sourceClones.set(current, copied);
        if (sourceProjection && current.nodeType === 1 && !preservedRoots && !sourceClones) {
          var projection = sourceProjection(current);
          if (projection && projection.namespaceURI === copied.namespaceURI && projection.localName === copied.localName) {
            if (projection !== copied) copied.replaceChildren.apply(copied, Array.prototype.slice.call(projection.childNodes));
            stack.pop();
            continue;
          }
        }
        if (exactPreservedRoot && current.nodeType === 1) {
          copied.removeAttribute("hidden");
          copied.removeAttribute("inert");
          if (copied.getAttribute("aria-hidden") === "true") copied.removeAttribute("aria-hidden");
          if (copied.style) {
            copied.style.removeProperty("display");
            copied.style.removeProperty("visibility");
            copied.style.removeProperty("opacity");
            if (!copied.getAttribute("style")) copied.removeAttribute("style");
          }
          copied.setAttribute("data-fetchutil-controlled-list-panel", "true");
        }
        frame.children = children;
        frame.copiedChildren = constructChildren ? null : Array.prototype.slice.call(copied.childNodes || []);
        frame.hidden = !!(style && (style.visibility === "hidden" || style.visibility === "collapse"));
        frame.overflowing = overflowing;
        frame.preservingRoot = preservedRoot;
        frame.childBounds = collectionFlow ? null : horizontalClipBounds(current, style, bounds);
        frame.index = 0;
        frame.entered = true;
      }
      if (frame.index < frame.children.length) {
        var index = frame.index++;
        var child = frame.children[index];
        if (constructChildren && (frame.hidden || frame.overflowing) && child.nodeType !== 1) continue;
        var childClone = constructChildren ? child.cloneNode(false) : frame.copiedChildren[index];
        if (!childClone) continue;
        if (constructChildren) copied.appendChild(childClone);
        if ((frame.hidden || frame.overflowing) && child.nodeType !== 1) {
          childClone.remove();
          continue;
        }
        // These leaves have already passed their parent's inherited visibility
        // and clipping decisions. Preserve complete mappings without a new frame.
        if (child.nodeType === 3 || child.nodeType === 8) {
          if (sourceClones) sourceClones.set(child, childClone);
          continue;
        }
        stack.push({ source: child, clone: childClone, preservingRoot: frame.preservingRoot,
          checkedParent: true, clipBounds: frame.childBounds, entered: false });
        continue;
      }
      if (frame.overflowing && !copied.children.length) {
        copied.remove();
        if (sourceClones) sourceClones.delete(current);
      } else if (frame.hidden) {
        copied.style.setProperty("visibility", "visible", "important");
        ["aria-label", "title", "alt", "value"].forEach(function(attribute) { copied.removeAttribute(attribute); });
        if (!copied.children.length) copied.remove();
      }
      stack.pop();
    }
  }
