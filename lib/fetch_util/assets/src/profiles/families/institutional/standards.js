  function standardsRecordContent(metadata) {
    var designation = document.querySelector("#stnd-designation, [id*='standard' i][id*='designation' i], [class*='standard' i][class*='designation' i]");
    var title = document.querySelector("#stnd-title, [id*='standard' i][id*='title' i], [class*='standard' i][class*='title' i]");
    var details = document.querySelector("#standard-details, [id*='standard' i][id*='details' i], [class*='standard' i][class*='details' i]");
    var description = document.querySelector("#stnd-description, [id*='standard' i][id*='description' i], [class*='standard' i][class*='description' i]");
    var titleSection = document.querySelector("#page-title.standard, [class*='standard' i][id*='title' i]");
    var main = document.querySelector("#content.standard #main-content, main #main-content, main");

    if (!designation || !title || !details || !description || !main || !titleSection) return null;

    var root = document.createElement("article");
    if (titleSection) root.appendChild(safeDeepClone(titleSection, document));
    root.appendChild(safeDeepClone(description, document));
    root.appendChild(safeDeepClone(details, document));

    var workingGroup = main.querySelector("#working-group-details");
    if (workingGroup) {
      var workingGroupClone = safeDeepClone(workingGroup, document);
      workingGroupClone.querySelectorAll("#working-group-projects-standards, .tab-content, .nav-tabs, [role='tablist']").forEach(function(el) { el.remove(); });
      root.appendChild(workingGroupClone);
    }

    return institutionalArticleResult(metadata, root, {
      minText: 250,
      title: normalizeText([designation.textContent, title.textContent].join(" - ")),
      strip: function(clone) {
        removeAll(clone, COMMON_INSTITUTIONAL_CHROME_SELECTOR + ", form, .osano-cm-window, [class*='cookie' i], [class*='newsletter' i]");
      }
    });
  }
