FactoryGirl.define do
  factory :module_graph, class: Hilda::ModuleGraph do
    trait :params do
      after(:build) do |graph|
        graph.add_start_module(Hilda::Modules::DebugModule, module_name: 'mod_a',
                param_defs: {
                  moo: {label: 'moo', type: :string },
                  baa: {label: 'baa', type: :string, default: 'baa' }
                }) \
            .add_module(Hilda::Modules::DebugModule, module_name: 'mod_b')
      end
    end

    trait :execution do
      #
      # mod_a -> mod_b -> mod_c
      #       -> mod_d -> mod_e -> mod_f
      # mod_g
      #
      # B and C not autorun
      #
      after(:build) do |graph|
        graph.add_start_module(Hilda::Modules::DebugModule, module_name: 'mod_a')
        graph.add_module(Hilda::Modules::DebugModule,'mod_a', module_name: 'mod_b', autorun: false)
        graph.add_module(Hilda::Modules::DebugModule,'mod_b', module_name: 'mod_c')
        graph.add_module(Hilda::Modules::DebugModule,'mod_a', module_name: 'mod_d')
        graph.add_module(Hilda::Modules::DebugModule,'mod_d', module_name: 'mod_e', autorun: false)
        graph.add_module(Hilda::Modules::DebugModule,'mod_e', module_name: 'mod_f')
        graph.add_start_module(Hilda::Modules::DebugModule, module_name: 'mod_g')
      end
    end
  end
end
