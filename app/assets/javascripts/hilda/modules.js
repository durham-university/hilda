function init_modules_ajax() {
  var ajax_manager = (function(){
    var requests = [];
    var waiting_for_response = 0;
    var timeout_id = 0;
    var poll_action = $("#modules_poll_form").attr('action');
    var last_change = -1;
    return {
      isGraphRunning: function(){
        if(!this.isOnGraphPage()) return false;
        return $('.module_graph').hasClass('graph_running') || $('.module_graph').hasClass('graph_queued');
      },
      isOnGraphPage: function(){
        return $('.module_graph').length>0;
      },
      updateModule: function(new_module_container){
        //console.log("updating module");
        var old_module_container = $('#'+new_module_container.attr('id'))
        old_module_container.replaceWith(new_module_container);
        new_module_container.trigger("hilda:module_replaced",[new_module_container]);
      },
      updateLastChange: function(){
        last_change = Math.max.apply(null, $('.module_container>.module_timestamp').map(function(){return parseInt($(this).text());}) );
      },
      handleResponse: function(resp){
        //console.log("got response");
        resp = $('<div>'+resp+'</div>');
        var _this = this;

        $('.module_graph').attr('class',resp.find('.module_graph').attr('class'));

        resp.find('.module_container').each(function(){
          var module_container = $(this);
          var change_time = parseInt(module_container.find('.module_timestamp').text());
          if(change_time>last_change) _this.updateModule(module_container);
        });
        this.updateLastChange()

        waiting_for_response--;

        if(requests.length>0 && waiting_for_response==0) this.sendNow();

        if(this.isGraphRunning() && !this.isRunning()) this.run();
      },
      handleFail: function(resp){
        alert("Error!  Status: " + resp.status);
        waiting_for_response--;
        if(requests.length>0 && waiting_for_response==0) this.sendNow();
      },
      sendForm: function(form){
        var req = {
            url: form.attr("action"),
            type: form.attr("method").toUpperCase(),
            data: new FormData(form[0]),
            processData: false,
            contentType: false,
            cache: false
        };
        if(form.attr('enctype')) req['enctype'] = form.attr('enctype');
        requests.push(req);
        if(!waiting_for_response) this.sendNow();
      },
      sendControlAction: function(button,action){
        var req = {
          url: button.attr('data-url'),
          type: 'POST',
          data: { no_layout: 'true' }
        }
        requests.push(req);
        if(!waiting_for_response) this.sendNow();
      },
      sendNow: function(){
        //console.log("sending form");
        waiting_for_response++;
        var req = requests.shift();
        var _this = this;
        req['success'] = function (resp) { _this.handleResponse(resp); };
        req['fail'] = function (resp) { _this.handleFail(resp); };
        $.ajax(req);
      },
      poll: function(){
        //console.log("polling");
        waiting_for_response++;
        var _this = this;
        $.ajax({
          url: poll_action,
          type: "GET",
          data: { no_layout: 'true' },
          success: function(resp) { _this.handleResponse(resp); },
          fail: function(resp) { _this.handleFail(resp); }
        });
      },
      run: function(){
        if(waiting_for_response == 0) this.poll();
        var _this = this;
        if(this.isGraphRunning()) {
          timeout_id = setTimeout(function(){ _this.run() }, 5000)
        }
        else {
          timeout_id = 0;
        }
      },
      isRunning: function(){
        return timeout_id>0;
      },
      stop: function(){
        clearTimeout(timeout_id);
        timeout_id=0;
      },
      start: function(){
        var _this = this;
        $(document).on('page:change', function(){ _this.pageChanged(); });
        this.updateLastChange();
        this.pageChanged();
      },
      pageChanged: function(){
        this.setSubmitHandlers();
        if(this.isGraphRunning() && !this.isRunning()) this.run();
      },
      setSubmitHandlers: function(){
        if(!this.isOnGraphPage()) return;
        var graph_elem = $(".module_graph");
        if(graph_elem.data('submit_handlers_set')) return;
        graph_elem.data('submit_handlers_set',true);
        var _this = this;

        var submitForm = function(event){
          event.preventDefault();
          if(_this.isGraphRunning()) return false;
          var button = $(this);
          var form = button.closest('form');
          if(button.hasClass('disabled')) { return false; }
          button.addClass('disabled');
          form.addClass('sending_data');

          _this.sendForm(form);

          form.find('input').attr('disabled','true');

          return false;
        };

        $(".module_graph").on('click',".module_container .module input[type='submit']", submitForm );
        $(".module_graph").on('click',".module_container .module button[type='submit']", submitForm );

        $(".module_graph").on('click',".module_container .module button.reset_module_button",function(event){
          if(_this.isGraphRunning()) return false;
          var button = $(this);
          if(button.hasClass('disabled')) { return false; }
          button.addClass('disabled');
          _this.sendControlAction(button,'reset');
        });

        $(".module_graph").on('click',".module_container .module button.start_module_button",function(event){
          if(_this.isGraphRunning()) return false;
          var button = $(this);
          if(button.hasClass('disabled')) { return false; }
          button.addClass('disabled');
          _this.sendControlAction(button,'start');
        });
      }
    };
  })();
  ajax_manager.start();

  hilda_modules_poll_change = function(){ ajax_manager.poll(); }

  dajax_manager = ajax_manager; // expose ajax_manager for debugging
}

$(function(){ init_modules_ajax() });