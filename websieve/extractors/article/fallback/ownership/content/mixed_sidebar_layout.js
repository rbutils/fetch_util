function sourceOwnedMixedSidebarBodySelector() {
  return "[itemprop~='articleBody' i], [data-article-body], [class*='article-body' i], " +
    "[class*='article-content' i], [class*='post-content' i], [class*='entry-content' i], [class*='story-content' i]";
}

function sourceOwnedMixedSidebarSelector() {
  return "[class*='sidebar' i], [id*='sidebar' i]";
}

function sourceOwnedMixedSidebarWrapperIsEligible(wrapper) {
  if (!wrapper || !wrapper.matches(sourceOwnedMixedSidebarSelector()) ||
      wrapper.closest("aside, nav, footer, form, menu, [role~='complementary' i]")) return false;
  var name = String(wrapper.className || "") + " " + String(wrapper.id || "");
  return !/(?:recommend|related|suggest|popular|recent)/i.test(name);
}

function cleanupEmptyMixedSidebarRecommendations(root) {
  if (!root || !root.querySelectorAll) return;
  var wrappers = Array.from(root.querySelectorAll(sourceOwnedMixedSidebarSelector()));
  if (root.matches && root.matches(sourceOwnedMixedSidebarSelector())) wrappers.unshift(root);

  wrappers.forEach(function(wrapper) {
    if (!sourceOwnedMixedSidebarWrapperIsEligible(wrapper)) return;
    var bodies = Array.from(wrapper.querySelectorAll(sourceOwnedMixedSidebarBodySelector()));
    if (bodies.length !== 1 || normalizeText(bodies[0].textContent || "")) return;
    if (bodies[0].querySelector("p, blockquote, pre, li, table, figure, img, picture, video, audio, iframe, object, embed")) return;

    var bodyBranch = sourceOwnedDirectChild(wrapper, bodies[0]);
    if (!bodyBranch) return;
    var sidebars = Array.from(wrapper.querySelectorAll(sourceOwnedMixedSidebarSelector())).filter(function(sidebar) {
      if (sidebar === wrapper || !sourceOwnedMixedSidebarWrapperIsEligible(sidebar)) return false;
      var parentSidebar = sidebar.parentElement && sidebar.parentElement.closest(sourceOwnedMixedSidebarSelector());
      return (!parentSidebar || parentSidebar === wrapper) && sourceOwnedDirectChild(wrapper, sidebar) !== bodyBranch;
    });
    if (sidebars.length === 1) sidebars[0].remove();
  });
}

function sourceOwnedMixedSidebarLayoutBody(node, wrapper) {
  if (!node || !sourceOwnedMixedSidebarWrapperIsEligible(wrapper) || !wrapper.contains(node)) return false;
  var bodyBranches = Array.from(wrapper.querySelectorAll(sourceOwnedMixedSidebarBodySelector())).filter(function(body) {
    return body.contains(node) && !elementSubtreeHidden(body) &&
      normalizeText(body.textContent || "").length >= 120 && body.querySelector("p, blockquote, pre, li");
  }).map(function(body) { return sourceOwnedDirectChild(wrapper, body); }).filter(Boolean);
  bodyBranches = bodyBranches.filter(function(branch, index) { return bodyBranches.indexOf(branch) === index; });
  if (bodyBranches.length !== 1) return false;
  var nodeBranch = sourceOwnedDirectChild(wrapper, node);
  if (!nodeBranch || nodeBranch !== bodyBranches[0]) return false;
  return Array.from(wrapper.querySelectorAll(sourceOwnedMixedSidebarSelector())).some(function(sidebar) {
    var sidebarBranch = sourceOwnedDirectChild(wrapper, sidebar);
    return sidebar !== wrapper && !elementSubtreeHidden(sidebar) && sidebarBranch && sidebarBranch !== nodeBranch;
  });
}

function sourceOwnedMixedSidebarLayoutWrapper(wrapper) {
  if (!sourceOwnedMixedSidebarWrapperIsEligible(wrapper)) return false;
  return Array.from(wrapper.querySelectorAll(sourceOwnedMixedSidebarBodySelector())).some(function(body) {
    return !elementSubtreeHidden(body) && normalizeText(body.textContent || "").length >= 120 &&
      body.querySelector("p, blockquote, pre, li") &&
      sourceOwnedMixedSidebarLayoutBody(body, wrapper);
  });
}

function sourceOwnedMixedSidebarArticleRoot(candidates, body, heading) {
  var wrapper = body && body.closest(sourceOwnedMixedSidebarSelector());
  if (!wrapper || !sourceOwnedMixedSidebarLayoutBody(body, wrapper)) return null;
  var roots = candidates.filter(function(candidate) {
    return candidate !== body && candidate.matches("article") && candidate.contains(heading) && candidate.contains(body);
  });
  roots = roots.filter(function(root) {
    return !roots.some(function(other) { return other !== root && root.contains(other); });
  });
  return roots.length === 1 ? roots[0] : null;
}
