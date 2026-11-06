# frozen_string_literal: true

require 'gstreamer_play'

require_relative 'paths'

module SolanumRb
  # The beep on start and the chime on lap change, through GstPlay — the same
  # library upstream uses, via the `gstreamer_play` gem.
  #
  # Audio is the one thing a headless test cannot confirm, so a missing sink
  # or a missing decoder must not take the timer down with it: playback
  # failures are reported on stderr and otherwise ignored.
  class Sound
    BEEP = 'beep.ogg'
    CHIME = 'chime.ogg'

    attr_reader :player

    def initialize
      @player = build_play
    end

    def play(name)
      case player
      when nil then nil
      else restart(name)
      end
    end

    # GstPlay only re-reads its `uri` from a stopped state, so a second play
    # of the same file is silent without the stop first.
    def restart(name)
      player.stop
      player.uri = "file://#{Paths.sound(name)}"
      player.play
    rescue StandardError => e
      warn("solanum-rb: could not play #{name}: #{e.message}")
    end

    # Built once, so a broken GStreamer is diagnosed at startup rather than on
    # every lap.
    def build_play
      GstPlay::Play.new
    rescue StandardError => e
      warn("solanum-rb: no audio, GStreamer did not start: #{e.message}")
      nil
    end
  end
end
