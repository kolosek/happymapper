require 'nokogiri'
require 'rubygems'
require 'date'
require 'time'
require 'xml'

class Boolean; end

module HappyMapper
  class XmlContent; end

  DEFAULT_NS = "happymapper"

  def self.included(base)
    base.instance_variable_set("@attributes", {})
    base.instance_variable_set("@elements", {})
    base.instance_variable_set("@registered_namespaces", {})
    
    base.extend ClassMethods
  end

  module ClassMethods
    def attribute(name, type, options={})
      attribute = Attribute.new(name, type, options)
      @attributes[to_s] ||= []
      @attributes[to_s] << attribute
      attr_accessor attribute.method_name.intern
    end

    def attributes
      @attributes[to_s] || []
    end

    def element(name, type, options={})
      element = Element.new(name, type, options)
      @elements[to_s] ||= []
      @elements[to_s] << element
      attr_accessor element.method_name.intern
    end

    def content(name)
      @content = name
      attr_accessor name
    end

    def after_parse_callbacks
      @after_parse_callbacks ||= []
    end

    def after_parse(&block)
      after_parse_callbacks.push(block)
    end

    def elements
      @elements[to_s] || []
    end

    def has_one(name, type, options={})
      element name, type, {:single => true}.merge(options)
    end

    def has_many(name, type, options={})
      element name, type, {:single => false}.merge(options)
    end

    # Specify a namespace if a node and all its children are all namespaced
    # elements. This is simpler than passing the :namespace option to each
    # defined element.
    def namespace(namespace = nil)
      @namespace = namespace if namespace
      @namespace
    end
    
    def register_namespace(namespace, ns)
      @registered_namespaces.merge!(namespace => ns)
    end

    def tag(new_tag_name)
      @tag_name = new_tag_name.to_s
    end

    def tag_name
      @tag_name ||= to_s.split('::')[-1].downcase
    end

    def nokogiri_config_callback
      @nokogiri_config_callback
    end

    def parse(xml, options = {})

      # create a local copy of the objects namespace value for this parse execution
      namespace = @namespace

      # If the XML specified is an Node then we have what we need.
      if xml.is_a?(Nokogiri::XML::Node) && !xml.is_a?(Nokogiri::XML::Document)
        node = xml
      else

        # If xml is an XML document select the root node of the document
        if xml.is_a?(Nokogiri::XML::Document)
          node = xml.root
        else

          # Attempt to parse the xml value with Nokogiri XML as a document
          # and select the root element
          xml = Nokogiri::XML(
            xml, nil, nil,
            Nokogiri::XML::ParseOptions::STRICT,
            &nokogiri_config_callback
          )
          node = xml.root
        end

        # if the node name is equal to the tag name then the we are parsing the
        # root element and that is important to record so that we can apply
        # the correct xpath on the elements of this document.

        root = node.nil? ? false : node.name == tag_name
      end

      # if any namespaces have been provied then we should capture those and then
      # merge them with any namespaces found on the xml node and merge all that
      # with any namespaces that have been registered on the object

      namespaces = options[:namespaces] || {}
      namespaces = namespaces.merge(xml.collect_namespaces) if xml.respond_to?(:collect_namespaces)
      namespaces = namespaces.merge(@registered_namespaces)

      # if a namespace has been provided then set the current namespace to it
      # or set the default namespace to the one defined under 'xmlns'
      # or set the default namespace to the namespace that matches 'happymapper's

      if options[:namespace]
        namespace = options[:namespace]
      elsif namespaces.has_key?("xmlns")
        namespace ||= DEFAULT_NS
        namespaces[DEFAULT_NS] = namespaces.delete("xmlns")
      elsif namespaces.has_key?(DEFAULT_NS)
        namespace ||= DEFAULT_NS
      end

      # from the options grab any nodes present and if none are present then
      # perform the following to find the nodes for the given class

      nodes = options.fetch(:nodes) do

        # when at the root use the xpath '/' otherwise use a more gready './/'
        # unless an xpath has been specified, which should overwrite default
        # and finally attach the current namespace if one has been defined
        #

        xpath  = (root ? '/' : './/')
        xpath  = options[:xpath].to_s.sub(/([^\/])$/, '\1/') if options[:xpath]
        xpath += "#{namespace}:" if namespace

        nodes = []

        # when finding nodes, do it in this order:
        # 1. specified tag if one has been provided
        # 2. name of element
        # 3. tag_name (derived from class name by default)

        # If a tag has been provided we need to search for it.

        if options.key?(:tag)
          begin
            nodes = node.xpath(xpath + options[:tag].to_s, namespaces)
          rescue
            # This exception takes place when the namespace is often not found
            # and we should continue on with the empty array of nodes.
          end
        else

          # This is the default case when no tag value is provided.
          # First we use the name of the element `items` in `has_many items`
          # Second we use the tag name which is the name of the class cleaned up

          [options[:name], tag_name].compact.each do |xpath_ext|
            begin
              nodes = node.xpath(xpath + xpath_ext.to_s, namespaces)
            rescue
              break
              # This exception takes place when the namespace is often not found
              # and we should continue with the empty array of nodes or keep looking
            end
            break if nodes && !nodes.empty?
          end

        end

        nodes
      end

      # Nothing matching found, we can go ahead and return
      return ( ( options[:single] || root ) ? nil : [] ) if nodes.size == 0

      # If the :limit option has been specified then we are going to slice
      # our node results by that amount to allow us the ability to deal with
      # a large result set of data.

      limit = options[:in_groups_of] || nodes.size

      # If the limit of 0 has been specified then the user obviously wants
      # none of the nodes that we are serving within this batch of nodes.

      return [] if limit == 0

      collection = []

      nodes.each_slice(limit) do |slice|

        part = slice.map do |n|

          # If an existing HappyMapper object is provided, update it with the
          # values from the xml being parsed.  Otherwise, create a new object

          obj = options[:update] ? options[:update] : new

          attributes.each do |attr|
            value = attr.from_xml_node(n, namespace, namespaces)
            value = attr.default if value.nil?
            obj.send("#{attr.method_name}=", value)
          end

          elements.each do |elem|
            obj.send("#{elem.method_name}=",elem.from_xml_node(n, namespace, namespaces))
          end

          if @content
            obj.send("#{@content.method_name}=",@content.from_xml_node(n, namespace, namespaces))
          end

          # If the HappyMapper class has the method #xml_value=,
          # attr_writer :xml_value, or attr_accessor :xml_value then we want to
          # assign the current xml that we just parsed to the xml_value

          if obj.respond_to?('xml_value=')
            n.namespaces.each {|name,path| n[name] = path }
            obj.xml_value = n.to_xml
          end

          # If the HappyMapper class has the method #xml_content=,
          # attr_write :xml_content, or attr_accessor :xml_content then we want to
          # assign the child xml that we just parsed to the xml_content

          if obj.respond_to?('xml_content=')
            n = n.children if n.respond_to?(:children)
            obj.xml_content = n.to_xml
          end

          # collect the object that we have created

          obj
        end

        # If a block has been provided and the user has requested that the objects
        # be handled in groups then we should yield the slice of the objects to them
        # otherwise continue to lump them together

        if block_given? and options[:in_groups_of]
          yield part
        else
          collection += part
        end

      end

      # per http://libxml.rubyforge.org/rdoc/classes/LibXML/XML/Document.html#M000354
      nodes = nil

      # If the :single option has been specified or we are at the root element
      # then we are going to return the first item in the collection. Otherwise
      # the return response is going to be an entire array of items.

      if options[:single] or root
        collection.first
      else
        collection
      end
    end


  end

  #
  # Create an xml representation of the specified class based on defined
  # HappyMapper elements and attributes. The method is defined in a way
  # that it can be called recursively by classes that are also HappyMapper
  # classes, allowg for the composition of classes.
  #
  def to_xml(parent_node = nil, default_namespace = nil)

    #
    # Create a tag that uses the tag name of the class that has no contents
    # but has the specified namespace or uses the default namespace
    #
    current_node = XML::Node.new(self.class.tag_name)


    if parent_node
      #
      # if #to_xml has been called with a parent_node that means this method
      # is being called recursively (or a special case) and we want to return
      # the parent_node with the new node as a child
      #
      parent_node << current_node
    else
      #
      # If #to_xml has been called without a Node (and namespace) that
      # means we want to return an xml document
      #
      write_out_to_xml = true
    end
    
    #
    # Add all the registered namespaces to the current node and the current node's
    # root element. Without adding it to the root element it is not possible to
    # parse or use xpath to find elements.
    #
    if self.class.instance_variable_get('@registered_namespaces')
      
      # Given a node, continue moving up to parents until there are no more parents
      find_root_node = lambda {|node| while node.parent? ; node = node.parent ; end ; node }
      root_node = find_root_node.call(current_node)
      
      # Add the registered namespace to the found root node only if it does not already have one defined
      self.class.instance_variable_get('@registered_namespaces').each_pair do |prefix,href|
        XML::Namespace.new(current_node,prefix,href)
        XML::Namespace.new(root_node,prefix,href) unless root_node.namespaces.find_by_prefix(prefix)
      end
    end

    #
    # Determine the tag namespace if one has been specified. This value takes
    # precendence over one that is handed down to composed sub-classes.
    #
    tag_namespace = current_node.namespaces.find_by_prefix(self.class.namespace) || default_namespace
    
    # Set the namespace of the current node to the specified namespace
    current_node.namespaces.namespace = tag_namespace if tag_namespace

    #
    # Add all the attribute tags to the current node with their namespace, if one
    # is defined, or the namespace handed down to the node.
    #
    self.class.attributes.each do |attribute|
      attribute_namespace = current_node.namespaces.find_by_prefix(attribute.options[:namespace]) || default_namespace
      
      value = send(attribute.method_name)

      #
      # If the attribute has a :on_save attribute defined that is a proc or
      # a defined method, then call those with the current value.
      #
      if on_save_operation = attribute.options[:on_save]
        if on_save_operation.is_a?(Proc)
          value = on_save_operation.call(value)
        elsif respond_to?(on_save_operation)
          value = send(on_save_operation,value)
        end
      end
      
      current_node[ "#{attribute_namespace ? "#{attribute_namespace.prefix}:" : ""}#{attribute.tag}" ] = value
    end

    #
    # All all the elements defined (e.g. has_one, has_many, element) ...
    #
    self.class.elements.each do |element|

      tag = element.tag || element.name
      
      element_namespace = current_node.namespaces.find_by_prefix(element.options[:namespace]) || tag_namespace
      
      value = send(element.name)

      #
      # If the element defines an :on_save lambda/proc then we will call that
      # operation on the specified value. This allows for operations to be 
      # performed to convert the value to a specific value to be saved to the xml.
      #
      if on_save_operation = element.options[:on_save]
        if on_save_operation.is_a?(Proc)
          value = on_save_operation.call(value)
        elsif respond_to?(on_save_operation)
          value = send(on_save_operation,value)
        end
      end

      #
      # Normally a nil value would be ignored, however if specified then
      # an empty element will be written to the xml
      #
      if value.nil? && element.options[:state_when_nil]
        current_node << XML::Node.new(tag,nil,element_namespace)
      end

      #
      # To allow for us to treat both groups of items and singular items
      # equally we wrap the value and treat it as an array.
      #
      if value.nil?
        values = []
      elsif value.respond_to?(:to_ary) && !element.options[:single]
        values = value.to_ary
      else
        values = [value]
      end


      values.each do |item|

        if item.is_a?(HappyMapper)

          #
          # Other HappyMapper items that are convertable should not be called
          # with the current node and the namespace defined for the element.
          #
          item.to_xml(current_node,element_namespace)

        elsif item

          #
          # When a value exists we should append the value for the tag
          #
          current_node << XML::Node.new(tag,item.to_s,element_namespace)

        else
          
          #
          # Normally a nil value would be ignored, however if specified then
          # an empty element will be written to the xml
          #
          current_node << XML.Node.new(tag,nil,element_namespace) if element.options[:state_when_nil]

        end

      end

    end


    #
    # Generate xml from a document if no node was passed as a parameter. Otherwise
    # this method is being called recursively (or special case) and we should
    # return the node with this node attached as a child.
    #
    if write_out_to_xml
      document = XML::Document.new
      document.root = current_node
      document.to_s
    else
      parent_node
    end

  end


end

require File.dirname(__FILE__) + '/happymapper/item'
require File.dirname(__FILE__) + '/happymapper/attribute'
require File.dirname(__FILE__) + '/happymapper/element'
require 'happymapper/supported_types'