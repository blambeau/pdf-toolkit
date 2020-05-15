class PDF::Toolkit
  module Native

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
      result = call_program("pdftk",*args,&block)
      return block_given? ? $?.success? : result
    end

    # Invoke +pdftotext+.  If +outfile+ is omitted, returns an +IO+ object for
    # the output.
    def pdftotext(file,outfile = nil,&block)
      call_program("pdftotext",file,
        outfile||"-",:mode => (outfile ? nil : 'r'),&block)
    end

    private

    def call_program(*args,&block)
      old_stream = nil
      options = args.last.is_a?(Hash) ? args.pop : {}
      options[:mode] ||= 'r' if block_given?
      unless options[:silence_stderr] == false
        old_stream = STDERR.dup
        STDERR.reopen(RUBY_PLATFORM =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
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

  end # module Native
end # class PDF::Toolkit
