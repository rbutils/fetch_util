# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GerritChangeProductStateScript
        private

        def gerrit_change_product_state_script
          <<~'JS'
            const stateKey = "__fetchUtilGerritChange";
            const pathname = (location.pathname || "").replace(/\/+$/, "");
            const marker = pathname.lastIndexOf('/+/');
            if (marker < 1) return { matched: false };

            const tail = pathname.slice(marker + 3).split("/").filter(Boolean);
            if (tail.length < 1 || tail.length > 2 || !/^\d+$/.test(tail[0]) ||
                (tail[1] && !/^\d+$/.test(tail[1]))) return { matched: false };

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
            if (projectPath.indexOf("/c/") === 0) {
              projectPath = projectPath.slice(3);
            } else {
              const cMarker = projectPath.indexOf("/c/");
              if (cMarker >= 0) {
                prefix = projectPath.slice(0, cMarker);
                projectPath = projectPath.slice(cMarker + 3);
              } else {
                if (prefix && projectPath.indexOf(prefix + "/") === 0) projectPath = projectPath.slice(prefix.length);
                projectPath = projectPath.replace(/^\/+/, "");
              }
            }

            try { projectPath = decodeURIComponent(projectPath); }
            catch (_error) { return { matched: false }; }
            if (!projectPath || projectPath.split("/").some((part) => !part || part === "." || part === "..")) {
              return { matched: false };
            }

            const description = document.querySelector('meta[name="description"]');
            const descriptionMatch = /^Gerrit Code Review$/i.test((description && description.content || "").trim());
            const appMatch = !!document.querySelector("gr-app");
            const footerMatch = Array.from(document.querySelectorAll("footer, [role='contentinfo']")).some(
              (node) => /Powered by Gerrit Code Review/i.test((node.textContent || "").trim())
            );
            const assetMatch = Array.from(document.querySelectorAll("script[src], link[href]")).some((node) => {
              const value = node.getAttribute("src") || node.getAttribute("href") || "";
              if (!/\/polygerrit_ui\/.*\/gr-app\.js(?:$|[?#])/i.test(value)) return false;
              try { return new URL(value, location.href).origin === location.origin; } catch (_error) { return false; }
            });
            const preloadMatch = Array.from(document.querySelectorAll("link[href]")).some((node) => {
              const value = node.getAttribute("href") || "";
              if (!/\/changes\/[^/?]+\/(?:detail|comments)(?:$|[?])/i.test(value)) return false;
              try { return new URL(value, location.href).origin === location.origin; } catch (_error) { return false; }
            });
            const product = descriptionMatch && appMatch && (footerMatch || assetMatch || preloadMatch);
            if (!product) return { matched: true, product: false };

            const number = tail[0];
            const patchset = tail[1] || null;
            const changePath = beforeMarker + "/+/" + number;
            const apiPath = (prefix || "") + "/changes/" + encodeURIComponent(projectPath + "~" + number);
            const routeKey = [location.origin, changePath, patchset || ""].join(":");
            const existing = window[stateKey];
            if (existing && existing.routeKey === routeKey) {
              return {
                matched: true,
                product: true,
                status: existing.status || "",
                signature: [existing.status, existing.messageCount || 0, existing.commentCount || 0,
                  existing.fileCount || 0].join(":")
              };
            }

            const route = {
              project: projectPath,
              number: number,
              patchset: patchset,
              changePath: changePath,
              apiPath: apiPath
            };
          JS
        end
      end
    end
  end
end
