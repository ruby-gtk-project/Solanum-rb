# frozen_string_literal: true

require 'glib2'

module SolanumRb
  # The countdown. Upstream makes this a GObject with `countdown-update` and
  # `lap` signals; nothing outside the window ever connects to them, so here
  # they are two blocks handed in at construction.
  #
  # Pausing works by subtracting the elapsed time from the remaining duration,
  # so a resumed timer picks up where it stopped.
  class Timer
    TICK_MS = 100

    def initialize(on_countdown:, on_lap:)
      @on_countdown = on_countdown
      @on_lap = on_lap
      @running = false
      @started_at = nil
      @duration = 0
    end

    def running? = @running

    # In minutes, matching the settings keys and upstream's `set_duration`.
    def duration=(minutes)
      @started_at = now
      @duration = minutes * 60
    end

    # Seconds left. While stopped that is just the stored duration — `stop`
    # has already subtracted what ran, and `@started_at` is stale from then
    # on, so counting from it again would drain a paused timer.
    def remaining
      case @running
      when true then [@duration - elapsed, 0].max
      else @duration
      end
    end

    def start
      @running = true
      @started_at = now

      GLib::Timeout.add(TICK_MS) { tick }
    end

    def stop
      @running = false
      # Only shrink the duration: a timer stopped after it ran out would
      # otherwise wind itself backwards.
      @duration = [@duration - elapsed, 0].max
    end

    # One turn of the countdown. Returns whether to stay subscribed, which is
    # what GLib::Timeout wants back.
    def tick
      case @running
      when false then false
      else countdown
      end
    end

    def countdown
      remaining.positive?.tap do |ticking|
        case ticking
        when true then @on_countdown.call(*minutes_and_seconds(remaining))
        else @on_lap.call
        end
      end
    end

    def elapsed = now - @started_at

    # Truncating, so the label counts 25:00, 24:59, ... the way upstream's does.
    def minutes_and_seconds(seconds) = [seconds.to_i / 60, seconds.to_i % 60]

    # Monotonic: a clock change mid-session must not skip or stall the lap.
    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
