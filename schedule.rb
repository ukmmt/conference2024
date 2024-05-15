#!/usr/bin/env ruby

# frozen_string_literal: true

require 'builder'
require 'ri_cal'
require 'uri'
require 'net/http'

def add_title_row(xml, title)
  xml.div(class: 'row') do
    xml.div(class: 'col-md-12') do
      xml.h3(title, class: 'section-title')
    end
  end
end

def display_time(d)
  d.strftime('%l:%M %p').strip
end

def std_time(d)
  d.xmlschema
end

def full_date(d)
  d.strftime('%A %B %-d, %Y')
end

def time_element(xml, dt)
  xml.time(display_time(dt), datetime: std_time(dt))
end

def pad_summary(summary)
  brs = summary.scan('<br/>').length
  return summary if brs >= 5

  summary + '&nbsp;<br/>' * (5 - brs)
end

def add_event(xml, event)
  xml.div(class: 'col-md-4 col-sm-6') do
    xml.div(class: 'schedule-box') do
      xml.div(class: 'panel-body') do
        xml.div(class: 'time') do
          time_element(xml, event[:from])
          xml << "&nbsp;-&nbsp;\n"
          time_element(xml, event[:to])
        end
        xml.h3 do
          xml << pad_summary(word_wrap(event[:summary]))
        end
        xml.p do
          xml << (event[:presenter].nil? ? '&nbsp;' : event[:presenter])
        end
      end
    end
  end
end

def add_schedule(xml, events)
  event_iter = events.each
  event = event_iter.next
  loop do
    current_date = event[:from].to_date
    add_title_row(xml, full_date(event[:from].to_date))
    xml.div(class: 'row') do
      while current_date == event[:from].to_date
        add_event(xml, event)
        event = event_iter.next
      end
    end
    add_title_row(xml, '')
  end
rescue StopIteration
  xml
end

def construct_schedules(feeds, indent)
  html = Builder::XmlMarkup.new(target: STDOUT, indent: indent)
  html.section(id: 'schedule', class: 'section schedule') do
    html.div(class: 'container') do
      add_title_row(html, 'Event Schedule')
      with_schedules(feeds) do |track, events|
        add_title_row(html, track)
        add_schedule(html, events)
      end
    end
  end
end

def word_wrap(text, line_width: 20, break_sequence: '<br/>')
  text.split("\n").collect! do |line|
    line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1#{break_sequence}").rstrip : line
  end * break_sequence
end

def with_schedules(feeds)
  feeds.each do |track, ical_feed_url|
    events = parse_ical_feed(ical_feed_url)
    yield track, events
  end
end

def print_schedules(feeds)
  with_schedules(feeds) do |track, events|
    puts track
    puts
    print_schedule(events)
    puts
  end
end

def print_schedule(events)
  event_iter = events.each
  event = event_iter.next
  loop do
    current_date = event[:from].to_date
    puts full_date(event[:from].to_date)
    while current_date == event[:from].to_date
      line = "#{event[:from].strftime('%R')}-#{event[:to].strftime('%R')}: #{event[:summary]}"
      line += " - #{event[:presenter].strip}" unless event[:presenter].to_s.strip.empty?
      line += ", #{event[:location]}"
      puts line
      event = event_iter.next
    end
    puts
  end
rescue StopIteration
  ''
end

def parse_ical_feed(feed_url)
  events = []

  # Parse the iCal feed
  cal = RiCal.parse_string(Net::HTTP.get(URI.parse(feed_url))).first

  # Iterate over each event
  cal.events.each do |event|
    # Extract relevant information from the event
    event_data = {
      summary: event.summary,
      presenter: event.description,
      location: event.location,
      from: event.start_time.new_offset('+01:00'),
      to: event.finish_time.new_offset('+01:00')
      # Add more fields as needed
    }

    # Add the event data to the list
    events << event_data
  end

  # Sort the events by start time
  events.sort_by! { |event| event[:from] }

  events
end

# Example usage:
ical_feeds = {
  'Primary Track' => 'https://calendar.google.com/calendar/ical/c_00c8190156cd77fb4fdd9aba637470d6ee5aef356b36bad76611c51b9a64a3dc%40group.calendar.google.com/public/basic.ics',
  'Secondary Track' => 'https://calendar.google.com/calendar/ical/c_86b903d65d79b9bd38f964569eb24aed6bc7d81aa980970a40c3dda123cec2b5%40group.calendar.google.com/public/basic.ics'
}
# print_schedules(ical_feeds)
construct_schedules(ical_feeds, 0)

