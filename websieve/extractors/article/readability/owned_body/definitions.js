  function readabilityDefinitionInterfaceOwner(node) {
    return node.closest("nav, form, button, [role='navigation'], [role='menu'], [role='menubar'], [role='toolbar'], [role='dialog']");
  }

  function completeReadabilityDefinitionPairs(node) {
    var hasTerm = false;
    var hasDefinition = false;
    var complete = Array.from(node.children).every(function(child) {
      if (!normalizeText(child.textContent || "")) return false;
      if (child.localName === "dt") {
        hasTerm = true;
        hasDefinition = false;
        return true;
      }
      if (child.localName !== "dd" || !hasTerm) return false;
      hasDefinition = true;
      return true;
    });
    return complete && hasTerm && hasDefinition;
  }

  function prepareReadabilityOwnedDefinitions(root, sourceClones, marker) {
    var className = "fetchutil-definition-content-" + marker;
    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "dl" || !root.documentElement.contains(clone)) return;
      if (readabilityDefinitionInterfaceOwner(source)) {
        clone.remove();
        return;
      }
      if (!source.closest("main, article, [role='main'], [itemprop~='articleBody' i]")) return;
      if (source.closest("pre, code, kbd, samp, aside, header, footer, details:not([open])")) return;
      if (clone.querySelector("nav, form, button, input, select, textarea, [role='dialog'], [role='navigation']")) return;
      if (!completeReadabilityDefinitionPairs(clone)) return;
      // The vendor's unlikely-candidate pass runs before conditional cleanup.
      // A private positive hint preserves this physically proved definition block.
      clone.classList.add(className);
    });
    return className;
  }

  function stripReadabilityDefinitionClass(html, className) {
    if (html.indexOf(className) === -1) return html;
    var template = document.createElement("template");
    template.innerHTML = html;
    template.content.querySelectorAll("[class]").forEach(function(node) {
      if (!node.classList.contains(className)) return;
      node.classList.remove(className);
      if (!node.className) node.removeAttribute("class");
    });
    return template.innerHTML;
  }
