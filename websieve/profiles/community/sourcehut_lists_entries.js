function sourcehutListsEntryWrapper(nodes) {
  var wrapper = document.createElement("div");
  nodes.forEach(function(node) {
    var clone = visibilityPrunedClone(node);
    if (clone) wrapper.appendChild(clone);
  });
  removeAll(wrapper, "script, style, noscript, button, form, details, summary, [role='tooltip'], a.btn");
  var markdown = cleanupMarkdownNoise(markdownFor(wrapper.innerHTML));
  return normalizeText(markdown) ? { node: wrapper, markdown: markdown } : null;
}

function sourcehutListsMessageAuthor(header) {
  var from = header && header.querySelector(":scope > .from");
  var link = from && Array.prototype.slice.call(from.querySelectorAll(":scope > a[href]")).find(function(candidate) {
    return !/^mailto:/i.test(candidate.getAttribute("href") || "");
  });
  var value = normalizeText(link && link.textContent);
  if (value) return value;
  return normalizeText(from && from.textContent).replace(/\s*<[^>]+>\s*$/, "");
}

function sourcehutListsMessageTime(header) {
  var link = header && header.querySelector(":scope > .date > a");
  return normalizeText(link && link.textContent);
}

function sourcehutListsMessagePermalink(header, route, root) {
  var link = header && header.querySelector(":scope > .date > a[href]");
  if (!link) return null;
  try {
    var url = new URL(link.getAttribute("href"), location.href);
    if (url.origin !== location.origin || url.pathname.replace(/\/$/, "") !== route.patchsetPath || !url.hash) return null;
    var target = document.getElementById(safeDecodeURI(url.hash.slice(1)));
    return target && root.contains(target) ? location.origin + route.patchsetPath + url.hash : null;
  } catch (_error) {
    return null;
  }
}

function sourcehutListsOpening(root, route, patchInfos) {
  var identity = sourcehutListsIdentity(root);
  var header = identity && identity.heading.parentElement.querySelector(":scope > .message-header");
  var body = sourcehutListsOpeningBody(root);
  var rendered = sourcehutListsEntryWrapper([header, body].filter(Boolean));
  if (!rendered) return null;
  var openingId = normalizeText((header && header.querySelector(":scope > .date > a[id]") || {}).id || "");
  var firstPatch = patchInfos[0];
  var firstHeader = firstPatch && firstPatch.heading.nextElementSibling;
  var firstId = normalizeText((firstHeader && firstHeader.querySelector(":scope > .date > a[id]") || {}).id || "");
  return {
    sourceNode: rendered.node,
    markdown: rendered.markdown,
    author: sourcehutListsMessageAuthor(header),
    timestamp: sourcehutListsMessageTime(header),
    generated: !!openingId && openingId === firstId
  };
}

function sourcehutListsTimelineColumn(root) {
  var body = sourcehutListsOpeningBody(root);
  return body && body.parentElement;
}

function sourcehutListsTimelineRecords(root, route) {
  var column = sourcehutListsTimelineColumn(root);
  var opening = sourcehutListsOpeningBody(root);
  if (!column) return [];
  var records = [];
  Array.prototype.slice.call(column.children).forEach(function(child) {
    if (child === opening) return;
    if (child.matches(".event-list.tool-status")) {
      Array.prototype.slice.call(child.children).forEach(function(event) {
        if (!event.matches(".event")) return;
        var rendered = sourcehutListsEntryWrapper([event]);
        if (rendered) records.push({ sourceNode: rendered.node, kind: "Tool event", markdown: rendered.markdown });
      });
      return;
    }
    if (child.matches(".alert.alert-info")) {
      var notice = sourcehutListsEntryWrapper([child]);
      if (notice) records.push({ sourceNode: notice.node, kind: "Revision notice", markdown: notice.markdown });
      return;
    }
    if (!child.matches(".message-header")) return;
    var nodes = [child];
    var sibling = child.nextElementSibling;
    while (sibling && !sibling.matches(".message-header")) {
      nodes.push(sibling);
      sibling = sibling.nextElementSibling;
    }
    var rendered = sourcehutListsEntryWrapper(nodes);
    if (!rendered) return;
    records.push({
      sourceNode: rendered.node,
      kind: "Feedback",
      author: sourcehutListsMessageAuthor(child),
      timestamp: sourcehutListsMessageTime(child),
      permalink: sourcehutListsMessagePermalink(child, route, root),
      markdown: rendered.markdown
    });
  });
  return deduplicateForgeThreadPermalinks(records);
}

function sourcehutListsPatchMessageHeader(info) {
  var sibling = info.heading.nextElementSibling;
  return sibling && sibling.matches(".message-header") ? sibling : null;
}

function sourcehutListsPatchRecords(root, route) {
  var infos = sourcehutListsPatchInfos(root, route);
  var records = infos.map(function(info) {
    var nodes = [info.heading];
    var sibling = info.heading.nextElementSibling;
    while (sibling && !sourcehutListsPatchInfo(sibling, route)) {
      nodes.push(sibling);
      sibling = sibling.nextElementSibling;
    }
    var rendered = sourcehutListsEntryWrapper(nodes);
    if (!rendered) return null;
    var header = sourcehutListsPatchMessageHeader(info);
    return {
      sourceNode: rendered.node,
      kind: "Patch",
      subject: info.subject,
      author: sourcehutListsMessageAuthor(header),
      timestamp: sourcehutListsMessageTime(header),
      permalink: info.rawUrl,
      rawUrl: info.rawUrl,
      markdown: rendered.markdown
    };
  }).filter(Boolean);
  return deduplicateForgeThreadPermalinks(records);
}

function sourcehutListsRecordSections(records) {
  var sections = [];
  records.forEach(function(record) {
    var heading = record.subject || record.kind;
    if (record.author) heading += " by " + record.author;
    if (record.permalink) heading = markdownLink(heading, record.permalink);
    sections.push("### " + heading);
    if (record.timestamp) sections.push("- Time: " + record.timestamp);
    sections.push(record.markdown);
  });
  return sections;
}
