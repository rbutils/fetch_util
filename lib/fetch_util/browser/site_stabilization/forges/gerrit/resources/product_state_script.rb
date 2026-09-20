# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GerritFileResourceProductStateScript
        private

        def gerrit_file_resource_product_state_script
          gerrit_file_resource_route_state_script + <<~'JS'
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

            let comparisonKind = "implicit";
            let comparisonValue = null;
            if (base != null) {
              if (Number(base) > 0) {
                comparisonKind = "patchset";
                comparisonValue = base;
              } else if (Number(base) < 0) {
                comparisonKind = "parent";
                comparisonValue = String(Math.abs(Number(base)));
              } else {
                comparisonKind = "auto_merge";
              }
            }

            const changePath = beforeMarker + "/+/" + number;
            const apiPath = (prefix || "") + "/changes/" + encodeURIComponent(projectPath + "~" + number);
            const routeKey = [location.origin, changePath, selector, filePath].join(":");
            const existing = window[stateKey];
            if (existing && existing.routeKey === routeKey) {
              return {
                matched: true,
                product: true,
                status: existing.status || "",
                signature: [existing.status, existing.fileCount || 0, existing.commentCount || 0,
                  existing.diffBlockCount || 0, existing.firstParentDiffBlockCount || 0].join(":")
              };
            }

            const route = {
              project: projectPath,
              number: number,
              patchset: target,
              selector: selector,
              target: target,
              base: base,
              comparison: comparisonKind,
              comparisonValue: comparisonValue,
              filePath: filePath,
              changePath: changePath,
              apiPath: apiPath
            };
          JS
        end
      end
    end
  end
end
