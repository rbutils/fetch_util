function githubResourceRoute() {
  if (!hostMatches(/(^|\.)github\.com$/)) return null;

  var parts = (location.pathname || "").split("/").filter(Boolean);
  if (parts.length < 4 || parts.length > 5) return null;
  if (!/^[\w.-]+$/.test(parts[0]) || !/^[\w.-]+$/.test(parts[1]) || !/^\d+$/.test(parts[3])) return null;
  if (["issues", "pull", "discussions"].indexOf(parts[2]) === -1) return null;
  if (parts[4] && ["commits", "checks", "files"].indexOf(parts[4]) === -1) return null;
  if (parts[4] && parts[2] !== "pull") return null;

  return {
    owner: parts[0],
    repository: parts[1],
    community: parts[0] + "/" + parts[1],
    kind: parts[2],
    number: parts[3],
    surface: parts[4] || null
  };
}

function githubThreadRoute() {
  var route = githubResourceRoute();
  return route && !route.surface ? route : null;
}

function githubPullResourceRoute() {
  var route = githubResourceRoute();
  return route && route.kind === "pull" && route.surface ? route : null;
}

function githubRouteUrl(route, suffix) {
  return location.origin + "/" + route.owner + "/" + route.repository + "/" + route.kind + "/" + route.number + (suffix || "");
}

function githubThreadRoot() {
  return document.querySelector("[data-testid='issue-viewer-container'], [data-testid='issue-viewer-issue-container'], #discussion_bucket, .js-discussion, .discussion-timeline");
}

function githubThreadBody(node) {
  if (!node) return null;
  if (node.matches("[data-testid='markdown-body'], [data-testid='comment-body'], .comment-body, .js-comment-body, .markdown-body[itemprop='text'], [itemprop='text']")) return node;
  return node.querySelector("[data-testid='markdown-body'], [data-testid='comment-body'], .comment-body, .js-comment-body, .markdown-body[itemprop='text'], [itemprop='text']");
}

function githubThreadBodies(node) {
  if (!node) return [];

  var selector = "[data-testid='markdown-body'], [data-testid='comment-body'], .comment-body, .js-comment-body, .markdown-body[itemprop='text'], [itemprop='text']";
  var bodies = node.matches(selector) ? [node] : Array.prototype.slice.call(node.querySelectorAll(selector));
  return bodies.filter(function(body, index) {
    if (!normalizeText(body.textContent) || elementSubtreeHidden(body)) return false;
    return !bodies.some(function(other, otherIndex) {
      return otherIndex < index && other.contains(body);
    });
  });
}

function githubThreadAuthorNode(node) {
  if (!node) return null;

  var selectors = [
    "[data-testid='issue-body-header-author']",
    "[data-testid='avatar-link']",
    "[data-testid='actor-link']",
    "a.author",
    "[data-testid='comment-author']",
    "a[data-hovercard-type='user']"
  ];
  for (var index = 0; index < selectors.length; index += 1) {
    var author = node.querySelector(selectors[index]);
    if (author && normalizeText(author.textContent)) return author;
  }
  return null;
}

function githubThreadAuthor(node) {
  var author = githubThreadAuthorNode(node);
  return normalizeText((author && author.textContent) || "").replace(/^@/, "");
}

function githubThreadPermalink(node) {
  var link = node && node.querySelector([
    "a[href*='#issuecomment-']",
    "a[href*='#discussioncomment-']",
    "a[href*='#event-']",
    "a[href*='#pullrequestreview-']",
    "a[href*='#discussion_r']",
    "[data-testid='issue-body-header-link']",
    "a[href*='#issue-']"
  ].join(", "));
  return materializedHttpUrl(link && link.getAttribute("href"));
}

function githubThreadTimestamp(node) {
  var time = node && node.querySelector("relative-time[datetime], time[datetime]");
  return normalizeText((time && (time.getAttribute("datetime") || time.textContent)) || "");
}

function githubThreadNodeMarkdown(node) {
  return githubThreadBodies(node).map(function(body) {
    var clone = visibilityPrunedClone(body);
    removeAll(clone, ".js-comment-actions, .timeline-comment-actions, .reaction-summary-item, [aria-label='Add reaction'], button, [role='tooltip']");
    return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
  }).filter(function(markdown) {
    return !!normalizeText(markdown);
  }).join("\n\n");
}

function githubThreadScore(opening) {
  var score = opening && opening.querySelector("[data-testid='reaction-count'], [data-testid='vote-count']");
  var text = normalizeText((score && score.textContent) || "");
  return /^-?\d[\d,]*$/.test(text) ? Number(text.replace(/,/g, "")) : null;
}

function githubThreadCount(root) {
  var count = root.querySelector("[data-testid='issue-comment-count'], [data-testid='discussion-comment-count'], .js-discussion .comment-count, .comment-count");
  var text = normalizeText((count && count.textContent) || "");
  var match = text.match(/^(\d[\d,]*)\s+(?:comments?|replies)$/i);
  return match ? Number(match[1].replace(/,/g, "")) : null;
}
