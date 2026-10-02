  function sourceOwnedTypedRuntimeDetailListLoss(content, candidate) {
    if (!content || content.contentType !== "article" || !candidate || candidate.contentType !== "list") return false;
    var runtimeScript = document.getElementById("__NEXT_DATA__");
    if (!runtimeScript) return false;

    var runtime;
    try { runtime = JSON.parse(runtimeScript.textContent || ""); } catch (error) { return false; }
    var routeParts = String(runtime && runtime.page || "").split("/").filter(Boolean);
    var pathParts = String(location.pathname || "").split("/").filter(Boolean);
    if (!routeParts.length || routeParts.length !== pathParts.length ||
        !/^\[[^\]]+\]$/.test(routeParts[routeParts.length - 1])) return false;

    var recordId;
    try { recordId = decodeURIComponent(pathParts[pathParts.length - 1]); } catch (error) { return false; }
    if (!recordId) return false;
    var routeMatches = routeParts.every(function(routePart, index) {
      if (/^\[[^\]]+\]$/.test(routePart)) return true;
      try { return decodeURIComponent(pathParts[index]) === routePart; } catch (error) { return false; }
    });
    if (!routeMatches) return false;

    var pageProps = runtime.props && (runtime.props.pageProps || runtime.props);
    if (!pageProps || typeof pageProps !== "object") return false;
    var records = [];
    function visit(value, insideCollection) {
      if (!value || typeof value !== "object") return;
      if (Array.isArray(value)) {
        value.forEach(function(item) { visit(item, true); });
        return;
      }
      if (!insideCollection && String(value.id || "") === recordId) records.push(value);
      Object.keys(value).forEach(function(key) {
        visit(value[key], insideCollection);
      });
    }
    visit(pageProps, false);
    if (records.length !== 1 || typeof records[0] !== "object") return false;

    var mains = Array.prototype.filter.call(document.querySelectorAll("main, [role='main']"), function(main) {
      return !elementSubtreeHidden(main) && !main.parentElement.closest("main, [role='main']");
    });
    if (mains.length !== 1) return false;
    var mainText = normalizeText(mains[0].textContent || "");
    var selectedRoot = document.createElement("div");
    selectedRoot.innerHTML = content.html || "";
    var selectedText = normalizeText(selectedRoot.textContent || content.textContent || "");
    var candidateExcerpt = normalizeText(candidate.excerpt || "");
    if (!mainText || !selectedText) return false;

    var missingDetailWitness = false;
    function inspectOwner(value) {
      if (missingDetailWitness || !value || typeof value !== "object") return;
      if (Array.isArray(value)) return;
      Object.keys(value).forEach(function(key) {
        var child = value[key];
        if (typeof child === "string") {
          var text = normalizeText(child);
          if (text.length >= 7 && mainText.indexOf(text) !== -1 && selectedText.indexOf(text) !== -1 &&
              candidateExcerpt.indexOf(text) === -1) missingDetailWitness = true;
        } else if (child && typeof child === "object") {
          inspectOwner(child);
        }
      });
    }
    inspectOwner(records[0]);
    return missingDetailWitness;
  }
