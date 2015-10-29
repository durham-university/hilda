require 'rsolr'

namespace :hilda do
  @template_counter = 0
  def new_template(title, key, description, exists_behaviour=:clean)
    if exists_behaviour==:clean
      Hilda::IngestionProcessTemplate.where(template_key: key).delete_all if key
    elsif exists_behaviour==:skip
      return if key && Hilda::IngestionProcessTemplate.where(template_key: key).any?
    elsif exists_behaviour==:error
      raise 'Template already exists' if key && Hilda::IngestionProcessTemplate.where(template_key: key).any?
    end
    template = Hilda::IngestionProcessTemplate.new(title: title, template_key: key, description: description, order_hint: @template_counter)
    @template_counter += 1
    yield template
    template.save
  end

  desc "create process templates"
  task "create_templates" => :environment do
    new_template('Test process','test','Testing process useful only in system development') do |template|
      template \
        .add_start_module(Hilda::Modules::FileReceiver) \
        .add_module(Hilda::Modules::FileMetadata, metadata_fields: {
          title: {label: 'Title', type: :string},
          test: {label: 'Test', type: :string}
         }) \
        .add_module(Hilda::Modules::DebugModule, sleep: 20 ) \
        .add_module(Hilda::Modules::Preservation) \
        .add_module(Hilda::Modules::DebugModule,
          param_defs: { test: {label: 'test param', type: :string, default: 'moo'} },
          info_template: 'hilda/modules/debug_info',
          sleep: 20 )
    end
  end
end
