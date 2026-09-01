# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module BitbucketCloudPullDiffState
        private

        def bitbucket_cloud_pull_diff_state_script
          <<~JS
            (() => {
              #{bitbucket_cloud_pull_diff_product_state_script}
              #{bitbucket_cloud_pull_diff_request_state_script}
              const product = fetchUtilBitbucketDiffProduct();
              if (!product.product) return { product: false, ready: false, loading: false, signature: '' };
              const routeKey = [product.route.workspace, product.route.repository, product.route.number].join(':');
              let prepared = window.__fetchUtilBitbucketPullDiff;
              if (!prepared || prepared.routeKey !== routeKey) {
                prepared = {
                  status: product.error ? 'failed' : 'loading',
                  reason: product.error || '', routeKey, route: product.route, metadata: null, values: []
                };
                window.__fetchUtilBitbucketPullDiff = prepared;
                if (!product.error) {
                  fetchUtilBitbucketDiffRequest(product).then((result) => {
                    Object.assign(prepared, {
                      status: 'ready', reason: '', metadata: result.metadata, values: result.records
                    });
                  }).catch((error) => {
                    prepared.status = 'failed';
                    prepared.reason = String(error && error.message || error || 'Bitbucket diffstat preparation failed');
                  });
                }
              }
              const loading = prepared.status === 'loading';
              const ready = prepared.status === 'ready' || prepared.status === 'failed';
              const signature = [prepared.status, prepared.reason || '', prepared.values.length].join(':');
              return { product: true, ready, loading, signature };
            })()
          JS
        end

        def fail_bitbucket_cloud_pull_diff_preparation(page)
          safe_evaluate(page, <<~'JS', default: false)
            (() => {
              const prepared = window.__fetchUtilBitbucketPullDiff;
              if (!prepared || prepared.status !== 'loading') return false;
              prepared.status = 'failed';
              prepared.reason = 'Bitbucket diffstat preparation timed out';
              return true;
            })()
          JS
        end
      end
    end
  end
end
