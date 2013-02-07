require 'test_helper'

class AssetPipelineTest < MiniTest::Unit::TestCase
  include ActiveSupport::Testing::Isolation

  def config
    app.config
  end

  def setup
    super

    create_file "vendor/javascripts/ember-template-compiler.js", File.read(handlebars_path)
  end

  def test_ember_precompiler_is_not_compiled
    create_file "app/javascripts/foo.js", "one js file is needed"

    create_file "vendor/javascripts/ember-template-compiler.js", "PRECOMPILER"

    compile ; assert_file "site/application.js"

    content = read "site/application.js"
    refute_includes content, "PRECOMPILER"
  end

  def test_templates_are_loaded_on_ember
    create_file "app/templates/home.hbs", "Hello {{name}}!"

    compile ; assert_file "site/application.js"

    content = read "site/application.js"
    assert_match content, /Ember\.TEMPLATES\['.+'\]=/
  end

  def test_templates_are_compiled_at_runtime_in_development
    create_file "app/templates/home.hbs", "Hello {{name}}"

    compile :development ; assert_file "site/application.js"

    content = read "site/application.js"

    assert_match content, /Ember\.TEMPLATES\['.+'\]=Ember\.Handlebars\.compile\(.+\);/m
  end

  def test_handlbars_templates_are_precompiled_in_production
    create_file "app/templates/home.hbs", "Hello {{name}}"

    compile :production ; assert_file "site/application.js"

    content = read "site/application.js"

    assert_match content, /Ember\.TEMPLATES\['.+'\]=Ember\.Handlebars\.template\(.+\);/m
  end

  def test_inline_handlebars_templates_are_precompiled_in_production
    create_file "app/javascripts/view.js", <<-js
      App.MyView = Ember.View.extend({
        template: Ember.Handlebars.compile('Hello {{name}}')
      })
    js

    compile :production ; assert_file "site/application.js"

    content = read "site/application.js"

    assert_match content, /template:\sEmber\.Handlebars\.template\(.+\)[^;]/

    compiled_template = Iridium::Ember::HandlebarsPrecompiler.compile 'Hello {{name}}'

    assert_includes content, compiled_template, 
      "Template did not compile correctly!"
  end

  def test_inline_handles_with_em_namespace_are_compiled
    create_file "app/javascripts/view.js", <<-js
      App.MyView = Ember.View.extend({
        template: Em.Handlebars.compile('Hello {{name}}')
      })
    js

    compile :production ; assert_file "site/application.js"

    content = read "site/application.js"

    assert_match content, /template:\sEmber\.Handlebars\.template\(.+\)[^;]/

    compiled_template = Iridium::Ember::HandlebarsPrecompiler.compile 'Hello {{name}}'

    assert_includes content, compiled_template, 
      "Template did not compile correctly!"
  end

  def test_ember_asserts_are_stripped_in_production
    create_file "app/javascripts/ember.coffee", <<-coffee
      Ember.assert 'ember assertion'
    coffee

    compile :production ; assert_file "site/application.js"

    content = read "site/application.js"
    refute_includes content, 'ember assertion'
  end

  def test_ember_warning_are_stripped_in_production
    create_file "app/javascripts/ember.coffee", <<-coffee
      Ember.warn 'ember warning'
    coffee

    compile :production ; assert_file "site/application.js"

    content = read "site/application.js"
    refute_includes content, 'ember warning'
  end

  def test_ember_deprecations_are_stripped_in_production
    create_file "app/javascripts/ember.coffee", <<-coffee
      Ember.deprecate 'ember deprecation'
    coffee

    compile :production ; assert_file "site/application.js"

    content = read "site/application.js"
    refute_includes content, 'ember deprecartion'
  end

  def test_ember_debug_calls_are_stripped_in_production
    create_file "app/javascripts/ember.coffee", <<-coffee
      Ember.debug 'debugger!'
    coffee

    compile :production ; assert_file "site/application.js"

    content = read "site/application.js"
    refute_includes content, 'debugger!'
  end

  private
  def compile(env = "test")
    ENV['IRIDIUM_ENV'] = env.to_s
    instance = TestApp.new
    instance.boot!
    instance.compile
  ensure
    ENV['IRIDIUM_ENV'] = "test"
  end
end
