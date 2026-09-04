# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'appdata'
require_relative 'config'
require_relative 'i18n'

module SolanumRb
  # The about window, with the credits, links and acknowledgements upstream
  # lists.
  #
  # Upstream builds it with `adw_about_window_new_from_appdata`, which reads
  # the metainfo out of a GResource. There is no GResource here, so `Appdata`
  # reads the same generated metainfo off disk and the same fields are set
  # from it. Anything the metainfo does not carry — the credits, the two
  # funding links, the copyright line — is set explicitly, exactly as upstream
  # sets it after the `from_appdata` call.
  class AboutDialog
    include I18n

    DEVELOPERS = ['Christopher Davis <christopherdavis@gnome.org>'].freeze
    ICON_CREDITS = ['Tobias Bernard https://tobiasbernard.com'].freeze
    SOUND_CREDITS = ['Miredly Sound https://soundcloud.com/mired'].freeze
    SUPPORTERS = [
      'Willo Vincent',
      'Sage Rosen',
      'refi64',
      'Patrons and GitHub Sponsors',
    ].freeze

    def build
      dialog.tap do |dlg|
        credit_translators(dlg)

        dlg.add_link(_('_Donate on Patreon'), 'https://www.patreon.com/chrisgnome')
        dlg.add_link(_('_Sponsor on GitHub'), 'https://github.com/sponsors/BrainBlasted/')

        dlg.add_credit_section(_('Icon by'), ICON_CREDITS)
        dlg.add_credit_section(_('Sound by'), SOUND_CREDITS)
        dlg.add_acknowledgement_section(_('Supported by'), SUPPORTERS)
      end
    end

    def present(parent) = dialog.present(parent)

    # gettext's convention: an untranslated `translator-credits` means nobody
    # has claimed the locale, and the literal msgid must not be shown.
    def credit_translators(dlg)
      _('translator-credits').then do |credits|
        case credits
        when 'translator-credits' then nil
        else dlg.translator_credits = credits
        end
      end
    end

    def dialog
      @dialog ||= Adwaita::AboutDialog.new.tap do |dlg|
        dlg.application_icon = Config.app_id
        dlg.version = Config.version
        dlg.developers = DEVELOPERS
        dlg.copyright = "© #{Config::COPYRIGHT} Christopher Davis, et al."
        apply_appdata(dlg)
      end
    end

    # The fields upstream's `from_appdata` fills in. Each falls back to the
    # value upstream would have shown anyway, so a missing metainfo file — a
    # checkout where `rake desktop` has not run — degrades to a plainer
    # dialog rather than an empty one.
    def apply_appdata(dlg)
      dlg.application_name = appdata.field(:name) || _('Solanum')
      dlg.developer_name = appdata.field(:developer_name) || 'Christopher Davis'
      dlg.license_type = license_type
      dlg.comments = comments
      dlg.website = appdata.url('homepage') || 'https://apps.gnome.org/Solanum'
      dlg.issue_url = appdata.url('bugtracker') || ISSUE_URL
      apply_optional(dlg)
    end

    ISSUE_URL = 'https://gitlab.gnome.org/World/Solanum/-/issues'

    def apply_optional(dlg)
      appdata.url('help').then do |help|
        case help
        when nil then nil
        else dlg.support_url = help
        end
      end

      appdata.release_notes.then do |notes|
        case notes
        when nil then nil
        else set_release_notes(dlg, notes)
        end
      end
    end

    def set_release_notes(dlg, notes)
      dlg.release_notes = notes
      dlg.release_notes_version = Config::BASE_VERSION
    end

    # The description if the metainfo is there, the summary otherwise — the
    # summary is what the desktop and software centre already show.
    def comments
      appdata.description || appdata.field(:summary) ||
        _('Balance working time and break time')
    end

    # `<project_license>` is an SPDX expression; AdwAboutDialog wants a
    # GtkLicense. Only the licence this project actually ships is mapped, and
    # anything else falls through to the custom-licence value, which is what
    # AdwAboutDialog does with a `license` string it cannot classify.
    def license_type
      case appdata.field(:license)
      when 'GPL-3.0-or-later', nil then Gtk::License::GPL_3_0
      else Gtk::License::CUSTOM
      end
    end

    def appdata
      @appdata ||= Appdata.new.then do |data|
        case data.available?
        when true then data
        else NullAppdata.new
        end
      end
    end

    # Stands in when the metainfo has not been generated, so every reader
    # above takes its fallback instead of raising.
    class NullAppdata
      def field(_key) = nil
      def url(_type) = nil
      def description = nil
      def release_notes(_version = nil) = nil
    end
  end
end
