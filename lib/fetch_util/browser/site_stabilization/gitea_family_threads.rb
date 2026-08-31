# frozen_string_literal: true

module FetchUtil
  class Browser
    module SiteStabilization
      module GiteaFamilyThreads
        GITEA_FAMILY_THREAD_STABILIZATION_PROFILE = {
          host: true,
          path_query: ->(uri) { uri.path.match?(%r{/(?:[^/]+/){2}(?:issues|pulls)/\d+/?\z}) },
          strategy: :stabilize_gitea_family_thread,
          fallthrough: true,
          notes: "Wait for host-agnostic Gitea and Forgejo issue and pull-request conversations.",
          tests: "spec/fetch_util/browser_stabilization_spec.rb"
        }.freeze

        private

        def stabilize_gitea_family_thread(page)
          last_signature = nil
          stable_observations = 0
          incomplete_signature = nil
          incomplete_observations = 0
          terminal_incomplete = false
          observed = retry_until_timeout(capped_timeout(6.0), interval: 0.1) do
            state = safe_evaluate(
              page,
              gitea_family_thread_product_state_script + gitea_family_thread_timeline_state_script,
              default: nil
            )
            return false if state.is_a?(Hash) && state["product"] == false
            next false unless state.is_a?(Hash) && state["product"]

            unless state["ready"]
              if state["loading"]
                incomplete_signature = nil
                incomplete_observations = 0
              elsif state["signature"] == incomplete_signature
                incomplete_observations += 1
              else
                incomplete_signature = state["signature"]
                incomplete_observations = 1
              end
              if incomplete_observations >= 10
                terminal_incomplete = true
                next true
              end
              next false
            end

            incomplete_signature = nil
            incomplete_observations = 0
            if state["signature"] == last_signature
              stable_observations += 1
            else
              last_signature = state["signature"]
              stable_observations = 1
            end
            stable_observations >= 3
          end

          return false if terminal_incomplete

          settle_after_stabilization(0.5) if observed
          !!observed
        end
      end
    end
  end
end
