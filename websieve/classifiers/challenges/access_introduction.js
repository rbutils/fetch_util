var sourceOwnedAccessIntroductions = new WeakMap();

function accessIntroductionInterfaceSelector() {
  return "form, nav, aside, header, footer, button, input, select, textarea, iframe, " +
    "[role='navigation'], [role='complementary'], [role='contentinfo'], [role='banner'], " +
    "[role='dialog'], [role='menu'], [role='menubar'], [role='toolbar'], [role='button']";
}

function accessIntroductionRegion(root) {
  var region = root.parentElement;
  while (region && region !== document.body) {
    if (region.matches(accessIntroductionInterfaceSelector())) return null;
    var visibleForm = Array.prototype.some.call(region.querySelectorAll("form"), function(form) {
      if (root.contains(form) || form.parentElement.closest(accessIntroductionInterfaceSelector()) ||
          elementVisuallyHidden(form)) return false;
      return Array.prototype.some.call(form.querySelectorAll("input:not([type='hidden']), button, select"), function(control) {
        return !elementVisuallyHidden(control);
      });
    });
    if (visibleForm) return region;
    region = region.parentElement;
  }
  return null;
}

function accessIntroductionRoot(heading) {
  if (heading.closest(accessIntroductionInterfaceSelector()) || elementVisuallyHidden(heading)) return null;
  var root = heading.parentElement;
  while (root && root !== document.body && !root.querySelector("p")) root = root.parentElement;
  if (!root || root === document.body || root.closest(accessIntroductionInterfaceSelector()) ||
      !/^(DIV|SECTION|ARTICLE|MAIN)$/.test(root.tagName) || elementVisuallyHidden(root)) return null;
  var region = accessIntroductionRegion(root);
  if (!region) return null;
  var clone = visibilityPrunedClone(root);
  if (!clone.querySelector("p") || clone.querySelector(accessIntroductionInterfaceSelector())) return null;
  clone.querySelectorAll("script, style, noscript, template").forEach(function(node) { node.remove(); });
  return { source: root, clone: clone, region: region };
}

function withAuthoredAccessIntroduction(content) {
  var seen = new Set();
  var candidates = Array.prototype.map.call(document.querySelectorAll("h1, h2, h3"), function(heading) {
    var candidate = accessIntroductionRoot(heading);
    if (!candidate || seen.has(candidate.source)) return null;
    seen.add(candidate.source);
    return candidate;
  }).filter(Boolean);
  candidates = candidates.filter(function(candidate) {
    return !candidates.some(function(other) {
      return other !== candidate && other.source.contains(candidate.source);
    });
  });
  if (!candidates.length || candidates.some(function(candidate) { return candidate.region !== candidates[0].region; })) return content;

  var wrapper = document.createElement("div");
  candidates.forEach(function(candidate) { wrapper.appendChild(candidate.clone); });
  normalizeCodeSurfaces(wrapper);
  materializeHttpAttributes(wrapper, false, true);
  var html = wrapper.innerHTML;
  var body = markdownFor(html, false, true, true);
  if (!normalizeText(body)) return content;
  content.html = html;
  content.markdown = contentMarkdownWithDetails(body, content.title, "- Access notice: login or account required");
  content.textContent = normalizeText(content.markdown);
  sourceOwnedAccessIntroductions.set(content, html);
  return content;
}

function hasSourceOwnedAccessIntroduction(content) {
  return !!content && content.contentType === "interstitial" &&
    sourceOwnedAccessIntroductions.has(content) && sourceOwnedAccessIntroductions.get(content) === content.html;
}
