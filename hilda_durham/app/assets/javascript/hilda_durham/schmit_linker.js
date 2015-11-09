$(function(){
  var setOptions=function(select, options){
    select.empty();
    select.append('<option value=""></option>');
    for(var i=0;i<options.length;i++){
      var option = $('<option></option>').attr('value',options[i].id).text(options[i].title+" ("+options[i].public_id+")");
      select.append(option);
    }
  };

  var selectedRepository=function(selector){
    var repositorySelect = selector.find('.select_repository');
    if(repositorySelect.val()=='') return null;
    return repositorySelect.val();
  };
  var selectedFonds=function(selector){
    var fondsSelect = selector.find('.select_fonds');
    if(fondsSelect.length==0) return null;
    if(fondsSelect.val()=='') return null;
    return fondsSelect.val();
  };

  var sendQuery=function(form,formData,success){
    $.ajax({
      url: form.attr('action'),
      type: form.attr('method').toUpperCase(),
      data: formData,
      processData: false,
      contentType: false,
      cache: false,
      dataType: 'json',
      success: function(resp){
        if(resp.status != 'OK'){
          alert("ERROR! Status: " + resp.error_message);
          return;
        }
        else success(resp);
      },
      fail: function(resp){
        alert("Error!  Status: " + resp.status);
      }
    });
  };

  var updateFonds=function(elem){
    var selector = elem.closest('.schmit_selector');
    var fondsSelect = selector.find('.select_fonds');
    if(fondsSelect.length==0) return;
    var repository = selectedRepository(selector);
    if(repository==null) return;

    var form = selector.find('.schmit_query');
    var formData = new FormData(form[0]);
    formData.append('ingestion_process[schmit_repository]',repository);
    formData.append('ingestion_process[schmit_type]','fonds');

    sendQuery(form,formData,function(resp){
      setOptions(fondsSelect, resp.result);
    });
  };

  var updateCatalogue=function(elem){
    var selector = elem.closest('.schmit_selector');
    var catalogueSelect = selector.find('.select_catalogue');
    if(catalogueSelect.length==0) return;
    var repository = selectedRepository(selector);
    if(repository==null) return;
    var fonds = selectedFonds(selector);

    var form = selector.find('.schmit_query');
    var formData = new FormData(form[0]);
    formData.append('ingestion_process[schmit_repository]',repository);
    if(fonds!=null) formData.append('ingestion_process[schmit_fonds]',fonds);
    formData.append('ingestion_process[schmit_type]','catalogue');

    sendQuery(form,formData,function(resp){
      setOptions(catalogueSelect, resp.result);
    });
  };

  $('.module_graph').on('change','.schmit_selector .select_repository',function(event) {
    updateFonds($(this));
    updateCatalogue($(this));
  });
  $('.module_graph').on('change','.schmit_selector .select_fonds',function(event) {
    updateCatalogue($(this));
  });
});
