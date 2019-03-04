module HappyMapper
  class Item
    attr_accessor :name, :type, :tag, :options, :namespace
    
    Types = [String, Float, Time, Date, DateTime, Integer, Boolean]
    
    # options:
    #   :deep   =>  Boolean False to only parse element's children, True to include
    #               grandchildren and all others down the chain (// in expath)
    #   :namespace => String Element's namespace if it's not the global or inherited
    #                  default
    #   :parser =>  Symbol Class method to use for type coercion.
    #   :raw    =>  Boolean Use raw node value (inc. tags) when parsing.
    #   :single =>  Boolean False if object should be collection, True for single object
    #   :tag    =>  String Element name if it doesn't match the specified name.
    def initialize(name, type, o={})
      self.name = name.to_s
      self.type = type
      self.tag = o.delete(:tag) || name.to_s
      self.options = o
      
      @xml_type = self.class.to_s.split('::').last.downcase
    end
    
    def constant
      @constant ||= constantize(type)
    end
        
    def from_xml_node(node, namespace, xpath_options)

      namespace = options[:namespace] if options.key?(:namespace)

      if suported_type_registered?
        find(node, namespace, xpath_options) { |n| process_node_as_supported_type(n) }
      elsif constant == XmlContent
        find(node, namespace, xpath_options) { |n| process_node_as_xml_content(n) }
      elsif custom_parser_defined?
        find(node, namespace, xpath_options) { |n| process_node_with_custom_parser(n) }
      else
        process_node_with_default_parser(node,:namespaces => xpath_options)
      end

    end
    
    def xpath(namespace = self.namespace)
      xpath  = ''
      xpath += './/' if options[:deep]
      xpath += "#{DEFAULT_NS}:" if namespace
      xpath += tag
      # puts "xpath: #{xpath}"
      xpath
    end

    def custom_parser_defined?
      options[:parser]
    end
    
    def primitive?
      Types.include?(constant)
    end
    
    def element?
      @xml_type == 'element'
    end
    
    def attribute?
      !element?
    end
    
    def method_name
      @method_name ||= name.tr('-', '_')
    end
    
    def typecast(value)
      return value if value.kind_of?(constant) || value.nil?
      begin        
        if    constant == String    then value.to_s
        elsif constant == Float     then value.to_f
        elsif constant == Time      then Time.parse(value.to_s)
        elsif constant == Date      then Date.parse(value.to_s)
        elsif constant == DateTime  then DateTime.parse(value.to_s)
        elsif constant == Boolean   then ['true', 't', '1'].include?(value.to_s.downcase)
        elsif constant == Integer
          # ganked from datamapper
          value_to_i = value.to_i
          if value_to_i == 0 && value != '0'
            value_to_s = value.to_s
            begin
              Integer(value_to_s =~ /^(\d+)/ ? $1 : value_to_s)
            rescue ArgumentError
              nil
            end
          else
            value_to_i
          end
        else
          value
        end
      rescue
        value
      end
    end
    
    private

        def process_node_with_default_parser(node,parse_options)
          constant.parse(node,options.merge(parse_options))
        end

        def process_node_with_custom_parser(node)
          if node.respond_to?(:content) && !options[:raw]
            value = node.content
          else
            value = node.to_s
          end

          begin
            constant.send(options[:parser].to_sym, value)
          rescue
            nil
          end
        end

        def process_node_as_xml_content(node)
          node = node.children if node.respond_to?(:children)
          node.respond_to?(:to_xml) ? node.to_xml : node.to_s
        end

        def process_node_as_supported_type(node)
          content = node.respond_to?(:content) ? node.content : node
          typecast(content)
        end

        def suported_type_registered?
          SupportedTypes.types.map {|caster| caster.type }.include?(constant)
        end

      def constantize(type)
        if type.is_a?(String)
          names = type.split('::')
          constant = Object
          names.each do |name|
            constant =  constant.const_defined?(name) ? 
                          constant.const_get(name) : 
                          constant.const_missing(name)
          end
          constant
        else
          type
        end
      end

  end
end