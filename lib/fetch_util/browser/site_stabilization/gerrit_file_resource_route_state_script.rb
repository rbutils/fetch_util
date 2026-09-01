# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GerritFileResourceRouteStateScript
        private

        def gerrit_file_resource_route_state_script
          <<~'JS'
            const stateKey = "__fetchUtilGerritFileResource";
            const pathname = (location.pathname || "").replace(/\/+$/, "");
            const marker = pathname.lastIndexOf('/+/');
            if (marker < 1) return { matched: false };

            const tail = pathname.slice(marker + 3).split("/");
            if (tail.length < 3 || !/^\d+$/.test(tail[0])) return { matched: false };
            const selector = tail[1];
            const comparison = selector.match(/^(-?[1-9]\d*|0)\.\.([1-9]\d*)$/);
            const targetOnly = selector.match(/^([1-9]\d*)$/);
            if (!comparison && !targetOnly) return { matched: false };

            const number = tail[0];
            const target = comparison ? comparison[2] : targetOnly[1];
            const base = comparison ? comparison[1] : null;
            const rawFilePath = tail.slice(2).join("/");
            let filePath;
            try { filePath = decodeURIComponent(rawFilePath); }
            catch (_error) { return { matched: false }; }
            const fileParts = filePath.split("/");
            const magicPath = fileParts[0] === "" && fileParts.length === 2 && fileParts[1];
            if (!filePath || fileParts.some((part, index) => !part && !(index === 0 && magicPath)) ||
                fileParts.some((part) => part === "." || part === "..")) return { matched: false };

            const beforeMarker = pathname.slice(0, marker);
            const baseNode = document.querySelector("base[href]");
            let prefix = "";
            if (baseNode) {
              try {
                const baseUrl = new URL(baseNode.getAttribute("href"), location.href);
                if (baseUrl.origin === location.origin) prefix = baseUrl.pathname.replace(/\/+$/, "");
              } catch (_error) { prefix = ""; }
            }

            let projectPath = beforeMarker;
            if (prefix && projectPath.indexOf(prefix + "/") === 0) {
              projectPath = projectPath.slice(prefix.length);
            }
            if (projectPath.indexOf("/c/") === 0) {
              projectPath = projectPath.slice(3);
            } else {
              const cMarker = projectPath.indexOf("/c/");
              if (cMarker >= 0) {
                prefix = projectPath.slice(0, cMarker);
                projectPath = projectPath.slice(cMarker + 3);
              } else {
                projectPath = projectPath.replace(/^\/+/, "");
              }
            }

            try { projectPath = decodeURIComponent(projectPath); }
            catch (_error) { return { matched: false }; }
            if (!projectPath || projectPath.split("/").some((part) => !part || part === "." || part === "..")) {
              return { matched: false };
            }
          JS
        end
      end
    end
  end
end
