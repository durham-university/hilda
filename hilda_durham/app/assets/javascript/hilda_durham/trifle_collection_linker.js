$(function(){
  var setOptions=function(select, options){
    select.empty();
    select.append('<option value=""></option>');
    for(var i=0;i<options.length;i++){
      var option = $('<option></option>').attr('value',options[i].id).text(options[i].title);
      select.append(option);
    }
  };

  var selectedRootCollection=function(selector){
    var rootCollectionSelect = selector.find('.select_root_collection');
    if(rootCollectionSelect.val()=='') return null;
    return rootCollectionSelect.val();
  };
  var selectedSubCollection=function(selector){
    var subCollectionSelect = selector.find('.select_sub_collection');
    if(subCollectionSelect.length==0) return null;
    if(subCollectionSelect.val()=='') return null;
    return subCollectionSelect.val();
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

  var updateSubCollections=function(elem){
    var selector = elem.closest('.trifle_collection_selector');
    var subCollectionSelect = selector.find('.select_sub_collection');
    if(subCollectionSelect.length==0) return;
    var rootCollection = selectedRootCollection(selector);
    if(rootCollection==null) return;

    var form = selector.find('.trifle_collection_query');
    var formData = new FormData(form[0]);
    formData.append('ingestion_process[trifle_root_collection]',rootCollection);
    formData.append('ingestion_process[trifle_type]','sub_collection');

    sendQuery(form,formData,function(resp){
      setOptions(subCollectionSelect, resp.result);
    });
  };

  $('.module_graph').on('change','.trifle_collection_selector .select_root_collection',function(event) {
    updateSubCollections($(this));
  });
});
