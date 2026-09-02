function bitbucketCloudPullApiRouteFromPath(pathname, resource) {
  if (!["activity", "statuses"].includes(resource)) return null;
  var match = (pathname || "").match(
    /^\/(?:(!api)\/)?2\.0\/repositories\/([^/]+)\/([^/]+)\/pullrequests\/(\d+)\/(activity|statuses)\/?$/
  );
  if (!match || match[5] !== resource) return null;

  var workspace;
  var repository;
  try {
    workspace = decodeURIComponent(match[2]);
    repository = decodeURIComponent(match[3]);
  } catch (_error) {
    return null;
  }
  if (!workspace || !repository || /[\/?#]/.test(workspace) || /[\/?#]/.test(repository)) return null;

  var apiPrefix = match[1] ? "/!api/2.0" : "/2.0";
  var pullRequestPath = apiPrefix + "/repositories/" + match[2] + "/" + match[3] +
    "/pullrequests/" + match[4];
  return {
    workspace: workspace,
    repository: repository,
    number: match[4],
    community: workspace + "/" + repository,
    apiPrefix: apiPrefix,
    pullRequestPath: pullRequestPath,
    resourcePath: pullRequestPath + "/" + resource
  };
}

function bitbucketCloudJsonObjectPayload() {
  if (!/^application\/json(?:$|;)/i.test(document.contentType || "")) return null;
  var nodes = document.querySelectorAll("body > pre");
  if (nodes.length !== 1) return null;

  try {
    var payload = JSON.parse(nodes[0].textContent || "");
    return payload && typeof payload === "object" && !Array.isArray(payload) ? payload : null;
  } catch (_error) {
    return null;
  }
}

function bitbucketCloudInlineText(value) {
  if (typeof value !== "string" && typeof value !== "number") return "";
  var text = normalizeText(String(value));
  text = text.replace(/(?:[a-z][a-z0-9+.-]*:)?\/\/[^\s<>\[\]()]+/gi, function(candidate) {
    return bitbucketCloudSafeHttpUrl(candidate) || "[unsafe URL removed]";
  });
  text = text.replace(/(?:javascript|data|vbscript|file|ftp|ftps|ssh|mailto|tel|sms|geo|magnet|irc|ircs):\S+/gi,
    "[unsafe URL removed]");
  return text.replace(/([\\`*_[\]<>])/g, "\\$1");
}
