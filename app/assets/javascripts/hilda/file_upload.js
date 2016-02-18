$(function(){
  var get_dropzone = function(elem){
    var uploader = elem.closest('.file_uploader');
    var dropzone = uploader.data('dropzone');
    if(!dropzone) return init_dropzone(uploader);
    return dropzone;
  };
  var get_uploader = function(dropzone){
    return $(dropzone.element).closest('.file_uploader');
  };

  var init_dropzone = function(uploader){
    var formTemplate = uploader.find('.form_template');

    var previewNode = uploader.find('.file_uploader_preview_template');
    previewNode.removeClass('file_uploader_preview_template');
    var previewTemplate = previewNode.parent().html();
    previewNode.detach();
    var actionButtons = uploader.find('.upload_action_buttons');
    if(actionButtons.length==0) return null;

    var dropzone = new Dropzone(actionButtons[0], {
      url: formTemplate.attr('action'),
      sending: function(event,xhr,formData){
        formData.append('authenticity_token', formTemplate.find("input[name='authenticity_token']").val());
        formData.append('ingestion_process[no_layout]','true');
        var md5=$(event.previewElement).data('md5') || '';
        formData.append("ingestion_process[md5s][]",md5);
      },
      method: "put",
      paramName: "ingestion_process[files]",
      parallelUploads: 10,
      uploadMultiple: true,
      previewTemplate: previewTemplate,
      autoQueue: false,
      previewsContainer: uploader.find('.file_uploader_previews_container')[0],
      clickable: ".fileinput-button"
    });

    dropzone.on("queuecomplete", function(progress) {
      hilda_modules_poll_change();
    });

    uploader.data('dropzone',dropzone);
    return dropzone;
  };
  
  var fileList = function(dropzone){
    // this includes both existing files and files about to be uploaded
    var uploader = get_uploader(dropzone);
    return $.makeArray(uploader.find('.file-row .name').map(function(){return $(this).text();}));
  };
  
  var sendFileList = function(dropzone, callback){
    console.log('sending file list')
    var uploader = get_uploader(dropzone);
    var formTemplate = uploader.find('.form_template');
    $.ajax({
      url: formTemplate.attr('action'),
      method: 'PUT',
      data: {
        "ingestion_process[file_names]": fileList(dropzone),
        'authenticity_token': formTemplate.find("input[name='authenticity_token']").val()
      },
      success: function(){
        console.log('file list success')
        callback();
      },
      error: function(xhr, textStatus) {
        console.log('file list error')
        alert("Error sending file list: "+textStatus);
      }
    });
  };

  var calculateMD5s = function(files,callback){
    getFileMD5s(files,function(status,result){
      if(status!='OK') {
        $(result.previewElement).find('.error').text('Error calculating MD5');
      }
      else {
        for(var i=0;i<files.length;i++){
          $(files[i].previewElement).data('md5',result[i]);
        }
        callback();
      }
    },function(file,pos,size,result){
      var status = 'Calculating MD5 '+(Math.floor(100.0*pos/size))+'%';
      if(result) status = 'MD5: '+result;
      $(file.previewElement).find('.md5').text(status);
    });
  };

  $('.module_graph').on('click','.file_uploader .upload_action_buttons .start',function(event) {
    event.preventDefault();
    var dropzone=get_dropzone($(this));
    sendFileList(dropzone,function(){
      console.log('calculating md5')
      var files = dropzone.getFilesWithStatus(Dropzone.ADDED);
      calculateMD5s(files,function(){
        console.log('sending files')
        dropzone.enqueueFiles(files);
      });      
    });
    return false;
  });
  $('.module_graph').on('click','.file_uploader .upload_action_buttons .cancel',function(event) {
    get_dropzone($(this)).removeAllFiles(true);
  });
  $('.module_graph').on('hilda:init_file_uploader','.file_uploader',function(event){
    get_dropzone($(this));
  });
  $('.module_graph').on('hilda:module_replaced','.module_container',function(event){
    $(this).find('.file_uploader').trigger("hilda:init_file_uploader")
  });
  $('.file_uploader').trigger("hilda:init_file_uploader");
});
