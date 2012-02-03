class PDF::Toolkit
  module Coercions

    ### From PDF to Ruby

    def cast_field(field)
      case field
      when /^D:(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)([-+].*)?/
        parse_time(field)
      when /^\d+$/
        field.to_i
      else
        field
      end
    end

    def parse_time(string)
      if string =~ /^D:(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)([-+].*)?/
        date = $~[1..6].map {|n|n.to_i}
        tz = $7
        time = Time.utc(*date)
        tz_match = tz.match(/^([+-])(\d{1,2})(?:'(\d\d)')?$/) if tz
        if tz_match
          direction, hours, minutes = tz_match[1..3]
          offset = (hours.to_i*60 + minutes.to_i)*60
          # Go the *opposite* direction
          time += (offset == "+" ? -offset : offset)
        end
        time
      else
        raise ArgumentError, "Unable to coerce `#{string}` to a Date"
      end
    end

    ### From Ruby to PDF

    def format_field(field)
      if field.kind_of?(Time)
        format_time(field)
      else
        field
      end
    end

    def format_time(time)
      string = ("D:%04d"+"%02d"*5) % time.to_a[0..5].reverse
      string += (time.utc_offset < 0 ? "-" : "+")
      string += "%02d'%02d'" % [time.utc_offset.abs/3600,(time.utc_offset.abs/60)%60]
    end

  end # module Casting
end # class PDF::Toolkit
