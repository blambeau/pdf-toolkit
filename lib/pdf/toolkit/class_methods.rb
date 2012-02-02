class PDF::Toolkit
  module ClassMethods

    def default_permissions
      @default_permissions ||= (superclass.default_permissions rescue [])
    end
    attr_writer :default_permissions

    def default_input_password
      @default_input_password ||= (superclass.default_input_password rescue nil)
    end
    attr_writer :default_input_password

    def default_owner_password
      @default_owner_password ||= (superclass.default_owner_password rescue nil)
    end
    attr_writer :default_owner_password
    protected   :default_owner_password=

    def default_user_password
      @default_user_password ||= (superclass.default_user_password rescue nil)
    end
    attr_writer :default_user_password
    protected   :default_user_password=

    def info_accessors
      @info_accessors ||= begin
        if superclass.respond_to?(:info_accessors)
          superclass.info_accessors.dup
        else
          Hash.new{|h,k|
            if h.has_key?(k.to_s.to_sym)
              h[k.to_s.to_sym]
            elsif k.kind_of?(Symbol)
              camelize_key(k)
            else
              k.dup
            end
          }
        end
      end
    end

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

    def camelize_key(key)
      if key.to_s.respond_to?(:camelize)
        key.to_s.camelize
      else
        key.to_s.gsub(/_+([^_])/) {$1.upcase}.sub(/^./) {|l|l.upcase}
      end
    end

  end # module ClassMethods
end # class PDF::Toolkit
