# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'i18n'

module SolanumRb
  # The about window, with the credits, links and acknowledgements upstream
  # lists.
  #
  # Upstream builds it with `adw_about_window_new_from_appdata`, which reads
  # the metainfo out of a GResource. There is no GResource here, so the few
  # fields it would have lifted are set directly.
  class AboutDialog
    include I18n

    APP_ID = 'org.gnome.Solanum.Rb'
    VERSION = '6.0.0'
    COPYRIGHT_YEAR = '2020-2024'
    DEVELOPERS = ['Christopher Davis <christopherdavis@gnome.org>'].freeze

    def build
      dialog.tap do |dlg|
        credit_translators(dlg)

        dlg.add_link(_('_Donate on Patreon'), 'https://www.patreon.com/chrisgnome')
        dlg.add_link(_('_Sponsor on GitHub'), 'https://github.com/sponsors/BrainBlasted/')

        dlg.add_credit_section(
          _('Icon by'),
          ['Tobias Bernard https://tobiasbernard.com'],
        )
        dlg.add_credit_section(
          _('Sound by'),
          ['Miredly Sound https://soundcloud.com/mired'],
        )

        dlg.add_acknowledgement_section(
          _('Supported by'),
          ['Willo Vincent', 'Sage Rosen', 'refi64', 'Patrons and GitHub Sponsors'],
        )
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
        dlg.application_name = _('Solanum')
        dlg.application_icon = APP_ID
        dlg.developer_name = 'Christopher Davis'
        dlg.version = VERSION
        dlg.developers = DEVELOPERS
        dlg.copyright = "© #{COPYRIGHT_YEAR} Christopher Davis, et al."
        dlg.license_type = Gtk::License::GPL_3_0
        dlg.comments = _('Balance working time and break time')
        dlg.website = 'https://apps.gnome.org/Solanum'
        dlg.issue_url = 'https://gitlab.gnome.org/World/Solanum/-/issues'
      end
    end
  end
end
