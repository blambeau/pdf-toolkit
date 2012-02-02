require 'tempfile'
require 'forwardable'

# Certain existing libraries have a PDF class; no sense in being unnecessarily
# incompatible.
module PDF #:nodoc:
end unless defined? PDF

# PDF::Toolkit can be used as a simple class, or derived from and tweaked.  The
# following two examples have identical results.
#
#   my_pdf = PDF::Toolkit.open("somefile.pdf")
#   my_pdf.updated_at = Time.now # ModDate
#   my_pdf["SomeAttribute"] = "Some value"
#   my_pdf.save!
#
#   class MyDocument < PDF::Toolkit
#     info_accessor :some_attribute
#     def before_save
#       self.updated_at = Time.now
#     end
#   end
#   my_pdf = MyDocument.open("somefile.pdf")
#   my_pdf.some_attribute = "Some value"
#   my_pdf.save!
#
# Note the use of a +before_save+ callback in the second example.  This is
# the only supported callback unless you use the experimental
# #loot_active_record class method.
#
# == Requirements
#
# PDF::Toolkit requires +pdftk+, which is available from
# http://www.accesspdf.com/pdftk.  For full functionality, also install
# +xpdf+ from http://www.foolabs.com/xpdf.  ActiveSupport (from Ruby on Rails)
# is also required but this dependency may be removed in the future.
#
# == Limitations
#
# Timestamps are written in UTF-16 by +pdftk+, which is not appropriately
# handled by +pdfinfo+.
#
# +pdftk+ requires the owner password, even for simply querying the document.
class PDF::Toolkit
  extend Forwardable

  VERSION = "0.5.0"

  # Raised when something fails with the toolkit
  class Error < ::StandardError; end

  # Raised when an invocation of `pdftk` fails under the cover
  class ExecutionError < Error
    attr_reader :command, :exit_status
    def initialize(msg = nil, cmd = nil, exit_status = nil)
      super(msg)
      @command = cmd
      @exit_status = exit_status
    end
  end

  # Raised when a .pdf file cannot be saved
  class FileNotSaved < Error; end

  class << self

    # Add an accessor for a key.  If the key is omitted, defaults to a
    # camelized version of the accessor (+foo_bar+ becomes +FooBar+).  The
    # example below illustrates the defaults.
    #
    #   class MyDocument < PDF::Toolkit
    #     info_accessor :created_at, "CreationDate"
    #     info_accessor :updated_at, "ModDate"
    #     info_accessor :author
    #     [:subject, :title, :keywords, :producer, :creator].each do |key|
    #       info_accessor key
    #     end
    #   end
    #
    #   MyDocument.open("document.pdf").created_at
    def info_accessor(accessor_name, info_key = nil)
      info_key ||= camelize_key(accessor_name)
      info_accessors[accessor_name] = info_key
      define_method accessor_name do
        self[info_key]
      end
      define_method "#{accessor_name}=" do |value|
        self[info_key] = value
      end
    end

    # Invoke +pdftk+ with the given arguments, plus +dont_ask+.  If :mode or
    # a block is given, IO::popen is called.  Otherwise, Kernel#system is
    # used.
    #
    #   result = PDF::Toolkit.pdftk(*%w(foo.pdf bar.pdf cat output baz.pdf))
    #   io = PDF::Toolkit.pdftk("foo.pdf","dump_data","output","-",:mode => 'r')
    #   PDF::Toolkit.pdftk("foo.pdf","dump_data","output","-") { |io| io.read }
    def pdftk(*args,&block)
      options = args.last.is_a?(Hash) ? args.pop : {}
      args << "dont_ask"
      args << options
      result = call_program(:pdftk,*args,&block)
      return block_given? ? $?.success? : result
    end

    # Invoke +pdftotext+.  If +outfile+ is omitted, returns an +IO+ object for
    # the output.
    def pdftotext(file,outfile = nil,&block)
      call_program(:pdftotext,file,
        outfile||"-",:mode => (outfile ? nil : 'r'),&block)
    end

    def info_accessors
      @info_accessors ||= Hash.new{|h,k|
        if h.has_key?(k.to_s.to_sym)
          h[k.to_s.to_sym]
        elsif k.kind_of?(Symbol)
          camelize_key(k)
        else
          k.dup
        end
      }
    end

    attr_accessor :default_permissions, :default_input_password
    attr_accessor :default_owner_password, :default_user_password
    protected :default_owner_password=, :default_user_password=

    private

    def instantiate(*args) #:nodoc:
      raise NoMethodError, "stub method `instantiate' called for #{self}:#{self.class}"
    end

    def call_program(*args,&block)
      old_stream = nil
      options = args.last.is_a?(Hash) ? args.pop : {}
      options[:mode] ||= 'r' if block_given?
      unless options[:silence_stderr] == false
        old_stream = STDERR.dup
        STDERR.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
        STDERR.sync = true
      end
      if options[:mode]
        command = (args.map{|arg| %{"#{arg.to_s.gsub('"','\\"')}"}}).join(" ")
        retval = IO.popen(command,options[:mode],&block)
        retval
      else
        system(*args)
      end
    ensure
      STDERR.reopen(old_stream) if old_stream
    end

    def camelize_key(key)
      if key.to_s.respond_to?(:camelize)
        key.to_s.camelize
      else
        key.to_s.gsub(/_+([^_])/) {$1.upcase}.sub(/^./) {|l|l.upcase}
      end
    end

  end

  info_accessor :created_at, "CreationDate"
  info_accessor :updated_at, "ModDate"
  [:author, :subject, :title, :keywords, :creator, :producer].each do |key|
    info_accessor key
  end

  # Create a new object associated with +filename+ and read in the
  # associated metadata.
  #
  #   my_pdf = PDF::Toolkit.open("document.pdf")
  def self.open(filename,input_password = nil)
    object = new(filename,input_password)
    object.reload
    object
  end

  # Like +open+, only the attributes are lazily loaded.  Under most
  # circumstances,  +open+ is preferred.
  def initialize(filename,input_password = nil)
    @filename = if filename.respond_to?(:to_str)
                  filename.to_str
                elsif filename.kind_of?(self.class)
                  filename.instance_variable_get("@filename")
                elsif filename.respond_to?(:path)
                  filename.path
                else
                  filename
                end
    @input_password = input_password || default_input_password
    @owner_password = default_owner_password
    @user_password  = default_user_password
    @permissions = default_permissions || []
    @new_info = {}
    callback(:after_initialize) if respond_to?(:after_initialize) && respond_to?(:callback)
    # reload
  end

  def_delegators :"self.class", :default_input_password,
                                :default_owner_password,
                                :default_user_password,
                                :default_permissions

  attr_reader :pdf_ids, :permissions
  attr_writer :owner_password, :user_password

  def page_count
    read_data unless @pages
    @pages
  end
  alias pages page_count

  # Path to the file.
  def path
    @new_filename || @filename
  end

  # Retrieve the file's version as a symbol.
  #
  #   my_pdf.version # => :"1.4"
  def version
    @version ||= File.open(@filename) do |io|
      io.read(8)[5..-1].to_sym
    end
  end

  # Reload (or load) the file's metadata.
  def reload
    @new_info = {}
    read_data
    # run_callbacks_for(:after_load)
    self
  end

  # Commit changes to the PDF.  The return value is a boolean reflecting the
  # success of the operation (This should always be true unless you're
  # utilizing #loot_active_record).
  def save
    create_or_update
  end

  # Like +save+, only raise an exception if the operation fails.
  #
  # TODO: ensure no ActiveRecord::RecordInvalid errors make it through.
  def save!
    if save
      self
    else
      raise FileNotSaved
    end
  end

  # Save to a different file.  A new object is returned if the operation
  # succeeded.  Otherwise, +nil+ is returned.
  def save_as(filename)
    dup.save_as!(filename)
  rescue FileNotSaved
    nil
  end

  # Save to a different file.  The existing object is modified.  An exception
  # is raised if the operation fails.
  def save_as!(filename)
    @new_filename = filename
    save!
    self
  rescue ActiveRecord::RecordInvalid
    raise FileNotSaved
  end

  # Invoke +pdftotext+ on the file and return an +IO+ object for reading the
  # results.
  #
  #   text = my_pdf.to_text.read
  def to_text(filename = nil,&block)
    self.class.send(:pdftotext,@filename,filename,&block)
  end

  def to_s #:nodoc:
    "#<#{self.class}:#{path}>"
  end

  # Create a hash from the file's metadata.
  def to_hash
    ensure_loaded
    @info.merge(@new_info).reject {|key,value| value.nil?}
  end

  def_delegators :to_hash, :each, :keys, :values, :each_key, :each_value, :each_pair, :merge
  include Enumerable

  def new_record? #:nodoc:
    !@new_filename.nil?
  end

  # Read a metadata attribute.
  #
  #   author = my_pdf["Author"]
  #
  # See +info_accessor+ for an alternate syntax.
  def [](key)
    key = lookup_key(key)
    return @new_info[key.to_s] if @new_info.has_key?(key.to_s)
    ensure_loaded
    @info[key.to_s]
  end

  # Write a metadata attribute.
  #
  #   my_pdf["Author"] = author
  #
  # See +info_accessor+ for an alternate syntax.
  def []=(key,value)
    key = lookup_key(key)
    @new_info[key.to_s] = value
  end

  def update_attribute(key,value)
    self[key] = value
    save
  end

  # True if the file has the given metadata attribute.
  def has_key?(value)
    ensure_loaded
    value = lookup_key(value)
    (@info.has_key?(value) || @new_info.has_key?(value)) && !!(self[value])
  end
  alias key? has_key?

  # Remove the metadata attribute from the file.
  def delete(key)
    key = lookup_key(key)
    if @info.has_key?(key) || !@pages
      @new_info[key] = nil
    else
      @new_info.delete(key)
    end
  end

  # Like +delete_if+, only nil is returned if no attributes were removed.
  def reject!(&block)
    ensure_loaded
    ret = nil
    each do |key,value|
      if yield(key,value)
        ret = self
        delete(key)
      end
    end
    ret
  end

  # Remove metadata if the given block returns false.  The following would
  # remove all timestamps.
  #
  #   my_pdf.delete_if {|key,value| value.kind_of?(Time)}
  def delete_if(&block)
    reject!(&block)
    self
  end

  # Add the specified attributes to the file.  If symbols are given as keys,
  # they are camelized.
  #
  # my_pdf.merge!("Author" => "Dave Thomas", :title => "Programming Ruby")
  def merge!(hash)
    hash.each do |k,v|
      @new_info[lookup_key(k)] = v
    end
    self
  end

  protected

  def read_attribute(key)
    self[key]
  end

  def write_attribute(key,value)
    self[key] = value
  end

  private

  # The password that will be used to decrypt the file.
  def input_password
    @input_password || @owner_password || @user_password
  end

  def lookup_key(key)
    return self.class.info_accessors[key]
  end

  def call_pdftk_on_file(*args,&block)
    options = args.last.is_a?(Hash) ? args.pop : {}
    args.unshift("input_pw",input_password) if input_password
    args.unshift(@filename)
    args << options
    self.class.send(:pdftk,*args,&block)
  end

  def cast_field(field)
    case field
    when /^D:(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)([-+].*)?$/
      parse_time(field)
    when /^\d+$/
      field.to_i
    else
      field
    end
  end

  def parse_time(string)
    if string =~ /^D:(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)([-+].*)?$/
      date = $~[1..6].map {|n|n.to_i}
      tz = $7
      time = Time.utc(*date)
      tz_match = tz.match(/^([+-])(\d{1,2})(?:'(\d\d)')?$/) if tz
      if tz_match
        direction, hours, minutes = tz_match[1..3]
        offset = (hours.to_i*60+minutes.to_i)*60
        # Go the *opposite* direction
        time += (offset == "+" ? -offset : offset)
      end
      time.getlocal
    else
      string
    end
  end

  def format_field(field)
    format_time(field)
  end

  def format_time(time)
    if time.kind_of?(Time)
      string = ("D:%04d"+"%02d"*5) % time.to_a[0..5].reverse
      string += (time.utc_offset < 0 ? "-" : "+")
      string += "%02d'%02d'" % [time.utc_offset.abs/3600,(time.utc_offset.abs/60)%60]
    else
      time
    end
  end

  def read_data
    last = nil
    bookmark_title, bookmark_level = nil, nil
    @info = {}
    @unknown_data = {}
    @pdf_ids = []
    @bookmarks = []
    unless File.readable?(@filename)
      raise ExecutionError, "File not found - #{@filename}"
    end
    retval = call_pdftk_on_file("dump_data","output","-", :mode => "r") do |pipe|
      pipe.each_line do |line|
        match = line.chomp.match(/(.*?): (.*)/)
        unless match
          raise ExecutionError, "Error parsing PDFTK output"
        end
        key, value = match[1], match[2]
        # key, value = line.chomp.split(/: /)
        case key
        when 'InfoKey'
          last = value
        when 'InfoValue'
          @info[last] = cast_field(value)
          last = nil
        when /^PdfID(\d+)$/
          @pdf_ids << value
        when /^PageLabel/
          # TODO
        when 'NumberOfPages'
          @pages = value.to_i
        when 'BookmarkTitle'
          bookmark_title = value
        when 'BookmarkLevel'
          bookmark_level = value.to_i
        when 'BookmarkPageNumber'
          unless bookmark_title && bookmark_level
            raise ExecutionError, "Error parsing PDFTK output"
          end
          @bookmarks << [bookmark_title, bookmark_level, value.to_i]
          bookmark_title, bookmark_level = nil, nil
        else
          @unknown_data[key] = value
        end
      end
    end
    if @info.empty? && !@pages || !retval
      raise ExecutionError.new("Error invoking PDFTK",nil,$?)
    end
    self
  end

  def write_info_to_file(out)
    # ensure_loaded
    raise Error, "No data to update PDF with" unless @new_info
    tmp = ( out == @filename ? "#{out}.#{$$}.new" : nil)
    args = ["update_info","-","output",tmp || out]
    args += [ "owner_pw", @owner_password ] if @owner_password
    args += [ "user_pw" , @user_password  ] if @user_password
    args += (["allow"] + @permissions.uniq ) if @permissions && !@permissions.empty?
    args << {:mode => "w"}
    # If a value is omitted, the old value is used.  If it is blank, it is
    # removed from the file.  Thus, it is not necessary to read the old
    # metadata in order to modify the file.
    retval = call_pdftk_on_file(*args) do |io|
      (@info || {}).merge(@new_info).each do |key,value|
        io.puts "InfoKey: #{key}"
        io.puts "InfoValue: #{format_field(value)}"
      end
    end
    if retval
      if tmp
        File.rename(tmp,out)
        tmp = nil
      end
    else
      raise ExecutionError.new("Error invoking PDFTK",nil,$?)
    end
    retval
  ensure
    File.unlink(tmp) if tmp && File.exists?(tmp)
  end

  def update
    if write_info_to_file(@filename)
      cleanup
      true
    end
  end

  def create
    if write_info_to_file(@new_filename)
      cleanup
      @filename = @new_filename
      @new_filename = nil
      true
    end
  end

  def create_or_update #:nodoc:
    run_callbacks_for(:before_save)
    result = new_record? ? create : update
    if result
      # run_callbacks_for(:after_save)
    end
    result
  end

  def respond_to_without_attributes?(method)
    respond_to?(method)
  end

  def destroy
    raise NoMethodError, "stub method `destroy' called for #{self}:#{self.class}"
    # File.unlink(@filename); self.freeze!
  end

  def cleanup
    if @info
      # Create a new hash on purpose
      @info = @info.merge(@new_info).reject {|key,value| value.nil?}
      @new_info = {}
    end
    @version = nil
    @input_password = nil
    self
  end

  def ensure_loaded
    unless @pages
      read_data
    end
    self
  end

  def run_callbacks_for(event,*args)
    send(event,*args) if respond_to?(event,true) && !respond_to?(:callback,true)
  end
end

#--
# vim:set tw=79:
