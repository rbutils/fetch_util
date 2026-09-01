# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module BitbucketCloudPullDiffRequestState
        private

        def bitbucket_cloud_pull_diff_request_state_script
          <<~'JS'
            const fetchUtilBitbucketDiffFetchJson = async (url) => {
              const response = await fetch(url, {
                credentials: 'same-origin',
                redirect: 'error',
                headers: { 'X-Requested-With': 'XMLHttpRequest', Accept: 'application/json' }
              });
              if (response.url && new URL(response.url, location.href).origin !== location.origin) {
                throw new Error('cross-origin Bitbucket API response');
              }
              if (!response.ok) throw new Error(`Bitbucket API returned HTTP ${response.status}`);
              const payload = await response.json();
              if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
                throw new Error('invalid Bitbucket API payload');
              }
              return payload;
            };

            const fetchUtilBitbucketDiffProxyUrl = (value, product) => {
              let parsed;
              try { parsed = new URL(value, product.metadataUrl); } catch (_error) { return null; }
              if (!/^https?:$/.test(parsed.protocol) || parsed.username || parsed.password) return null;
              const match = parsed.pathname.match(
                /^(?:\/!api)?\/2\.0\/repositories\/([^/]+)\/([^/]+)\/(pullrequests\/(\d+)\/diffstat|diffstat\/(.+))\/?$/
              );
              const decode = (item) => { try { return decodeURIComponent(item); } catch (_error) { return ''; } };
              if (!match || decode(match[1]).toLowerCase() !== product.route.workspace.toLowerCase() ||
                  decode(match[2]).toLowerCase() !== product.route.repository.toLowerCase()) return null;
              const pullRequestId = match[4] || parsed.searchParams.get('from_pullrequest_id');
              if (pullRequestId !== product.route.number) return null;
              const proxyPath = parsed.pathname.replace(/^(?:\/!api)?\/2\.0/, product.proxyPrefix);
              return location.origin + proxyPath + parsed.search;
            };

            const fetchUtilBitbucketDiffRecord = (record) => {
              if (!record || typeof record !== 'object' || Array.isArray(record)) return false;
              const oldPath = record.old && typeof record.old === 'object' && record.old.path;
              const newPath = record.new && typeof record.new === 'object' && record.new.path;
              return !!(String(oldPath || '').trim() || String(newPath || '').trim());
            };

            const fetchUtilBitbucketDiffRequest = async (product) => {
              const metadata = await fetchUtilBitbucketDiffFetchJson(product.metadataUrl);
              const repository = ((metadata.destination || {}).repository || {});
              if (String(metadata.id || '') !== product.route.number ||
                  String(repository.full_name || '').toLowerCase() !==
                    `${product.route.workspace}/${product.route.repository}`.toLowerCase()) {
                throw new Error('Bitbucket API pull request identity mismatch');
              }
              const firstUrl = fetchUtilBitbucketDiffProxyUrl(
                metadata.links && metadata.links.diffstat && metadata.links.diffstat.href,
                product
              );
              if (!firstUrl) throw new Error('missing trusted Bitbucket diffstat route');

              const records = [];
              const seen = new Set();
              let expectedCount = null;
              let pageUrl = firstUrl;
              while (pageUrl) {
                if (seen.has(pageUrl)) throw new Error('repeated Bitbucket diffstat continuation');
                seen.add(pageUrl);
                const page = await fetchUtilBitbucketDiffFetchJson(pageUrl);
                const hasSize = Object.prototype.hasOwnProperty.call(page, 'size');
                if (!Array.isArray(page.values) || (hasSize && (!Number.isInteger(page.size) || page.size < 0)) ||
                    (hasSize && expectedCount !== null && page.size !== expectedCount)) {
                  throw new Error('incomplete Bitbucket diffstat payload');
                }
                if (hasSize) expectedCount = page.size;
                if (!page.values.every(fetchUtilBitbucketDiffRecord)) {
                  throw new Error('invalid Bitbucket diffstat record');
                }
                records.push(...page.values);
                if (page.next) {
                  pageUrl = fetchUtilBitbucketDiffProxyUrl(page.next, product);
                  if (!pageUrl) throw new Error('untrusted Bitbucket diffstat continuation');
                } else {
                  pageUrl = null;
                }
              }
              if (expectedCount !== null && records.length !== expectedCount) {
                throw new Error('incomplete Bitbucket diffstat payload');
              }
              return { metadata, records };
            };
          JS
        end
      end
    end
  end
end
