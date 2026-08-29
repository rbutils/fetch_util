  function tableIndexCells(row) {
    return Array.prototype.filter.call(row.children || [], function(cell) {
      return cell.matches && cell.matches("th, td");
    });
  }

  function tableIndexSpan(cell, propertyName, attributeName) {
    var value = parseInt(cell[propertyName] || cell.getAttribute(attributeName) || "1", 10);
    return value > 0 ? value : 1;
  }

  function tableIndexCellGrid(rows) {
    var grid = [];
    rows.forEach(function(row, rowIndex) {
      if (!grid[rowIndex]) grid[rowIndex] = [];
      var columnIndex = 0;
      tableIndexCells(row).forEach(function(cell) {
        while (grid[rowIndex][columnIndex]) columnIndex += 1;
        var colSpan = tableIndexSpan(cell, "colSpan", "colspan");
        var rowSpan = tableIndexSpan(cell, "rowSpan", "rowspan");
        for (var gridRow = rowIndex; gridRow < rowIndex + rowSpan; gridRow += 1) {
          if (!grid[gridRow]) grid[gridRow] = [];
          for (var gridColumn = columnIndex; gridColumn < columnIndex + colSpan; gridColumn += 1) {
            grid[gridRow][gridColumn] = cell;
          }
        }
        columnIndex += colSpan;
      });
    });
    return grid;
  }

  function tableIndexHeaders(table) {
    var rows = Array.prototype.filter.call(table.querySelectorAll("thead tr"), function(row) {
      var cells = tableIndexCells(row);
      return !elementVisuallyHidden(row) && cells.some(function(cell) { return cell.tagName === "TH"; });
    });
    if (!rows.length) {
      rows = Array.prototype.filter.call(table.querySelectorAll("tr"), function(row) {
        var cells = tableIndexCells(row);
        return !elementVisuallyHidden(row) && cells.length && cells.every(function(cell) { return cell.tagName === "TH"; });
      });
    }
    if (!rows.length) return [];

    var grid = tableIndexCellGrid(rows);
    var width = grid.reduce(function(maximum, row) { return Math.max(maximum, row.length); }, 0);
    var labels = [];
    for (var column = 0; column < width; column += 1) {
      var parts = [];
      rows.forEach(function(_row, rowIndex) {
        var label = normalizeText(((grid[rowIndex] || [])[column] || {}).textContent || "");
        if (label && parts[parts.length - 1] !== label) parts.push(label);
      });
      labels.push(parts.join(" / "));
    }
    return labels.filter(Boolean).length >= 2 ? labels : [];
  }

  function tableIndexDataRows(table) {
    var groups = [];
    Array.prototype.forEach.call(table.querySelectorAll("tr"), function(row) {
      if (row.closest("table") !== table || row.closest("thead, tfoot")) return;
      var group = groups[groups.length - 1];
      if (!group || group.parent !== row.parentElement) {
        group = { parent: row.parentElement, rows: [] };
        groups.push(group);
      }
      group.rows.push(row);
    });

    var dataRows = [];
    groups.forEach(function(group) {
      var grid = tableIndexCellGrid(group.rows);
      group.rows.forEach(function(row, rowIndex) {
        dataRows.push({ row: row, cells: grid[rowIndex] || [] });
      });
    });
    return dataRows;
  }

  function tableIndexCloneCellId(rowIndex, cellIndex) {
    return rowIndex + ":" + cellIndex;
  }

  function tableIndexAnnotateClone(source, clone) {
    if (!source || !clone || source.tagName !== "TABLE" || clone.tagName !== "TABLE") return false;
    var sourceRows = tableIndexDataRows(source);
    var cloneRows = tableIndexDataRows(clone);
    if (sourceRows.length !== cloneRows.length) return false;
    if (sourceRows.some(function(dataRow, rowIndex) {
      return tableIndexCells(dataRow.row).length !== tableIndexCells(cloneRows[rowIndex].row).length;
    })) return false;

    sourceRows.forEach(function(sourceDataRow, rowIndex) {
      var cloneRow = cloneRows[rowIndex].row;
      var cloneCells = tableIndexCells(cloneRow);
      cloneRow.setAttribute("data-fetchutil-table-row", String(rowIndex));
      tableIndexCells(sourceDataRow.row).forEach(function(_cell, cellIndex) {
        cloneCells[cellIndex].setAttribute("data-fetchutil-table-cell", tableIndexCloneCellId(rowIndex, cellIndex));
      });
    });
    return true;
  }

  function tableIndexMappedDataRows(source, clone) {
    var sourceRows = tableIndexDataRows(source);
    var sourceCellIds = new Map();
    sourceRows.forEach(function(dataRow, rowIndex) {
      tableIndexCells(dataRow.row).forEach(function(cell, cellIndex) {
        sourceCellIds.set(cell, tableIndexCloneCellId(rowIndex, cellIndex));
      });
    });

    var cloneCells = {};
    Array.prototype.forEach.call(clone.querySelectorAll("[data-fetchutil-table-cell]"), function(cell) {
      cloneCells[cell.getAttribute("data-fetchutil-table-cell")] = cell;
    });

    var valid = true;
    var mappedRows = tableIndexDataRows(clone).map(function(dataRow) {
      var rowIndex = parseInt(dataRow.row.getAttribute("data-fetchutil-table-row"), 10);
      var sourceDataRow = sourceRows[rowIndex];
      if (!sourceDataRow) {
        valid = false;
        return null;
      }

      return {
        row: dataRow.row,
        cells: sourceDataRow.cells.map(function(sourceCell) {
          return cloneCells[sourceCellIds.get(sourceCell)] || null;
        })
      };
    });
    return valid ? mappedRows : null;
  }

  function tableIndexClearCloneAnnotations(root) {
    Array.prototype.forEach.call(root.querySelectorAll("[data-fetchutil-table-row], [data-fetchutil-table-cell]"), function(node) {
      node.removeAttribute("data-fetchutil-table-row");
      node.removeAttribute("data-fetchutil-table-cell");
    });
  }
