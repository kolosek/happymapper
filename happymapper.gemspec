# -*- encoding: utf-8 -*-
# stub: happymapper 0.4.1 ruby lib

Gem::Specification.new do |s|
  s.name = "happymapper"
  s.version = "0.4.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["John Nunemaker"]
  s.date = "2017-03-30"
  s.email = ["nunemaker@gmail.com"]
  s.files = ["License", "README.rdoc", "Rakefile", "examples/amazon.rb", "examples/current_weather.rb", "examples/dashed_elements.rb", "examples/multi_street_address.rb", "examples/post.rb", "examples/twitter.rb", "lib/happymapper", "lib/happymapper.rb", "lib/happymapper/attribute.rb", "lib/happymapper/element.rb", "lib/happymapper/item.rb", "lib/happymapper/supported_types.rb", "lib/happymapper/version.rb", "spec/fixtures", "spec/fixtures/address.xml", "spec/fixtures/analytics.xml", "spec/fixtures/commit.xml", "spec/fixtures/current_weather.xml", "spec/fixtures/family_tree.xml", "spec/fixtures/intrade.xml", "spec/fixtures/multi_street_address.xml", "spec/fixtures/multiple_namespaces.xml", "spec/fixtures/nested_namespaces.xml", "spec/fixtures/notes.xml", "spec/fixtures/pita.xml", "spec/fixtures/posts.xml", "spec/fixtures/product_default_namespace.xml", "spec/fixtures/product_no_namespace.xml", "spec/fixtures/product_single_namespace.xml", "spec/fixtures/radar.xml", "spec/fixtures/statuses.xml", "spec/happymapper_attribute_spec.rb", "spec/happymapper_element_spec.rb", "spec/happymapper_item_spec.rb", "spec/happymapper_spec.rb", "spec/happymapper_to_xml_namespaces_spec.rb", "spec/happymapper_to_xml_spec.rb", "spec/spec.opts", "spec/spec_helper.rb", "spec/support", "spec/support/models.rb"]
  s.homepage = "http://happymapper.rubyforge.org"
  s.rubyforge_project = "happymapper"
  s.rubygems_version = "2.4.8"
  s.summary = "object to xml mapping library"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<libxml-ruby>, ["~> 2.0"])
    else
      s.add_dependency(%q<libxml-ruby>, ["~> 2.0"])
    end
  else
    s.add_dependency(%q<libxml-ruby>, ["~> 2.0"])
  end
end
