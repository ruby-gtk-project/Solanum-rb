# frozen_string_literal: true

# Checks on the parts that need no widgets and no display: the countdown
# arithmetic and the PO catalogue.

require 'tmpdir'

require_relative '../lib/solanum_rb/appdata'
require_relative '../lib/solanum_rb/config'
require_relative '../lib/solanum_rb/i18n'
require_relative '../lib/solanum_rb/timer'

# A timer on a clock the test drives, so a 25-minute lap takes no time to
# check. `now` is public for exactly this.
class FakeClock < SolanumRb::Timer
  attr_accessor :clock

  def initialize(**kwargs)
    @clock = 0.0
    super
  end

  def now = @clock
end

$failures = []

def check(name)
  ok = yield
  puts(ok ? "    ok   #{name}" : "    FAIL #{name}")
  unless ok
    $failures << name
  end
rescue StandardError => e
  puts("    FAIL #{name} — #{e.class}: #{e.message}")
  $failures << name
end

def section(title)
  puts("[#{title}]")
  yield
end

def new_timer
  ticks = []
  laps = []
  timer = FakeClock.new(
    on_countdown: ->(min, sec) { ticks << [min, sec] },
    on_lap:       -> { laps << true },
  )
  [timer, ticks, laps]
end

section('the countdown') do
  timer, ticks, laps = new_timer
  timer.duration = 25

  check('a fresh timer is not running') { !timer.running? }
  check('25 minutes is 1500 seconds') { timer.remaining == 1500 }

  timer.start
  timer.clock = 0.1
  timer.tick
  check('the first tick reports 24:59, not 25:00') { ticks.last == [24, 59] }

  timer.clock = 60.0
  timer.tick
  check('a minute in reports 24:00') { ticks.last == [24, 0] }

  check('no lap yet') { laps.empty? }
  timer.clock = 1500.0
  check('the tick that runs out reports a lap') { timer.tick == false }
  check('the lap fired') { laps.length == 1 }
end

section('pausing') do
  timer, = new_timer
  timer.duration = 25
  timer.start

  timer.clock = 300.0
  timer.stop
  check('pausing keeps the remaining 20 minutes') { timer.remaining == 1200 }
  check('a paused timer is not running') { !timer.running? }
  check('a paused timer stops ticking') { timer.tick == false }

  timer.start
  timer.clock = 360.0
  timer.tick
  check('resuming counts from where it stopped') { timer.remaining == 1140 }
end

section('pausing past the end') do
  timer, = new_timer
  timer.duration = 1
  timer.start
  timer.clock = 120.0
  timer.stop
  check('an overrun timer does not wind backwards') { timer.remaining.zero? }
end

# gettext reads four variables; a test that sets only one would be answered by
# whichever of the others the shell happens to export.
def use_locale(name)
  %w[LANGUAGE LC_ALL LC_MESSAGES LANG].each { |var| ENV[var] = name }
  SolanumRb::I18n.reset!
end

section('the catalogue') do
  I = SolanumRb::I18n

  use_locale('fr')
  check('French is picked up') { I.language == 'fr' }
  check('a plain string translates') { I._('Lap Length') == 'Durée de cycle' }
  check('a plural entry translates through msgstr[0]') { I.f_('Lap {}', 3) == 'Cycle 3' }
  check('a contextual string translates') do
    I.p_('shortcut window', 'Show Preferences') == 'Afficher les préférences'
  end
  check('a multi-line msgstr joins up') do
    I._(
      'The length of each session type in minutes. Changes apply to the ' \
              'next session of each type.',
    ).start_with?('La durée de chaque')
  end
  check('an unknown string falls back') { I._('not in the catalogue') == 'not in the catalogue' }

  use_locale('de')
  check('switching locale reloads') { I.f_('Lap {}', 7) == 'Abschnitt 7' }

  use_locale('C')
  check('C means no translation') { I.language.nil? }
  check('and every string is its own msgid') { I._('Lap Length') == 'Lap Length' }

  use_locale('xx_YY')
  check('an unshipped locale falls back to nothing') { I.language.nil? }

  # A process with no usable locale still has to be able to read a UTF-8
  # catalogue: Ruby would otherwise open it as US-ASCII and raise on the
  # first accented character. This is what the nix build runs as.
  check('a catalogue reads under a C locale') do
    %w[LANGUAGE LC_ALL LC_MESSAGES LANG].each { |var| ENV.delete(var) }
    I.reset!
    I.parse_po(File.expand_path('../po/fr.po', __dir__))['Long Break'] == 'Pause longue'
  end

  # Leaving a bogus LC_ALL set makes every later subshell warn about it.
  use_locale('C')
end

# Upstream's -Dprofile switch. Both profiles have to be reachable from one
# process, so each check sets the variable itself.
def with_profile(value)
  ENV['SOLANUM_RB_PROFILE'] = value
  yield
ensure
  ENV.delete('SOLANUM_RB_PROFILE')
end

