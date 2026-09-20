function sourcehutTodoRoute() {
  var match = (location.pathname || "").match(/^\/(~[\w.%+-]+)\/([\w.%+-]+)\/(\d+)\/?$/);
  if (!match) return null;

  var trackerPath = "/" + match[1] + "/" + match[2];
  return {
    owner: match[1],
    tracker: match[2],
    number: match[3],
    community: match[1] + "/" + match[2],
    trackerPath: trackerPath,
    ticketPath: trackerPath + "/" + match[3]
  };
}

function sourcehutTodoSameOriginUrl(value) {
  var url = materializedHttpUrl(value);
  if (!url) return null;
  try {
    return new URL(url).origin === location.origin ? url : null;
  } catch (_error) {
    return null;
  }
}

function sourcehutTodoAssetEvidence() {
  return Array.prototype.slice.call(document.querySelectorAll("link[href], script[src]")).some(function(node) {
    var value = node.getAttribute("href") || node.getAttribute("src");
    var url = sourcehutTodoSameOriginUrl(value);
    if (!url) return false;
    return /\/static\/todo\.sr\.ht\/main\.min\.[a-z0-9]+\.css$/i.test(new URL(url).pathname);
  });
}

function sourcehutTodoRoot() {
  var identity = document.querySelector(".ticket-id");
  return (identity && identity.closest("main, .container")) || document.querySelector("main, .container");
}

function sourcehutTodoMetadataNode(root) {
  return Array.prototype.slice.call(root.querySelectorAll("dl.row")).find(function(node) {
    var labels = Array.prototype.slice.call(node.querySelectorAll("dt")).map(function(term) {
      return normalizeText(term.textContent).replace(/:$/, "").toLowerCase();
    });
    return labels.indexOf("status") >= 0 && labels.indexOf("submitter") >= 0;
  }) || null;
}

function sourcehutTodoMetadataField(root, label) {
  var metadata = sourcehutTodoMetadataNode(root);
  if (!metadata) return "";
  var wanted = label.toLowerCase();
  var term = Array.prototype.slice.call(metadata.querySelectorAll("dt")).find(function(node) {
    if (normalizeText(node.textContent).replace(/:$/, "").toLowerCase() !== wanted) return false;
    var value = node.nextElementSibling;
    if (!value || !value.matches("dd")) return false;
    var clone = visibilityPrunedClone(value);
    return !!normalizeText(clone && clone.textContent);
  });
  var value = term && term.nextElementSibling;
  var clone = value && visibilityPrunedClone(value);
  return normalizeText(clone && clone.textContent);
}

