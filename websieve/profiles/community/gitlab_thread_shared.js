function gitlabResourceRoute() {
  var match = (location.pathname || "").match(/^(.+)\/-\/(issues|work_items|merge_requests)\/(\d+)(?:\/(commits|pipelines|reports|diffs))?\/?$/);
  if (!match) return null;

  var projectPath = match[1].replace(/^\/+|\/+$/g, "");
  var projectParts = projectPath.split("/").filter(Boolean);
  if (projectParts.length < 2 || projectParts.some(function(part) { return !/^[\w.%+-]+$/.test(part); })) return null;

  return {
    projectPath: projectPath,
    community: projectPath,
    kind: match[2],
    number: match[3],
    surface: match[4] || null,
    basePath: "/" + projectPath + "/-/" + match[2] + "/" + match[3]
  };
}

function gitlabThreadRoute() {
  var route = gitlabResourceRoute();
  return route && !route.surface ? route : null;
}

function gitlabRouteUrl(route, suffix) {
  return location.origin + route.basePath + (suffix || "");
}

function gitlabRuntimeOriginMatches(value) {
  if (!value) return true;

  try {
    return new URL(value, location.href).origin === location.origin;
  } catch (_error) {
    return false;
  }
}

function gitlabProductAssetEvidence() {
  return Array.prototype.slice.call(document.querySelectorAll("script[src], link[href]")).some(function(node) {
    var value = node.getAttribute("src") || node.getAttribute("href");
    if (!value || !/\/assets\/(?:webpack|application|gitlab)/i.test(value)) return false;

    try {
      return new URL(value, location.href).origin === location.origin;
    } catch (_error) {
      return false;
    }
  });
}

function gitlabProductMatch(root) {
  if (!root) return false;

  var html = document.documentElement;
  var site = document.querySelector("meta[property='og:site_name']");
  var branded = !!(html && html.classList.contains("gl-system") && site && /^GitLab$/i.test(normalizeText(site.getAttribute("content"))));
  var meta = !!document.querySelector("meta[name='gitlab-meta'], meta[name^='gitlab-']");
  var gon = window.gon || {};
  var runtime = !!(gon.api_version && gitlabRuntimeOriginMatches(gon.gitlab_url || gon.relative_url_root));
  var asset = gitlabProductAssetEvidence();

  return (runtime && (branded || meta || asset)) || (branded && (meta || asset));
}

function gitlabThreadRoot(route) {
  if (!route) return null;

  var root = document.querySelector([
    ".work-item-page",
    "[data-testid='work-item-view']",
    ".work-item-notes",
    ".issuable-details",
    ".merge-request",
    ".issue-details"
  ].join(", "));
  if (!root) return null;

  root = root.closest("main, .content-wrapper, .issuable-details, .merge-request, .issue-details") || root;
  return root;
}

function gitlabThreadBody(node) {
  if (!node) return null;
  var selector = "[data-testid='work-item-description'], [data-testid='description-content'], .detail-page-description .md, .issuable-description .md, .description .md, .note-body, .note-text, .render-content.markup";
  if (node.matches && node.matches(selector)) return node;
  return node.querySelector(selector);
}

function gitlabThreadBodies(node) {
  if (!node) return [];

  var selector = ".note-body, .note-text, [data-testid='note-body'], .render-content.markup";
  var bodies = node.matches && node.matches(selector) ? [node] : Array.prototype.slice.call(node.querySelectorAll(selector));
  return bodies.filter(function(body, index) {
    if (!normalizeText(body.textContent) || elementSubtreeHidden(body)) return false;
    return !bodies.some(function(other, otherIndex) {
      return otherIndex < index && other.contains(body);
    });
  });
}

function gitlabThreadAuthorNode(node) {
  if (!node) return null;

  var selectors = [
    "[data-testid='work-item-author']",
    "[data-testid='author-link']",
    ".author-name-link",
    ".author-link",
    ".js-user-link",
    "a[data-user-id]",
    ".note-header-info a"
  ];
  for (var index = 0; index < selectors.length; index += 1) {
    var authors = Array.prototype.slice.call(node.querySelectorAll(selectors[index]));
    var author = authors.find(function(candidate) {
      return !elementVisuallyHidden(candidate) && normalizeText(candidate.textContent);
    });
    if (author) return author;
  }
  return null;
}

function gitlabThreadAuthor(node) {
  var author = gitlabThreadAuthorNode(node);
  return normalizeText((author && author.textContent) || "").replace(/^@/, "");
}

function gitlabThreadPermalink(node, route) {
  if (!node) return null;

  var links = Array.prototype.slice.call(node.querySelectorAll("a[href*='#note_'], a[href*='#note-'], a[href*='#discussion_'], a[href*='#diff-note_']"));
  var link = links.find(function(candidate) { return !elementVisuallyHidden(candidate); });
  var href = link && link.getAttribute("href");
  if (!href && node.id && /^(?:note|discussion|diff-note)[_-]/.test(node.id)) href = gitlabRouteUrl(route) + "#" + node.id;
  return materializedHttpUrl(href);
}

function gitlabThreadTimestamp(node) {
  var times = node ? Array.prototype.slice.call(node.querySelectorAll("time[datetime], gl-relative-time[datetime]")) : [];
  var time = times.find(function(candidate) { return !elementVisuallyHidden(candidate); });
  return normalizeText((time && (time.getAttribute("datetime") || time.textContent)) || "");
}

function gitlabThreadNodeMarkdown(node) {
  return gitlabThreadBodies(node).map(function(body) {
    var clone = visibilityPrunedClone(body);
    removeAll(clone, "button, [role='tooltip'], .note-actions, .js-note-actions, .award-control, .emoji-block");
    return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
  }).filter(function(markdown) {
    return !!normalizeText(markdown);
  }).join("\n\n");
}

function gitlabProjectId() {
  var gon = window.gon || {};
  var node = document.querySelector("[data-project-id]");
  var value = gon.current_project_id || gon.project_id || (node && node.getAttribute("data-project-id"));
  return /^\d+$/.test(String(value || "")) ? String(value) : null;
}

function gitlabApiRoot() {
  var relativeRoot = normalizeText((window.gon || {}).relative_url_root || "").replace(/\/$/, "");
  return location.origin + relativeRoot + "/api/v4";
}