section('the build profile') do
  C = SolanumRb::Config

  with_profile(nil) do
    check('the default build is not a devel one') { !C.development? }
    check('and uses the plain application id') { C.app_id == 'org.gnome.Solanum.Rb' }
    check('with no name suffix') { C.name_suffix == '' }
    check('and the plain version') { C.version == '6.0.0' }
  end

  with_profile('development') do
    check('the devel build is one') { C.development? }
    check('and suffixes the application id') { C.app_id == 'org.gnome.Solanum.Rb.Devel' }
    check('and marks its name') { C.name_suffix == ' ☢' }
    check('and stamps the commit into the version') { C.version.start_with?('6.0.0-') }
  end

  check('the copyright year is upstream\'s, not this year') { C::COPYRIGHT == '2022' }

  # Both profiles' icons have to exist or the shell shows a blank tile.
  %w[org.gnome.Solanum.Rb org.gnome.Solanum.Rb.Devel].each do |id|
    check("#{id} has a scalable icon") do
      File.exist?("data/icons/hicolor/scalable/apps/#{id}.svg")
    end
    check("#{id} has a symbolic icon") do
      File.exist?("data/icons/hicolor/symbolic/apps/#{id}-symbolic.svg")
    end
  end
end

# These are what the about dialog shows; upstream lifts them out of the
# metainfo with adw_about_dialog_new_from_appdata.
section('the appdata reader') do
  appdata = SolanumRb::Appdata.new

  check('the generated metainfo is there') { appdata.available? }
  check('the name') { appdata.field(:name) == 'Solanum' }
  check('the summary') { appdata.field(:summary) == 'Balance working time and break time' }
  check('the licence') { appdata.field(:license) == 'GPL-3.0-or-later' }
  check('the developer') { appdata.field(:developer_name) == 'Christopher Davis' }
  check('the homepage') { appdata.url('homepage') == 'https://apps.gnome.org/Solanum' }
  check('the bugtracker') { appdata.url('bugtracker').include?('gitlab.gnome.org') }
  check('a url that is not there') { appdata.url('nonexistent').nil? }

  check('the description is flattened to one line') do
    appdata.description == 'Solanum is a time tracking app that uses the pomodoro ' \
                           'technique. Work in 4 sessions, with breaks in between each ' \
                           'session and one long break after all 4.'
  end

  check('the release notes for this version') do
    appdata.release_notes.to_s.include?("The timer's text now scales with window size")
  end
  check('an unknown version has no release notes') { appdata.release_notes('0.0.1').nil? }

  # The untranslated element must win over its xml:lang siblings — the locale
  # is applied by I18n, not by picking a translated element out of the file.
  check('a translated sibling is not picked up') do
    appdata.field(:summary) !~ /[^\x00-\x7F]/
  end
end

section('the generated desktop entry and metainfo') do
  desktop = File.read('build/generated/org.gnome.Solanum.Rb.desktop', encoding: 'UTF-8')
  metainfo = File.read('build/generated/org.gnome.Solanum.Rb.metainfo.xml', encoding: 'UTF-8')

  check('the application id is substituted') { desktop.include?('Icon=org.gnome.Solanum.Rb') }
  check('no placeholder survives in the desktop entry') { !desktop.include?('@') }
  check('no placeholder survives in the metainfo') { !metainfo.include?('@APP_ID@') }
  check('the name suffix is empty for a default build') do
    desktop.include?("\nName=Solanum\n")
  end
  check('keywords are localised') { desktop.include?('Keywords[fr]=Pomodoro;Minuteur;') }
  check('the summary is localised') { metainfo.include?('<summary xml:lang="de">') }
  check('the multi-line description is localised') do
    metainfo.include?('<p xml:lang="fr">Solanum est une application')
  end
  # Upstream's catalogues cover four appdata strings — the name, the summary,
  # the description and the developer's name — and not the release notes. A
  # sibling is only ever added where a translation exists, so the release
  # notes stay monolingual here too.
  check('release notes get no empty translations') { !metainfo.include?('<li xml:lang=') }
  check('the developer name is carried through untranslated') do
    metainfo.include?('<name xml:lang="fr">Christopher Davis</name>')
  end
  check('the launchable points at the desktop entry') do
    metainfo.include?('<launchable type="desktop-id">org.gnome.Solanum.Rb.desktop</launchable>')
  end
end

section('the stylesheet') do
  # Comments are stripped first: the file's header explains the change by
  # quoting the very syntax this check bans.
  css = File.read(File.expand_path('../data/style.css', __dir__), encoding: 'UTF-8')
            .gsub(%r{/\*.*?\*/}m, '')

  # GTK 4.22 cannot resolve a custom property inside @keyframes: it emits four
  # parser errors per animation frame, so the blinking countdown floods the
  # log. libadwaita's @-named colours are used instead.
  check('no var() custom properties') { !css.include?('var(') }
  check('the blink keyframes are still there') { css.include?('@keyframes blinkingText') }

  # Upstream writes this rule as `.main_box` while the window applies
  # `main-box`, so its padding has never taken effect.
  check('the padding rule matches the class the window applies') do
    css.include?('.main-box {') && !css.include?('.main_box {')
  end
end

puts
case $failures.empty?
when true
  puts('UNIT OK')
else
  puts("UNIT FAILED: #{$failures.length} — #{$failures.join(', ')}")
  exit(1)
end
