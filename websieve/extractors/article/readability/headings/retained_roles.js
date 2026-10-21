  function readabilityHeadingRoleSignature(heading) {
    function resolvedAttribute(node, name) {
      var value = node.getAttribute(name) || "";
      if (!value) return value;
      try { return new URL(value, location.href).href; } catch (_error) { return value; }
    }

    return JSON.stringify({
      text: normalizedHeadingText(heading),
      references: Array.from(heading.querySelectorAll("a[href]")).map(function(link) {
        return [normalizeText(link.textContent), resolvedAttribute(link, "href")];
      }),
      images: Array.from(heading.querySelectorAll("img")).map(function(image) {
        return [image.getAttribute("alt"), resolvedAttribute(image, "src"), image.getAttribute("srcset")];
      }),
      programs: Array.from(heading.querySelectorAll("pre, code, kbd, samp")).map(function(program) {
        return [program.localName, program.textContent];
      })
    });
  }

  function readabilityRetainedHeadingRoleSnapshots(root, sourceClones, sourceIdentities) {
    var snapshots = new Map();
    if (!root || !sourceClones || !sourceIdentities) return snapshots;
    sourceIdentities.forEach(function(identity, source) {
      if (source.localName !== "h1" || !identity.unique || elementVisuallyHidden(source)) return;
      if (source.closest("nav, aside, footer, form, button, pre, code, kbd, samp, [role='navigation'], [role='complementary']")) return;
      if (!source.closest("main, article, [role='main'], [itemprop~='articleBody']")) return;
      var clone = sourceClones.get(source);
      if (!clone || clone.localName !== "h1" || !root.contains(clone)) return;
      snapshots.set(source, readabilityHeadingRoleSignature(clone));
    });
    return snapshots;
  }

  function restoreReadabilityRetainedHeadingRole(article, snapshots, sourceClones, sourceIdentities, marker) {
    if (!article || !article.content || !snapshots || snapshots.size !== 1) return article;
    var entry = Array.from(snapshots.entries())[0];
    var template = document.createElement("template");
    template.innerHTML = article.content;
    if (template.content.querySelector("h1")) return article;
    var heading = sourceOwnedReaderRetainedHeading(template.content, entry[0], sourceClones, sourceIdentities, marker);
    if (!heading || heading.localName !== "h2" || readabilityHeadingRoleSignature(heading) !== entry[1]) return article;

    var restored = document.createElement("h1");
    Array.from(heading.attributes).forEach(function(attribute) {
      restored.setAttribute(attribute.name, attribute.value);
    });
    while (heading.firstChild) restored.appendChild(heading.firstChild);
    heading.replaceWith(restored);
    article.content = template.innerHTML;
    return article;
  }
