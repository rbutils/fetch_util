  function previewImageInterface(node) {
    return node.closest("form, nav, aside, footer, header, button, pre, code, kbd, samp, script, style, noscript, template, svg, " +
      "[role~='navigation' i], [role~='complementary' i], [role~='dialog' i], [role~='alertdialog' i], " +
      "[role~='menu' i], [role~='menubar' i], [role~='toolbar' i], [role~='button' i], " +
      "[hidden], [inert], [aria-hidden='true' i], details:not([open])");
  }

  function previewImageTargetId(input) {
    var ids = [];
    var controls = input.getAttribute("aria-controls");
    if (controls !== null) {
      if (input.getAttribute("aria-haspopup") !== "dialog" || !controls || /\s/.test(controls)) return null;
      ids.push(controls);
    }
    var target = input.getAttribute("data-bs-target");
    if (target !== null) {
      if (input.getAttribute("data-bs-toggle") !== "modal" || !/^#[^\s#]+$/.test(target)) return null;
      ids.push(target.slice(1));
    }
    if (!ids.length || ids.some(function(id) { return id !== ids[0]; })) return null;
    return ids[0];
  }

  function sourcePreviewImage(input, source) {
    if (!input.isConnected || input.ownerDocument !== document || input.getRootNode() !== document ||
        input.form || input.hasAttribute("form") || input.hasAttribute("formaction") ||
        previewImageInterface(input) || elementVisuallyHidden(input)) return null;
    var ownerSelector = "article, [itemprop~='articleBody' i], main, [role~='main' i]";
    var owner = input.closest(ownerSelector);
    if (!owner || !source.contains(owner) || !Array.from(owner.querySelectorAll("p")).some(function(paragraph) {
      return paragraph.closest(ownerSelector) === owner && !previewImageInterface(paragraph) &&
        !elementVisuallyHidden(paragraph) && !!normalizeText(paragraph.textContent);
    })) return null;
    var url = materializedHttpUrl(input.getAttribute("src"));
    var id = url && previewImageTargetId(input);
    if (!id) return null;
    var targets = Array.from(document.querySelectorAll("[id]")).filter(function(node) { return node.id === id; });
    if (targets.length !== 1 || !owner.contains(targets[0]) || targets[0].contains(input)) return null;
    var target = targets[0];
    if (!target.matches("[role~='dialog' i], [aria-hidden], [hidden]") ||
        target.closest("form, nav, aside, footer, pre, code, template")) return null;
    var matchingImage = Array.from(target.querySelectorAll("img[src]")).some(function(image) {
      return !image.closest("template, pre, code") && materializedHttpUrl(image.getAttribute("src")) === url;
    });
    return matchingImage ? {input: input, target: target, url: url} : null;
  }

  function materializeEditorialPreviewImages(source, clone, elementMap) {
    var previews = Array.from(source.querySelectorAll("input[type='image' i]")).map(function(input) {
      return sourcePreviewImage(input, source);
    }).filter(Boolean);
    if (!previews.length) return elementMap;
    var sourceClones = elementMap || new WeakMap();
    if (!sourceClones.has(source)) mapDomCloneElements(source, clone, sourceClones);
    previews.forEach(function(preview) {
      var input = sourceClones.get(preview.input);
      if (!input || input.localName !== "input" || !clone.contains(input)) return;
      var attributes = ["type", "src", "alt", "title", "id", "width", "height", "form", "formaction",
        "aria-controls", "aria-haspopup", "data-bs-target", "data-bs-toggle"];
      if (!attributes.every(function(attribute) {
        return input.getAttribute(attribute) === preview.input.getAttribute(attribute);
      })) return;
      var target = sourceClones.get(preview.target);
      if (target && clone.contains(target) && target.id === preview.target.id && elementSubtreeHidden(preview.target)) target.remove();
      var image = clone.ownerDocument.createElement("img");
      image.setAttribute("src", preview.url);
      image.setAttribute("alt", preview.input.getAttribute("alt") || "");
      ["id", "title", "width", "height"].forEach(function(attribute) {
        if (preview.input.hasAttribute(attribute)) image.setAttribute(attribute, preview.input.getAttribute(attribute));
      });
      input.replaceWith(image);
      sourceClones.set(preview.input, image);
    });
    return sourceClones;
  }
