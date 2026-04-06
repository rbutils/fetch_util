# frozen_string_literal: true

module FetchUtil
  class Regulatory
    module RobotGlobs
      private

      def robot_user_agent_glob(user_agent)
        token = user_agent.to_s.strip
        return "*" if token.empty? || token == "*"
        return token if token.end_with?("*")

        "#{token}*"
      end
    end
  end
end
