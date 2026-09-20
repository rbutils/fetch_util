function giteaFamilyPullResourceContent(metadata) {
  var route = giteaFamilyPullResourceRoute();
  if (!route) return null;

  var root = giteaFamilyPullResourceRoot(route);
  if (!giteaFamilyPullResourceProductMatch(route, root)) return null;
  if (giteaFamilyPullResourceSurface(route) === "commits") {
    return giteaFamilyPullCommitsContent(metadata, route, root);
  }
  if (giteaFamilyPullResourceSurface(route) === "files") {
    return giteaFamilyPullFilesContent(metadata, route, root);
  }
  return null;
}

function registerGiteaFamilyPullResourceProfiles() {
  registerHostAwareProfile(true, giteaFamilyPullResourceContent);
}
