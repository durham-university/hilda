module Hilda::IngestionProcessesHelper
  def traverse_graph(graph,&block)
    buffer = ''.html_safe
    mods = graph.start_modules.reverse
    while mods.any? do
      mod = mods.pop
      mods.concat(graph.graph[mod].reverse)
      buffer << capture do block.call(mod) end
    end
    buffer
  end
  
  def graph_groups(graph)
    sorted_mods = []
    mods = graph.start_modules.reverse
    while mods.any? do
      mod = mods.pop
      sorted_mods << mod
      mods.concat(graph.graph[mod].reverse)
    end
    
    sorted_mods.group_by do |m| m.param_values[:module_group] end
  end

  def include_modules_support
    render('hilda/modules/modules_support')
  end

  def render_module(mod)
    template = mod.param_values.fetch(:template,'hilda/modules/default')
    capture do render(template, mod: mod) end
  end

  def render_module_controls(mod)
    template = mod.param_values.fetch(:controls_template,'hilda/modules/default_controls')
    capture do render(template, mod: mod) end
  end

  def render_module_log(mod)
    template = mod.param_values.fetch(:log_template,'hilda/modules/default_log')
    capture do render(template, mod: mod) end
  end

  def render_module_form(mod)
    template = mod.param_values.fetch(:form_template,'hilda/modules/default_form')
    capture do render(template, mod: mod) end
  end

  def render_module_params(mod,f,&block)
    by_group = (mod.param_defs || {}).map do |k,v| v.merge(key: k) end \
                                     .group_by do |x| x[:group] end


    safe_join( by_group.each.with_object([]).with_index do |((group,params),o),index|
      o << %Q|<li class="list-group-item">|.html_safe
      o << %Q|<h4 class="group_heading">#{html_escape(group)}</h4>|.html_safe if group.present?
      params.each_with_object(o) do |param,o|
        key = param[:key]
        if param[:template].present?
          o << capture do render(template, mod: mod, param: param, param_key: key) end
        else
          case param[:type]
          when :file
            o << capture do render('hilda/modules/file_upload', mod: mod, param: param, param_key: key) end
          else
            options = {
              as: param[:type], 
              label: param[:label], 
              input_html: { class: 'form-control', onchange: 'moduleDataChanged(this)', value: mod.param_values.try(:[],key) || param[:default] }
            }
            options[:disabled] = 'true' unless mod.can_receive_params?
            options[:hint] = param[:note] if param[:note].present?
            if [:select, :radio_buttons, :check_boxes].include?(param[:type])
              options[:collection] = param[:collection]
              options[:selected] = options[:input_html].delete(:value)
            end
            o << %Q|<div class="form-group">|.html_safe
            o << f.input(key, options)
            o << %Q|</div>|.html_safe
          end
        end
      end

      o << capture do block.call end if block_given? && index == by_group.length-1

      o << %Q|</li>|.html_safe
    end)
  end

  def render_module_info(mod)
    template = mod.param_values.fetch(:info_template,nil)
    if template
      capture do render(template, mod: mod) end
    else
      ''
    end
  end

  def module_title(mod)
    mod.module_name.split('/').last.titleize
  end

  def render_module_run_status(mod)
    %Q|<div class="module_status #{html_escape mod.run_status}">
        #{html_escape mod.run_status}
       </div>|.html_safe
  end
end
