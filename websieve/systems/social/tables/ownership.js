  function tableSocialTables() {
    return Array.from(document.querySelectorAll("table")).filter(function(table) {
      return !elementSubtreeHidden(table) && !table.closest("article, [itemprop='articleBody'], blockquote, pre, code, nav, footer, aside, form, dialog, [role='dialog']");
    });
  }

  function tableSocialRows(table) {
    return Array.from(table.querySelectorAll("tr")).filter(function(row) {
      return row.closest("table") === table && !row.closest("thead, tfoot") && !elementSubtreeHidden(row);
    });
  }

  function tableSocialIndent(row) {
    var declared = row.getAttribute("aria-level") || row.getAttribute("data-depth") || row.getAttribute("data-level");
    if (declared !== null && declared !== "" && isFinite(Number(declared)) && Number(declared) >= 0) {
      return { value: Number(declared), explicit: true };
    }
    var cell = row.cells && row.cells[0];
    if (!cell || normalizeText(cell.textContent)) return null;
    var image = cell.querySelector("img[width]");
    if (!image || (image.getAttribute("src") && image.getAttribute("height") !== "1" && image.naturalHeight !== 1)) return null;
    var width = Number(image.getAttribute("width"));
    return isFinite(width) && width >= 0 ? { value: width, explicit: false } : null;
  }
