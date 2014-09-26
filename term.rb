#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "curses"

include Curses

Curses.init_screen()
Curses.start_color()
Curses.raw()
Curses.noecho()
Curses.start_color()

Curses.init_pair(1, 8, COLOR_WHITE)
Curses.init_pair(2, 8, COLOR_CYAN)
Curses.init_pair(3, 8, COLOR_GREEN)
Curses.init_pair(4, 8, COLOR_RED)
Curses.init_pair(5, 8, COLOR_YELLOW)
Curses.init_pair(6, 8, COLOR_BLACK)
Curses.init_pair(7, COLOR_BLUE, COLOR_WHITE)
Curses.init_pair(8, COLOR_BLACK, COLOR_WHITE)

# This class is a common viewport.
# Method init() should be overridden by the child class
# in order drawing take the place
class Viewport
  def initialize(height, width, top, left)
    @width = width
    @height = height
    @content = Window.new(@height, @width, top, left)
    init()
  end

  def init()
  end

  def _text(text)
    @content.addstr(text)
  end

  def _center_text(text, y)
    @content.setpos(y, @width / 2 - text.length / 2)
    _text(text)
  end

  def _space()
    _text(" ")
  end

  def _fill()
    (0..@height).each do | line |
      @content.setpos(line, 0)
      _clr()
    end
  end

  def _separator()
    @content.attrset(color_pair(6)|A_STANDOUT|A_NORMAL)
    @content.addstr("  |  ")
  end


  def _clr()
    (0..@width - @content.curx).each do
      @content.addstr(" ")
    end
  end


  def get_char()
    refresh()
    return @content.getch
  end


  def refresh()
    @content.refresh()
  end

  def close()
    @content.close
  end

  def content()
    return @content
  end
end



# This class draws a status bar below the window terminal.
# Accepts all that stuff from the cucumber results.
class StatusBar < Viewport
  @@STEP_DONE = 0
  @@STEP_FAILED = 1
  @@STEP_PASSED = 2
  @@STEP_SKIPPED = 3

  def init()
    # XXX: replace with setters
    @steps_done = 0
    @steps_total = 0
    @steps_failed = 0
    @steps_skipped = 0
    @steps_passed = 0

    draw()
  end

  def draw()
    @content.setpos(0, 0)
    @content.attrset(color_pair(1)|A_STANDOUT|A_NORMAL)
    _space()
    _text("Steps:")
    _space()

    # Steps
    @content.attrset(color_pair(2)|A_STANDOUT|A_NORMAL)
    @content.addstr(@steps_done.to_s)
    @content.attrset(color_pair(1)|A_STANDOUT|A_NORMAL)
    _space()
    _text("of")
    _space()
    @content.attrset(color_pair(2)|A_STANDOUT|A_NORMAL)
    @content.addstr(@steps_total.to_s)

    # Failed
    @content.attrset(color_pair(1)|A_STANDOUT|A_NORMAL)
    _separator()
    _text("Failed:")
    _space()
    @content.attrset(color_pair(4)|A_STANDOUT|A_BOLD)
    @content.addstr(@steps_failed.to_s)

    # Skipped
    @content.attrset(color_pair(1)|A_STANDOUT|A_NORMAL)
    _separator()
    _text("Skipped:")
    _space()
    @content.attron(color_pair(5)|A_STANDOUT|A_BOLD)
    @content.addstr(@steps_skipped.to_s)

    # Passed
    @content.attrset(color_pair(1)|A_STANDOUT|A_NORMAL)
    _separator()
    _text("Passed:")
    _space()
    @content.attron(color_pair(3)|A_STANDOUT|A_BOLD)
    @content.addstr(@steps_passed.to_s)

    _clr()
    @content.noutrefresh()
  end

  def set_total_steps(steps)
    if @steps_total != steps
      @steps_passed = 0
      @steps_skipped = 0
      @steps_failed = 0
      @steps_done = 0
    end

    @steps_total = steps
    draw()
  end

  def inc_step(step_type)
    @steps_passed += 1
    case step_type
    when @@STEP_PASSED
      @steps_passed += 1
    when @@STEP_SKIPPED
      @steps_skipped += 1
    when @@STEP_FAILED
      @steps_failed += 1
    end
    @steps_done += 1
    draw()
  end

