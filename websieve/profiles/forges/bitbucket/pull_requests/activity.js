function bitbucketCloudActivityRouteFromPath(pathname) {
  var route = bitbucketCloudPullApiRouteFromPath(pathname, "activity");
  if (!route) return null;
  route.activityPath = route.resourcePath;
  return route;
}

function bitbucketCloudPullActivityRoute() {
  return bitbucketCloudActivityRouteFromPath(location.pathname);
}

function bitbucketCloudActivityApiUrl(value, route, suffix, allowQuery) {
  var safe = bitbucketCloudSafeHttpUrl(value);
  if (!safe) return null;
  try {
    var parsed = new URL(safe);
    var match = parsed.pathname.match(
      /^\/(?:(!api)\/)?2\.0\/repositories\/([^/]+)\/([^/]+)\/pullrequests\/(\d+)(\/.*)?$/
    );
    var matchedSuffix = (match && match[5] || "").replace(/\/$/, "");
    if (!match || parsed.hash || (!allowQuery && parsed.search) || matchedSuffix !== suffix ||
        safeDecodeURI(match[2]).toLowerCase() !== route.workspace.toLowerCase() ||
        safeDecodeURI(match[3]).toLowerCase() !== route.repository.toLowerCase() || match[4] !== route.number) return null;
    var prefix = match[1] ? "/!api/2.0" : "/2.0";
    if (parsed.origin === location.origin && prefix === route.apiPrefix) return parsed.href;
    var canonicalApiHost = "api." + location.hostname.toLowerCase();
    if (route.apiPrefix === "/!api/2.0" && prefix === "/2.0" && parsed.protocol === location.protocol &&
        parsed.hostname.toLowerCase() === canonicalApiHost && parsed.port === location.port) {
      return location.origin + route.apiPrefix + parsed.pathname.slice("/2.0".length) + parsed.search;
    }
  } catch (_error) {
    return null;
  }
  return null;
}

function bitbucketCloudActivityPullRequestMatches(pullRequest, route) {
  if (!pullRequest || pullRequest.type !== "pullrequest" || !Number.isInteger(pullRequest.id) ||
      String(pullRequest.id) !== route.number) return false;
  var self = pullRequest.links && pullRequest.links.self && pullRequest.links.self.href;
  if (!bitbucketCloudActivityApiUrl(self, route, "")) return false;

  var html = pullRequest.links && pullRequest.links.html && pullRequest.links.html.href;
  if (!html) return true;
  var safeHtml = bitbucketCloudSafeHttpUrl(html);
  if (!safeHtml) return false;
  try {
    var htmlUrl = new URL(safeHtml);
    var match = htmlUrl.pathname.match(/^\/([^/]+)\/([^/]+)\/pull-requests\/(\d+)\/?$/);
    return !!match && !htmlUrl.search && !htmlUrl.hash &&
      safeDecodeURI(match[1]).toLowerCase() === route.workspace.toLowerCase() &&
      safeDecodeURI(match[2]).toLowerCase() === route.repository.toLowerCase() && match[3] === route.number;
  } catch (_error) {
    return false;
  }
}

function bitbucketCloudActivityCommentMatches(comment, route) {
  if (!Number.isInteger(comment.id) || comment.id <= 0 || comment.type !== "pullrequest_comment") return false;
  var self = comment.links && comment.links.self && comment.links.self.href;
  return !!bitbucketCloudActivityApiUrl(self, route, "/comments/" + comment.id);
}

function bitbucketCloudActivityRecord(record, route) {
  if (!record || typeof record !== "object" || Array.isArray(record) ||
      !bitbucketCloudActivityPullRequestMatches(record.pull_request, route)) return null;
  var eventNames = Object.keys(record).filter(function(key) { return key !== "pull_request"; });
  if (eventNames.length !== 1 || !/^[a-z][a-z0-9_]*$/.test(eventNames[0])) return null;
  var eventName = eventNames[0];
  var event = record[eventName];
  if (!event || typeof event !== "object" || Array.isArray(event)) return null;
  if (event.pullrequest && !bitbucketCloudActivityPullRequestMatches(event.pullrequest, route)) return null;
  if (event.pull_request && !bitbucketCloudActivityPullRequestMatches(event.pull_request, route)) return null;
  if (eventName === "comment" && !bitbucketCloudActivityCommentMatches(event, route)) return null;
  var timestamp = event.date || event.created_on || event.updated_on;
  if (typeof timestamp !== "string" || !timestamp.trim()) return null;
  return { source: record, eventName: eventName, event: event };
}

function bitbucketCloudActivityResponse(payload, route) {
  if (!Array.isArray(payload.values) || !Number.isInteger(payload.pagelen) || payload.pagelen <= 0 ||
      payload.values.length === 0 || payload.values.length > payload.pagelen) return null;
  if (payload.page != null && (!Number.isInteger(payload.page) || payload.page <= 0)) return null;
  if (payload.size != null && (!Number.isInteger(payload.size) || payload.size < payload.values.length)) return null;
  if (payload.page != null && payload.size != null &&
      ((payload.page - 1) * payload.pagelen) + payload.values.length > payload.size) return null;
  var records = payload.values.map(function(record) {
    return bitbucketCloudActivityRecord(record, route);
  });
  return records.every(Boolean) ? { payload: payload, records: records } : null;
}

function bitbucketCloudActivityContinuation(value, route) {
  if (value == null) return { provided: false, url: null };
  if (typeof value !== "string") return { provided: true, url: null };
  var mapped = bitbucketCloudActivityApiUrl(value, route, "/activity", true);
  return { provided: true, url: mapped && mapped !== location.href ? mapped : null };
}

