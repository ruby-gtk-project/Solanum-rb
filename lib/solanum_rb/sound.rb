# frozen_string_literal: true

require 'gst'

require_relative 'paths'

module SolanumRb
  # The beep on start and the chime on lap change. Upstream uses GstPlay;
  # `playbin` is the same pipeline one layer down, and is what the `gstreamer`
  # gem exposes.
  #
  # Audio is the one thing a headless test cannot confirm, so a missing sink
  # or a missing decoder must not take the timer down with it: playback
  # failures are reported on stderr and otherwise ignored.
  class Sound
    BEEP = 'beep.ogg'
    CHIME = 'chime.ogg'

    attr_reader :playbin

    def initialize
      @playbin = build_playbin
    end

    def play(name)
      case playbin
      when nil then nil
      else restart(name)
      end
    end

    # `playbin` only re-reads its `uri` from the READY state, so a second play
    # of the same file is silent without the stop first.
    def restart(name)
      playbin.stop
      playbin.uri = "file://#{Paths.sound(name)}"
      playbin.play
    rescue StandardError => e
      warn("solanum-rb: could not play #{name}: #{e.message}")
    end

    # Built once, so a broken GStreamer is diagnosed at startup rather than on
    # every lap.
    def build_playbin
      Gst.init
      Gst::ElementFactory.make('playbin', 'solanum-sound')
    rescue StandardError => e
      warn("solanum-rb: no audio, GStreamer did not start: #{e.message}")
      nil
    end
  end
end