end


# This class is a main viewport that shows the whole progress
# of the scenarios executed.
class TrailWindow < Viewport
  def init()
    @data = []
    draw()
  end

  def draw()
    @content.refresh()
  end

  def data()
    return @data
  end

  def reload_content()
    @content.attrset(color_pair(8)|A_STANDOUT|A_NORMAL)
    _fill()
    idx = 0
    @content.scrollok(true)

    data_buff = @data
    if @data.length > @content.maxy()
      data_buff = @data.slice(@data.length - @content.maxy(), @data.length)
    end
    data_buff.each do |line|
      @content.setpos(idx, 0)
      @content.addstr(line)
      idx += 1
    end
    @content.refresh()
  end
end


# Message window
class PopupWindow < Viewport
  def initialize(term_height, term_width)
    @width = 30
    @height = 6
    @msg = ""
    @content = Window.new(@height, @width,
                          term_height / 2 - @height / 2,
                          term_width / 2 - @width / 2)
    @content.attrset(color_pair(7)|A_NORMAL)
  end

  def show(msg)
    @msg = msg
  end

  def draw()
    _fill()
    @content.setpos(1, 0)
    _clr()
    _center_text(@msg, 2)
    _center_text("[ OK ]", 4)
    @content.box("|", "-")
    @content.refresh()
    @content.getch()
    @content.close()
  end
end


class MenuWindow < Viewport
  @@ITEMS = {
    # Action index => [expected key, title, shown, disabled]
    1 => ["s", "Start", true, false],
    2 => ["t", "Stop", false, false],
    3 => ["h", "Help", true, false],
    4 => ["q", "Quit", true, false],
  }

  def init()
    draw()
  end

  def started(state)
    @@ITEMS[2][2] = state
    @@ITEMS[1][2] = !@@ITEMS[2][2]
    @@ITEMS[3][3] = state
    draw()
  end

  def started?()
    return @@ITEMS[2][2]
  end

  def _draw_item(key, title, disabled)
    @content.attrset(color_pair(disabled ? 6 : 2)|A_STANDOUT)
    @content.addstr(key)
    _text(":")
    @content.attrset(color_pair(disabled ? 6 : 1)|A_STANDOUT)
    @content.addstr(title)
    _space()
    _space()
  end

  def draw()
    @content.setpos(0, 0)
    @content.attrset(color_pair(1)|A_STANDOUT|A_NORMAL)
    _space()
    @@ITEMS.each do |action, item|
      key, title, available, disabled = item
      if available
          _draw_item(key, title, disabled)
      end
    end

    _clr()
  end
end


#
# Application container
#
class TermApp
  def initialize(term_width, term_height)
    # Terminal settings
    @term_width = term_width
    @term_height = term_height

    # Viewports
    @menu = MenuWindow.new(1, @term_width, 0, 0)
    @status = StatusBar.new(1, @term_width, @term_height - 1, 0)
    @trail = TrailWindow.new(@term_height - 2, @term_width, 1, 0)
  end

  def set_total_steps(steps)
    @status.set_total_steps(steps)
    @status.inc_step(0)
    @menu.started(false)
  end

  def inc_step(step)
    @status.inc_step(step)
  end

  def console(line)
    @trail.data().push(line)
    @trail.reload_content()
  end

  def do_help()
    PopupWindow.new(@term_height, @term_width).show("Help you yourself. :)")
    @trail.reload_content()
  end

  def do_start()
    @menu.started(true)
  end

  def do_stop()
    @menu.started(false)
  end

  def do_finish()
    PopupWindow.new(@term_height, @term_width).show("Finished. Happy?")
    @trail.reload_content()
  end

  def run()
    while ch = @menu.get_char()
      case ch
      when "s"
        do_start()
      when "t"
        do_stop()
      when "h"
        do_help()
      when 'q'
        exit
      end
    end
  end
end