function sourcehutTodoProductMatch(route, root) {
  if (!route || !root) return false;
  var owner = normalizeText((root.querySelector(".tracker-owner") || {}).textContent || "");
  var tracker = normalizeText((root.querySelector(".tracker-name") || {}).textContent || "");
  var number = normalizeText((root.querySelector(".ticket-id") || {}).textContent || "").replace(/^#/, "");
  var title = normalizeText((root.querySelector(".ticket-title") || {}).textContent || "");
  var events = root.querySelector(".event-list.ticket-events");
  var navigation = Array.prototype.slice.call(document.querySelectorAll(
    ".header-tabbed.resource-nav.ticket-header a[href]"
  )).some(function(link) {
    var url = sourcehutTodoSameOriginUrl(link.getAttribute("href"));
    return url && new URL(url).pathname.replace(/\/$/, "") === route.trackerPath;
  });

  return owner === route.owner && tracker === route.tracker && number === route.number && !!title &&
    !!events && sourcehutTodoAssetEvidence() && navigation;
}

function sourcehutTodoNodeMarkdown(node) {
  if (!node) return "";
  var clone = visibilityPrunedClone(node);
  if (!clone) return "";
  removeAll(clone, "script, style, noscript, button, form, [role='tooltip'], .event-actions, .dropdown");
  return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
}

function sourcehutTodoMetadata(root) {
  var node = sourcehutTodoMetadataNode(root);
  if (!node) return null;
  var clone = visibilityPrunedClone(node);
  if (!clone) return null;
  removeAll(clone, "button, form, script, style, noscript");
  var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
  return normalizeText(markdown) ? { node: clone, markdown: markdown } : null;
}

function sourcehutTodoEventHeading(node) {
  return Array.prototype.slice.call(node.children).find(function(child) {
    return child.matches("h4");
  }) || null;
}

function sourcehutTodoEventPermalink(node, route) {
  var heading = sourcehutTodoEventHeading(node);
  var id = heading && heading.id;
  if (!/^event-\d+$/.test(id || "")) return null;
  var link = Array.prototype.slice.call(heading.querySelectorAll("a[href]")).find(function(candidate) {
    try {
      var url = new URL(candidate.getAttribute("href"), location.href);
      return url.origin === location.origin && url.pathname.replace(/\/$/, "") === route.ticketPath &&
        url.hash === "#" + id;
    } catch (_error) {
      return false;
    }
  });
  return link ? location.origin + route.ticketPath + "#" + id : null;
}

function sourcehutTodoEventAuthor(node) {
  var heading = sourcehutTodoEventHeading(node);
  var link = heading && Array.prototype.slice.call(heading.querySelectorAll("a[href]")).find(function(candidate) {
    return /^~[\w.%+-]+$/.test(normalizeText(candidate.textContent));
  });
  return normalizeText(link && link.textContent);
}

function sourcehutTodoEventTimestamp(node) {
  var time = node.querySelector(":scope > h4 time[datetime]");
  if (time) return normalizeText(time.getAttribute("datetime"));
  var titled = node.querySelector(":scope > h4 [title]");
  return normalizeText(titled && titled.getAttribute("title"));
}

function sourcehutTodoEventContext(node, route) {
  var heading = sourcehutTodoEventHeading(node);
  if (!heading) return "";
  var clone = visibilityPrunedClone(heading);
  if (!clone) return "";
  var author = Array.prototype.slice.call(clone.querySelectorAll("a[href]")).find(function(link) {
    return /^~[\w.%+-]+$/.test(normalizeText(link.textContent));
  });
  if (author) author.remove();
  Array.prototype.slice.call(clone.querySelectorAll("a[href]")).forEach(function(link) {
    try {
      if (new URL(link.getAttribute("href"), location.href).hash === "#" + heading.id) link.remove();
    } catch (_error) {
      // Preserve malformed non-control context for the final URL sanitizer.
    }
  });
  return normalizeText(clone.textContent);
}

function sourcehutTodoEventBody(node) {
  var body = Array.prototype.slice.call(node.children).find(function(child) {
    return child.matches("blockquote, .event-body");
  });
  return body ? sourcehutTodoNodeMarkdown(body) : "";
}

function sourcehutTodoEventMarkdown(node, route) {
  var context = sourcehutTodoEventContext(node, route);
  var body = sourcehutTodoEventBody(node);
  return [context, body].filter(Boolean).join("\n\n").replace(/^\s+/gm, "");
}

function sourcehutTodoEventEntry(node, route) {
  var body = sourcehutTodoEventBody(node);
  var markdown = sourcehutTodoEventMarkdown(node, route);
  if (!normalizeText(markdown)) return null;
  return {
    sourceNode: visibilityPrunedClone(node),
    kind: body ? "Comment" : "Event",
    author: sourcehutTodoEventAuthor(node),
    timestamp: sourcehutTodoEventTimestamp(node),
    permalink: sourcehutTodoEventPermalink(node, route),
    markdown: markdown
  };
}

function sourcehutTodoEntries(root, route) {
  var list = root.querySelector(".event-list.ticket-events");
  if (!list) return [];
  var entries = Array.prototype.slice.call(list.children).filter(function(node) {
    return node.matches(".event") && !elementSubtreeHidden(node);
  }).map(function(node) {
    return sourcehutTodoEventEntry(node, route);
  });
  return deduplicateForgeThreadPermalinks(entries);
}

function sourcehutTodoEmailInstruction(root, route) {
  var link = Array.prototype.slice.call(root.querySelectorAll("a[href^='mailto:']")).find(function(candidate) {
    var value = candidate.getAttribute("href") || "";
    return value.indexOf("/" + route.number + "@todo.sr.ht") >= 0;
  });
  var value = link && link.getAttribute("href");
  if (!value) return "";
  return "Email comments: `" + value.replace(/`/g, "") + "`";
}

function sourcehutTodoInventory(route, root) {
  var entries = [
    { label: "Tracker", url: location.origin + route.trackerPath },
    { label: "Ticket", url: location.origin + route.ticketPath }
  ];
  var links = Array.prototype.slice.call(document.querySelectorAll(
    ".project-nav a[href], .resource-nav a[href]"
  )).concat(Array.prototype.slice.call(root.querySelectorAll(
    "dl.row a[href], .event-list.ticket-events a[href]"
  )));
  links.forEach(function(link) {
    var url = link.closest(".project-nav")
      ? materializedHttpUrl(link.getAttribute("href"))
      : sourcehutTodoSameOriginUrl(link.getAttribute("href"));
    if (!url) return;
    entries.push({ label: normalizeText(link.textContent) || "Related resource", url: url });
  });
  return browsableInventory("Browse this SourceHut ticket", entries);
}
