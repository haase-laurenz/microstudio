var extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

this.MusicEditor = (function(superClass) {
  extend(MusicEditor, superClass);

  function MusicEditor(app) {
    MusicEditor.__super__.constructor.call(this, app);
    this.folder = "music";
    this.item = "music";
    this.list_change_event = "musiclist";
    this.get_item = "getMusic";
    this.use_thumbnails = true;
    this.extensions = ["mp3", "ogg", "flac"];
    this.update_list = "updateMusicList";
    this.init();
  }

  MusicEditor.prototype.openItem = function(name) {
    var music;
    MusicEditor.__super__.openItem.call(this, name);
    music = this.app.project.getMusic(name);
    if (music != null) {
      return music.play();
    }
  };

  MusicEditor.prototype.createAsset = function(folder) {
    var input;
    input = document.createElement("input");
    input.type = "file";
    input.accept = ".mp3,.ogg,.flac";
    input.addEventListener("change", (function(_this) {
      return function(event) {
        var f, files, i, len;
        files = event.target.files;
        if (files.length >= 1) {
          for (i = 0, len = files.length; i < len; i++) {
            f = files[i];
            _this.fileDropped(f, folder);
          }
        }
      };
    })(this));
    return input.click();
  };

  MusicEditor.prototype.fileDropped = function(file, folder) {
    var reader;
    console.info("processing " + file.name);
    reader = new FileReader();
    reader.addEventListener("load", (function(_this) {
      return function() {
        var audioContext, file_size;
        file_size = reader.result.byteLength;
        console.info("file read, size = " + file_size);
        if (file_size > 30000000) {
          _this.app.appui.showNotification(_this.app.translator.get("Music file is too heavy"));
          return;
        }
        audioContext = new AudioContext();
        return audioContext.decodeAudioData(reader.result, function(decoded) {
          var ext, music, name, r2, thumbnailer;
          console.info(decoded);
          thumbnailer = new SoundThumbnailer(decoded, 192, 64, "hsl(200,80%,60%)");
          name = file.name.split(".")[0];
          ext = file.name.split(".")[1].toLowerCase();
          name = _this.findNewFilename(name, "getMusic", folder);
          if (folder != null) {
            name = folder.getFullDashPath() + "-" + name;
          }
          if (folder != null) {
            folder.setOpen(true);
          }
          music = _this.app.project.createMusic(name, thumbnailer.canvas.toDataURL(), file_size);
          music.uploading = true;
          _this.setSelectedItem(name);
          r2 = new FileReader();
          r2.addEventListener("load", function() {
            var data;
            music.local_url = r2.result;
            data = r2.result.split(",")[1];
            _this.app.project.addPendingChange(_this);
            return _this.app.client.sendRequest({
              name: "write_project_file",
              project: _this.app.project.id,
              file: "music/" + name + "." + ext,
              properties: {},
              content: data,
              thumbnail: thumbnailer.canvas.toDataURL().split(",")[1]
            }, function(msg) {
              console.info(msg);
              _this.app.project.removePendingChange(_this);
              music.uploading = false;
              _this.app.project.updateMusicList();
              return _this.checkNameFieldActivation();
            });
          });
          return r2.readAsDataURL(file);
        });
      };
    })(this));
    return reader.readAsArrayBuffer(file);
  };

  return MusicEditor;

})(Manager);
