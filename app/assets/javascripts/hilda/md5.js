function getFileMD5(file,callback,progress){
  var blobSlice = File.prototype.slice || File.prototype.mozSlice || File.prototype.webkitSlice;
  var chunkSize = 2097152; // Read in chunks of 2MB
  var chunks = Math.ceil(file.size / chunkSize);
  var currentChunk = 0;
  var spark = new SparkMD5.ArrayBuffer();
  var fileReader = new FileReader();

  var loadNext=function() {
    var start = currentChunk * chunkSize;
    if(progress) progress(start,file.size);
    var end = Math.min(start+chunkSize,file.size);
    fileReader.readAsArrayBuffer(blobSlice.call(file, start, end));
  };

  fileReader.onload = function (e) {
    spark.append(e.target.result);
    currentChunk++;
    if (currentChunk < chunks) {
      loadNext();
    } else {
      if(progress) progress(file.size,file.size);
      callback('OK',spark.end());
    }
  };

  fileReader.onerror = function () {
    callback('ERROR',null);
  };

  loadNext();
}

function getFileMD5s(files,callback,progress){
  var current = 0;
  var md5s = [];
  var inner_progress = null;
  if(progress) {
    inner_progress = function(pos,size){
      progress(files[current],pos,size);
    };
  }
  var nextFile = function(){
    if(current>=files.length) {
      callback('OK',md5s);
      return;
    }
    file = files[current];
    getFileMD5(file,function(status,result){
      if(status!='OK') {
        callback('ERROR',file);
        return;
      }
      md5s.push(result);
      if(progress) progress(files[current],files[current].size,files[current].size,result);
      current++;
      nextFile();
    },inner_progress);
  };
  nextFile();
}
