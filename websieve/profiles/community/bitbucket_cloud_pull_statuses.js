function bitbucketCloudStatusRouteFromPath(pathname) {
  var route = bitbucketCloudPullApiRouteFromPath(pathname, "statuses");
  if (!route) return null;
  route.statusesPath = route.resourcePath;
  return route;
}

function bitbucketCloudPullStatusRoute() {
  return bitbucketCloudStatusRouteFromPath(location.pathname);
}

function bitbucketCloudStatusApiLinkMatches(value, route, suffix) {
  var url = bitbucketCloudSafeHttpUrl(value);
  if (!url) return false;

  try {
    var parsed = new URL(url);
    var prefix = "/(?:!api/)?2\\.0/repositories/";
    var pattern = new RegExp("^" + prefix + "([^/]+)/([^/]+)" + suffix + "/?$");
    var match = parsed.pathname.match(pattern);
    return parsed.origin === location.origin && !!match &&
      safeDecodeURI(match[1]).toLowerCase() === route.workspace.toLowerCase() &&
      safeDecodeURI(match[2]).toLowerCase() === route.repository.toLowerCase();
  } catch (_error) {
    return false;
  }
}

function bitbucketCloudStatusRecordMatches(record, route, repositoryUuid) {
  if (!record || typeof record !== "object" || Array.isArray(record)) return false;
  if (record.type !== "build" || typeof record.key !== "string" || !record.key.trim()) return false;
  if (typeof record.state !== "string" || !record.state.trim()) return false;

  var commit = record.commit;
  var repository = record.repository;
  if (!commit || commit.type !== "commit" || typeof commit.hash !== "string") return false;
  if (!repository || repository.type !== "repository" || typeof repository.full_name !== "string") return false;
  if (typeof repository.uuid !== "string") return false;

  var hash = commit.hash.trim().toLowerCase();
  var fullName = repository.full_name.trim().toLowerCase();
  var uuid = repository.uuid.trim().toLowerCase();
  if (!/^[0-9a-f]{40}$/.test(hash)) return false;
  if (fullName !== route.community.toLowerCase()) return false;
  if (!/^\{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}$/.test(uuid)) return false;
  if (repositoryUuid && uuid !== repositoryUuid) return false;

  var repositorySelf = repository.links && repository.links.self && repository.links.self.href;
  var commitSelf = commit.links && commit.links.self && commit.links.self.href;
  var statusSelf = record.links && record.links.self && record.links.self.href;
  return bitbucketCloudStatusApiLinkMatches(repositorySelf, route, "") &&
    bitbucketCloudStatusApiLinkMatches(commitSelf, route, "/commit/" + hash) &&
    bitbucketCloudStatusApiLinkMatches(statusSelf, route, "/commit/" + hash + "/statuses/build/[^/]+");
}

function bitbucketCloudStatusResponse(payload, route) {
  if (!Array.isArray(payload.values)) return null;
  if (!Number.isInteger(payload.page) || payload.page <= 0) return null;
  if (!Number.isInteger(payload.pagelen) || payload.pagelen <= 0) return null;
  if (!Number.isInteger(payload.size) || payload.size < 0) return null;
  if (payload.values.length > payload.pagelen || payload.values.length > payload.size) return null;
  if (payload.values.length === 0) return null;

  var repositoryUuid = null;
  for (var index = 0; index < payload.values.length; index += 1) {
    if (!bitbucketCloudStatusRecordMatches(payload.values[index], route, repositoryUuid)) return null;
    repositoryUuid = payload.values[index].repository.uuid.trim().toLowerCase();
  }
  return { payload: payload, repositoryUuid: repositoryUuid };
}

function bitbucketCloudStatusContinuation(value, route) {
  if (value == null) return { provided: false, url: null };
  if (typeof value !== "string") return { provided: true, url: null };
  var safe = bitbucketCloudSafeHttpUrl(value);
  if (!safe) return { provided: true, url: null };

  try {
    var parsed = new URL(safe);
    var continuationRoute = bitbucketCloudStatusRouteFromPath(parsed.pathname);
    var continuationPrefix = parsed.pathname.indexOf("/!api/2.0/") === 0 ? "/!api/2.0" : "/2.0";
    var routePrefix = route.statusesPath.indexOf("/!api/2.0/") === 0 ? "/!api/2.0" : "/2.0";
    var matches = continuationRoute && parsed.origin === location.origin && !parsed.hash &&
      continuationPrefix === routePrefix &&
      continuationRoute.community.toLowerCase() === route.community.toLowerCase() &&
      continuationRoute.number === route.number && parsed.href !== location.href;
    return { provided: true, url: matches ? parsed.href : null };
  } catch (_error) {
    return { provided: true, url: null };
  }
}

