# frozen_string_literal: true

require 'shellwords'

require_relative 'paths'

module SolanumRb
  # The build-time constants upstream generates into `config.rs` from meson.
  # There is no build step here, so the profile comes from the environment
  # instead of a meson option — `SOLANUM_RB_PROFILE=development` selects the
  # devel profile, exactly as `-Dprofile=development` does upstream.
  module Config
    BASE_ID = 'org.gnome.Solanum.Rb'
    BASE_VERSION = '6.0.0'
    # Upstream's `copyright` in meson.build. Not the current year: it is the
    # year the copyright line names.
    COPYRIGHT = '2022'

    module_function

    def development? = ENV.fetch('SOLANUM_RB_PROFILE', 'default') == 'development'

    # `.Devel` for a development build, empty otherwise. It is suffixed onto
    # the application id, and the window adds `devel` as a style class.
    def profile
      case development?
      when true then '.Devel'
      else ''
      end
    end

    def app_id = "#{BASE_ID}#{profile}"

    # Upstream's `name_suffix`, which marks a devel build's visible name.
    def name_suffix
      case development?
      when true then ' ☢'
      else ''
      end
    end

    # A devel build reports the commit it was run from, the way meson stamps
    # the short SHA into the version.
    def version = "#{BASE_VERSION}#{version_suffix}"

    def version_suffix
      case development?
      when true then "-#{vcs_tag}"
      else ''
      end
    end

    def vcs_tag
      @vcs_tag ||= read_vcs_tag
    end

    def read_vcs_tag
      `git -C #{__dir__.shellescape} rev-parse --short HEAD 2>/dev/null`.strip.then do |tag|
        case tag
        when '' then 'devel'
        else tag
        end
      end
    rescue StandardError
      'devel'
    end

    # Upstream's PKGDATADIR: where the sounds, icons and stylesheet live.
    def pkgdatadir = Paths.data_dir

    def localedir = Paths.po_dir

    # The generated metainfo for this profile. Upstream reads it out of the
    # GResource to build the about window; here it is a file on disk, written
    # by `rake desktop` and installed by the nix build.
    def metainfo_path = Paths.generated("#{app_id}.metainfo.xml")

    def desktop_path = Paths.generated("#{app_id}.desktop")
  end
end
