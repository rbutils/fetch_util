# frozen_string_literal: true

module FetchUtil
  class PhaseObservation
    def initialize(url:, callback:, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @url = url.to_s.dup.freeze
      @request_id = object_id
      @callback = callback
      @clock = clock
    end

    DISABLED = new(url: nil, callback: nil, clock: nil).freeze

    def self.disabled
      DISABLED
    end

    def measure(phase, attempt: 1)
      return yield unless @callback

      started_at = @clock.call
      emit(phase, :start, nil, attempt, nil)
      outcome = :success
      error_class = nil
      begin
        yield
      rescue StandardError => e
        outcome = :error
        error_class = e.class.name.to_s.dup.freeze
        raise
      ensure
        emit(phase, :finish, @clock.call - started_at, attempt, outcome, error_class)
      end
    end

    private

    def emit(phase, edge, duration, attempt, outcome, error_class = nil)
      event = {
        url: @url,
        request_id: @request_id,
        phase: phase.to_sym,
        edge: edge,
        duration: duration,
        attempt: attempt,
        outcome: outcome,
        error_class: error_class
      }.freeze
      @callback.call(event)
    rescue StandardError
      nil
    end
  end

  private_constant :PhaseObservation
end