function bitbucketCloudStatusInventory(route, payload, continuations) {
  var entries = [
    { label: "Pull request API", url: location.origin + route.pullRequestPath },
    { label: "Statuses API", url: location.origin + route.statusesPath }
  ];
  if (continuations.previous.url) entries.push({ label: "Previous statuses API page", url: continuations.previous.url });
  if (continuations.next.url) entries.push({ label: "Next statuses API page", url: continuations.next.url });

  payload.values.forEach(function(record, index) {
    var name = bitbucketCloudInlineText(record.name) || bitbucketCloudInlineText(record.key) || String(index + 1);
    var resultUrl = bitbucketCloudSafeHttpUrl(record.url);
    var statusUrl = bitbucketCloudSafeHttpUrl(record.links && record.links.self && record.links.self.href);
    var commitUrl = bitbucketCloudSafeHttpUrl(record.commit && record.commit.links &&
      record.commit.links.html && record.commit.links.html.href);
    if (resultUrl) entries.push({ label: "Build result for " + name, url: resultUrl });
    if (statusUrl) entries.push({ label: "Status record " + (index + 1), url: statusUrl });
    if (commitUrl) entries.push({ label: "Commit for " + name, url: commitUrl });
  });
  return entries;
}

function bitbucketCloudStatusSections(record, index) {
  var name = bitbucketCloudInlineText(record.name) || bitbucketCloudInlineText(record.key) ||
    ("Status " + (index + 1));
  var sections = ["### Status " + (index + 1) + ": " + name];
  [
    ["State", record.state],
    ["Key", record.key],
    ["Reference", record.refname],
    ["Commit", record.commit && record.commit.hash],
    ["Description", record.description],
    ["Created", record.created_on],
    ["Updated", record.updated_on]
  ].forEach(function(pair) {
    var value = bitbucketCloudInlineText(pair[1]);
    if (value) sections.push("- " + pair[0] + ": " + value);
  });
  var safeRecord = bitbucketCloudSafeSupplementalValue(record);
  sections.push("#### Complete status record", fencedCodeBlock("json", JSON.stringify(safeRecord, null, 2)).trim());
  return sections;
}

function bitbucketCloudPullStatusesContent(metadata) {
  var route = bitbucketCloudPullStatusRoute();
  var response = route && bitbucketCloudStatusResponse(bitbucketCloudJsonObjectPayload() || {}, route);
  if (!response) return null;
  if (metadata) metadata.language = null;

  var payload = response.payload;
  var continuations = {
    previous: bitbucketCloudStatusContinuation(payload.previous, route),
    next: bitbucketCloudStatusContinuation(payload.next, route)
  };
  var terminalIncomplete = !continuations.next.url &&
    ((payload.page - 1) * payload.pagelen) + payload.values.length < payload.size;
  var continuationInvalid = terminalIncomplete ||
    (continuations.previous.provided && !continuations.previous.url) ||
    (continuations.next.provided && !continuations.next.url);
  var title = "Bitbucket pull request " + route.number + " build statuses";
  var sections = [
    "# " + title,
    "- Repository: " + bitbucketCloudInlineText(route.community),
    "- Pull request: " + route.number,
    "- Statuses shown on this API page: " + payload.values.length,
    "- Page: " + payload.page,
    "- Page length: " + payload.pagelen,
    "- Total statuses: " + payload.size
  ];
  payload.values.forEach(function(record, index) {
    sections = sections.concat(bitbucketCloudStatusSections(record, index));
  });
  if (continuationInvalid) {
    var warning = terminalIncomplete
      ? "API counters indicate omitted statuses, but no safe next page was available."
      : "A pagination continuation was present but could not be safely traversed.";
    sections.push("## Retrieval warning", warning);
  }
  sections.push(browsableInventory(
    "Browse these Bitbucket build statuses",
    bitbucketCloudStatusInventory(route, payload, continuations)
  ));
  var markdown = sections.filter(Boolean).join("\n\n");
  var safePayload = bitbucketCloudSafeSupplementalValue(payload);
  if (continuations.next.provided && !continuations.next.url) delete safePayload.next;
  if (continuations.previous.provided && !continuations.previous.url) delete safePayload.previous;
  var pre = document.createElement("pre");
  pre.textContent = JSON.stringify(safePayload, null, 2);
  var first = payload.values[0];

  return {
    title: title,
    siteName: "Bitbucket",
    excerpt: first ? bitbucketCloudInlineText(first.state) + ": " +
      (bitbucketCloudInlineText(first.name) || bitbucketCloudInlineText(first.key)) :
      "No build statuses returned on this API page.",
    html: pre.outerHTML,
    markdown: markdown,
    textContent: normalizeText(markdown),
    warningReasons: continuationInvalid ? ["bitbucket_cloud_statuses_incomplete"] : [],
    hostAware: true,
    readerMode: false,
    contentType: "list"
  };
}

function registerBitbucketCloudPullStatusProfiles() {
  registerHostAwareProfile(true, bitbucketCloudPullStatusesContent);
}
