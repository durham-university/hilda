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

  def include_modules_support
    render('hilda/modules/modules_support')
  end

  def render_module(mod)
    template = mod.param_values.fetch(:template,'hilda/modules/default')
    capture do render(template, mod: mod) end
  end

  def render_module_run_controls(mod)
    components = []

    components << %Q|
        <button type="button" class="btn btn-default reset_module_button" aria-label="Reset module"
                data-url="#{ingestion_process_module_reset_path(mod.module_graph,mod.module_name)}">
          <span class="glyphicon glyphicon-step-backward" aria-hidden="true"></span>
        </button>
      |.html_safe

    components << %Q|
        <button type="button" class="#{'disabled' unless mod.ready_to_run?} btn btn-default start_module_button" aria-label="Start module"
                data-url="#{ingestion_process_module_start_path(mod.module_graph,mod.module_name)}">
          <span class="glyphicon glyphicon-play" aria-hidden="true"></span>
        </button>
      |.html_safe

    safe_join components
  end

  def render_module_status(mod)
    template = mod.param_values.fetch(:status_template,'hilda/modules/default_status')
    capture do render(template, mod: mod) end
  end

  def render_module_form(mod)
    template = mod.param_values.fetch(:form_template,'hilda/modules/default_form')
    capture do render(template, mod: mod) end
  end

  def render_module_params(mod,f)
    disabled = (mod.run_status == :running) ? { disabled: 'true' } : {}
    safe_join( (mod.param_defs || {}).each_with_object([]) do |(key,param),o|
      case param[:type]
      when :file
        uploaded = mod.param_values.try(:[],key)
        o << f.input(key, as: :file, label: param[:label], input_html: disabled )
        o << %Q|<div class="form-group uploaded_file_info">Uploaded file: #{html_escape uploaded}</div>|.html_safe if uploaded
      else
        o << f.input(key, label: param[:label], input_html: { value: mod.param_values.try(:[],key) || param[:default] }.merge(disabled) )
      end
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

  def render_module_log(mod,last=5,errors_only=true)
    last = mod.log.size if last.nil? || last<0
    messages = mod.log
    if errors_only
      messages = messages.select do |message| message.level == :error || message.level == :warn end
    end
    messages = messages.last(last).each_with_object(''.html_safe) do |message,buffer|
      buffer << render_module_log_message(mod,message)
    end
    if messages.present?
      safe_join([
        %Q|<div class="module_log">
            <div class="module_log_info">Showing last #{last.to_i} #{'error ' if errors_only}messages</div>
            <table>|.html_safe,
            messages,
        %Q| </table>
           </div>|.html_safe])
   else
     ''
   end
  end

  def render_module_log_message(mod,message)
    safe_join([
      %Q|<tr class="#{html_escape message.level}">
          <td class="level">#{html_escape message.level}</td>
          <td class="time"></td>
          <td class="message">|.html_safe,
          message.message,
          render_module_log_exception(message.exception),
      %Q| </td>
       </tr>|.html_safe])
  end

  def render_module_log_exception(exception)
    return '' unless exception
    %Q|<div class="exception">#{safe_join exception.backtrace, '<br/>'}</div>|.html_safe
  end
end
