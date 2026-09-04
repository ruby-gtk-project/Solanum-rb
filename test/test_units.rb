# frozen_string_literal: true

# Checks on the parts that need no widgets and no display: the countdown
# arithmetic and the PO catalogue.

require 'tmpdir'

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
end

section('the stylesheet') do
  # Comments are stripped first: the file's header explains the change by
  # quoting the very syntax this check bans.
  css = File.read(File.expand_path('../data/style.css', __dir__)).gsub(%r{/\*.*?\*/}m, '')

  # GTK 4.22 cannot resolve a custom property inside @keyframes: it emits four
  # parser errors per animation frame, so the blinking countdown floods the
  # log. libadwaita's @-named colours are used instead.
  check('no var() custom properties') { !css.include?('var(') }
  check('the blink keyframes are still there') { css.include?('@keyframes blinkingText') }
end

puts
case $failures.empty?
when true
  puts('UNIT OK')
else
  puts("UNIT FAILED: #{$failures.length} — #{$failures.join(', ')}")
  exit(1)
end
