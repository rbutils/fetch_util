# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module AzureDevopsPrProductStateScript
        private

        def azure_devops_pr_product_state_script
          <<~'JS'
            const stateKey = "__fetchUtilAzureDevopsPullRequest";
            const pathname = (location.pathname || "").replace(/\/+$/, "");
            const lowerPath = pathname.toLowerCase();
            const marker = lowerPath.lastIndexOf("/_git/");
            if (marker < 1) return { matched: false };

            const prefixPath = pathname.slice(0, marker);
            const tail = pathname.slice(marker + 6).split("/").filter(Boolean);
            if (tail.length !== 3 || tail[1].toLowerCase() !== "pullrequest" || !/^\d+$/.test(tail[2])) {
              return { matched: false };
            }

            const decodeSegment = (value) => {
              try { return decodeURIComponent(value); } catch (_error) { return ""; }
            };
            const repository = decodeSegment(tail[0]);
            const prefixParts = prefixPath.split("/").filter(Boolean).map(decodeSegment);
            if (!repository || repository === "." || repository === ".." || !prefixParts.length ||
                prefixParts.some((part) => !part || part === "." || part === "..")) return { matched: false };

            const number = tail[2];
            const project = prefixParts[prefixParts.length - 1];
            const basePath = prefixPath + "/_git/" + tail[0] + "/pullrequest/" + number;
            const bodyMatch = document.body && document.body.classList.contains("ms-vss-web-vsts-theme");
            const headingMatch = Array.from(document.querySelectorAll('[role="heading"], h1')).some(
              (node) => new RegExp("\\bPull Request\\s+" + number + "\\b", "i").test((node.textContent || "").trim())
            );
            const tabNames = ["overview", "files", "updates", "commits"];
            const tabsMatch = tabNames.every((name) => {
              const tab = document.querySelector("#__bolt-tab-" + name);
              if (!tab) return false;
              try {
                const url = new URL(tab.getAttribute("href"), location.href);
                return url.origin === location.origin && url.pathname === basePath && url.searchParams.get("_a") === name;
              } catch (_error) { return false; }
            });
            const moduleMatch = Array.from(document.scripts).some((script) =>
              /Repos\/Views\/PullRequest|Repos\/Discussion/.test(script.textContent || "")
            );
            const product = !!(bodyMatch && headingMatch && tabsMatch && moduleMatch);
            if (!product) return { matched: true, product: false };

            const apiPath = prefixPath + "/_apis/git/repositories/" + encodeURIComponent(repository) +
              "/pullRequests/" + number;
            const routeKey = [location.origin, basePath].join(":");
            const existing = window[stateKey];
            if (existing && existing.routeKey === routeKey) {
              return {
                matched: true,
                product: true,
                status: existing.status || "",
                signature: [existing.status, existing.threadCount || 0, existing.commentCount || 0,
                  existing.commitCount || 0].join(":")
              };
            }

            const route = {
              prefixPath: prefixPath,
              project: project,
              repository: repository,
              number: number,
              basePath: basePath,
              apiPath: apiPath
            };
          JS
        end
      end
    end
  end
end
