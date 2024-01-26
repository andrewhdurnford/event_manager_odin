require 'csv'
require 'google/apis/civicinfo_v2'
require './secret.rb'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_number(number)
  if number.gsub(/\D/, '').length == 11 && number[0] == "1"
    return number.gsub(/\D/, '').chars.last(10).join
  else
    return "0000000000"
  end
end

def most_registered_time(regdate, reg_hours)
  # gives reg hour
  reg_hour = regdate.split[1].split(":")[0]

  #convert number to hour
  time_hash = { 1 => "1 AM", 2 => "2 AM", 3 => "3 AM", 4 => "4 AM", 5 => "5 AM", 6 => "6 AM",
  7 => "7 AM", 8 => "8 AM", 9 => "9 AM", 10 => "10 AM", 11 => "11 AM", 12 => "12 PM",
  13 => "1 PM", 14 => "2 PM", 15 => "3 PM", 16 => "4 PM", 17 => "5 PM", 18 => "6 PM",
  19 => "7 PM", 20 => "8 PM", 21 => "9 PM", 22 => "10 PM", 23 => "11 PM", 24 => "12 AM"}

  # most common hour
  reg_hour = time_hash[reg_hour.to_i]
  if reg_hours.key?(reg_hour)
    reg_hours[reg_hour] += 1
  else
    reg_hours[reg_hour] = 1
  end
  reg_hours
end

def most_registered_day(regdate, reg_days)
  #convert number to day of week
  num_to_day = {0 => "Sunday", 1 => "Monday", 2 => "Tuesday", 3 => "Wednesday", 4 => "Thursday", 5 => "Friday", 6 => "Saturday"}

  #get reg date in proper form
  regdate = regdate.split[0].split("/")
  regdate = Date.new(("20" + regdate[2]).to_i, regdate[0].to_i, regdate[1].to_i).wday
  regdate = num_to_day[regdate]
  if reg_days.key?(regdate)
    reg_days[regdate] += 1
  else
    reg_days[regdate] = 1
  end
  reg_days
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = API_KEY

  begin
    legislators = civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
reg_hours = Hash.new(0)
reg_days = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]

  zipcode = clean_zipcode(row[:zipcode])

  phone = clean_number(row[:homephone])

  reg_hours = most_registered_time(row[:regdate], reg_hours)

  reg_days = most_registered_day(row[:regdate], reg_days)

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)
end

reg_hours = reg_hours.sort_by {|_key, value| value}.reverse!.to_h
most_registered_hour = reg_hours.keys.first

reg_days = reg_days.sort_by {|_key, value| value}.reverse!.to_h
most_registered_day = reg_days.keys.first

puts "The most registered hour was #{most_registered_hour}."
puts "The most registered day of the week was #{most_registered_day}."
