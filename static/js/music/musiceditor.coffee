class @MusicEditor extends Manager
  constructor:(app)->
    super app

    @folder = "music"
    @item = "music"
    @list_change_event = "musiclist"
    @get_item = "getMusic"
    @use_thumbnails = true

    @extensions = ["mp3","ogg","flac"]
    @update_list = "updateMusicList"

    @init()

  openItem:(name)->
    super(name)
    music = @app.project.getMusic(name)
    if music?
      music.play()

  createAsset:(folder)->
    input = document.createElement "input"
    input.type = "file"
    input.accept = ".mp3,.ogg,.flac"
    input.addEventListener "change",(event)=>
      files = event.target.files
      if files.length>=1
        for f in files
          @fileDropped(f,folder)
      return

    input.click()

  fileDropped:(file,folder)->
    console.info "processing #{file.name}"
    reader = new FileReader()
    reader.addEventListener "load",()=>
      file_size = reader.result.byteLength
      console.info "file read, size = "+ file_size
      if file_size > 30000000  # client-side limit to 30 Mb
        @app.appui.showNotification(@app.translator.get("Music file is too heavy"))
        return
      audioContext = new AudioContext()
      audioContext.decodeAudioData reader.result,(decoded)=>
        console.info decoded
        thumbnailer = new SoundThumbnailer(decoded,192,64,"hsl(200,80%,60%)")
        name = file.name.split(".")[0]
        ext = file.name.split(".")[1].toLowerCase()
        name = @findNewFilename name,"getMusic",folder
        if folder? then name = folder.getFullDashPath()+"-"+name
        if folder? then folder.setOpen true

        music = @app.project.createMusic(name,thumbnailer.canvas.toDataURL(),file_size)
        music.uploading = true
        @setSelectedItem name

        r2 = new FileReader()
        r2.addEventListener "load",()=>
          music.local_url = r2.result
          data = r2.result.split(",")[1]
          @app.project.addPendingChange @

          @app.client.sendRequest {
            name: "write_project_file"
            project: @app.project.id
            file: "music/#{name}.#{ext}"
            properties: {}
            content: data
            thumbnail: thumbnailer.canvas.toDataURL().split(",")[1]
          },(msg)=>
            console.info msg
            @app.project.removePendingChange(@)
            music.uploading = false
            @app.project.updateMusicList()
            @checkNameFieldActivation()

        r2.readAsDataURL(file)

    reader.readAsArrayBuffer(file)