function bitbucketCloudActivityActor(event) {
  var actor = event.user || event.author || event.actor || event.creator;
  return bitbucketCloudInlineText(actor && (actor.display_name || actor.nickname || actor.username));
}

function bitbucketCloudActivityLabel(eventName) {
  return eventName.split("_").map(function(part) {
    return part ? part.charAt(0).toUpperCase() + part.slice(1) : "";
  }).join(" ");
}

function bitbucketCloudActivitySections(record, index) {
  var event = record.event;
  var label = bitbucketCloudActivityLabel(record.eventName);
  var sections = ["### Activity " + (index + 1) + ": " + label];
  [
    ["Actor", bitbucketCloudActivityActor(event)],
    ["Date", event.date || event.created_on || event.updated_on],
    ["State", event.state],
    ["Title", event.title],
    ["Comment ID", event.id]
  ].forEach(function(pair) {
    var value = bitbucketCloudInlineText(pair[1]);
    if (value) sections.push("- " + pair[0] + ": " + value);
  });
  sections.push("#### Complete activity record", fencedCodeBlock(
    "json",
    JSON.stringify(bitbucketCloudSafeSupplementalValue(record.source), null, 2)
  ).trim());
  return sections;
}

function bitbucketCloudActivityInventory(route, records, continuations) {
  var entries = [
    { label: "Pull request API", url: location.origin + route.pullRequestPath },
    { label: "Activity API", url: location.origin + route.activityPath }
  ];
  if (continuations.previous.url) entries.push({ label: "Previous activity API page", url: continuations.previous.url });
  if (continuations.next.url) entries.push({ label: "Next activity API page", url: continuations.next.url });
  var pullRequest = records[0].source.pull_request;
  var pullHtml = bitbucketCloudSafeHttpUrl(pullRequest.links && pullRequest.links.html && pullRequest.links.html.href);
  if (pullHtml) entries.push({ label: "Pull request", url: pullHtml });
  records.forEach(function(record, index) {
    var event = record.event;
    var self = event.links && event.links.self && event.links.self.href;
    var mappedSelf = record.eventName === "comment"
      ? bitbucketCloudActivityApiUrl(self, route, "/comments/" + event.id)
      : null;
    var html = bitbucketCloudSafeHttpUrl(event.links && event.links.html && event.links.html.href);
    var actor = event.user || event.author || event.actor;
    var actorHtml = bitbucketCloudSafeHttpUrl(actor && actor.links && actor.links.html && actor.links.html.href);
    if (mappedSelf) entries.push({ label: "Activity record " + (index + 1), url: mappedSelf });
    if (html) entries.push({ label: "Activity view " + (index + 1), url: html });
    if (actorHtml) entries.push({ label: "Actor for activity " + (index + 1), url: actorHtml });
  });
  return entries;
}

function bitbucketCloudPullActivityContent(metadata) {
  var route = bitbucketCloudPullActivityRoute();
  var response = route && bitbucketCloudActivityResponse(bitbucketCloudJsonObjectPayload() || {}, route);
  if (!response) return null;
  if (metadata) metadata.language = null;
  var payload = response.payload;
  var records = response.records;
  var continuations = {
    previous: bitbucketCloudActivityContinuation(payload.previous, route),
    next: bitbucketCloudActivityContinuation(payload.next, route)
  };
  var terminalIncomplete = payload.size != null && payload.page != null && !continuations.next.url &&
    ((payload.page - 1) * payload.pagelen) + payload.values.length < payload.size;
  var continuationInvalid = terminalIncomplete ||
    (continuations.previous.provided && !continuations.previous.url) ||
    (continuations.next.provided && !continuations.next.url);
  var title = "Bitbucket pull request " + route.number + " activity";
  var sections = [
    "# " + title,
    "- Repository: " + bitbucketCloudInlineText(route.community),
    "- Pull request: " + route.number,
    "- Activity records shown on this API page: " + records.length,
    "- Page length: " + payload.pagelen
  ];
  if (payload.page != null) sections.push("- Page: " + payload.page);
  if (payload.size != null) sections.push("- Total activity records: " + payload.size);
  records.forEach(function(record, index) {
    sections = sections.concat(bitbucketCloudActivitySections(record, index));
  });
  if (continuationInvalid) {
    sections.push("## Retrieval warning", terminalIncomplete
      ? "API counters indicate omitted activity records, but no safe next page was available."
      : "A pagination continuation was present but could not be safely traversed.");
  }
  sections.push(browsableInventory(
    "Browse this Bitbucket pull request activity",
    bitbucketCloudActivityInventory(route, records, continuations)
  ));
  var markdown = sections.filter(Boolean).join("\n\n");
  var safePayload = bitbucketCloudSafeSupplementalValue(payload);
  if (continuations.next.provided && !continuations.next.url) delete safePayload.next;
  if (continuations.previous.provided && !continuations.previous.url) delete safePayload.previous;
  var pre = document.createElement("pre");
  pre.textContent = JSON.stringify(safePayload, null, 2);

  return {
    title: title,
    siteName: "Bitbucket",
    excerpt: bitbucketCloudActivityLabel(records[0].eventName) + ": " +
      (bitbucketCloudActivityActor(records[0].event) || bitbucketCloudInlineText(route.community)),
    html: pre.outerHTML,
    markdown: markdown,
    textContent: normalizeText(markdown),
    warningReasons: continuationInvalid ? ["bitbucket_cloud_activity_incomplete"] : [],
    hostAware: true,
    readerMode: false,
    contentType: "list"
  };
}

function registerBitbucketCloudPullActivityProfiles() {
  registerHostAwareProfile(true, bitbucketCloudPullActivityContent);
}
