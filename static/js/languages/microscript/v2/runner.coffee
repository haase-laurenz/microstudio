class @Runner
  constructor:(@microvm)->

  init:()->
    @initialized = true
    @system = @microvm.context.global.system
    @system.preemptive = 1
    @system.threads = []
    @main_thread = new Thread @
    @threads = [@main_thread]
    @current_thread = @main_thread
    @thread_index = 0

    @microvm.context.global.print = @microvm.context.meta.print
    @microvm.context.global.random = new Random(0)
    @fps = 60
    @fps_max = 60
    @cpu_load = 0
    @microvm.context.meta.print("microScript 2.0 - alpha")

  run:(src,filename)->
    @init() if not @initialized

    parser = new Parser(src,filename)
    parser.parse()
    if parser.error_info?
      err = parser.error_info
      err.type = "compile"
      throw err

    program = parser.program

    compiler = new Compiler(program)
    result = null
    compiler.routine.callback = (res)->
      result = res
    @main_thread.addCall compiler.routine
    @tick()
    result

  call:(name,args)->
    if name == "draw" or name == "update"
      if @microvm.context.global[name]?
        @main_thread.addCall "#{name}()"
      if name == "draw"
        @tick()
      return

    if @microvm.context.global[name]?
      src = "#{name}()"
      parser = new Parser(src,"")
      parser.parse()
      program = parser.program
      compiler = new Compiler(program)

      processor = @main_thread.processor
      processor.time_limit = Date.now()+16
      processor.load compiler.routine
      processor.run(@microvm.context)
    else
      return 0


  process:(thread,time_limit)->
    processor = thread.processor
    processor.time_limit = time_limit
    @current_thread = thread
    processor.run(@microvm.context)

  tick:()->
    if @system.fps?
      @fps = @fps*.9 + @system.fps*.1

    @fps_max = Math.max @fps,@fps_max

    frame_time = Math.min(16,Math.floor(1000/@fps_max))
    if @fps < 59
      margin = 10
    else
      margin = Math.floor(1000/@fps*.8)

    time = Date.now()
    time_limit = time+100 # allow more time to prevent interrupting main_thread in the middle of a draw()
    time_out = if @system.preemptive then time_limit else Infinity

    processor = @main_thread.processor
    if not processor.done
      if @main_thread.sleep_until?
        if Date.now() >= @main_thread.sleep_until
          delete @main_thread.sleep_until
          @process @main_thread, time_out
      else
        @process @main_thread, time_out

    while processor.done and Date.now() < time_out and @main_thread.loadNext()
      @process @main_thread, time_out

    time_limit = time+margin # secondary threads get remaining time
    time_out = if @system.preemptive then time_limit else Infinity

    processing = true
    while processing
      processing = false

      for t in @threads
        if t != @main_thread
          continue if t.paused
          processor = t.processor
          if not processor.done
            if t.sleep_until?
              if Date.now() >= t.sleep_until
                delete t.sleep_until
                @process t, time_out
                processing = true
            else
              @process t, time_out
              processing = true
          else if t.start_time?
            if t.repeat
              while time >= t.start_time
                if time >= t.start_time+150
                  t.start_time = time+t.delay
                else
                  t.start_time += t.delay

                processor.load t.routine
                @process t, time_out
                processing = true
            else
              if time >= t.start_time
                delete t.start_time
                processor.load t.routine
                @process t, time_out
                processing = true
          else
            t.terminated = true

      break if Date.now() > time_limit

    for i in [@threads.length-1..1] by -1
      t = @threads[i]
      if t.terminated
        @threads.splice i,1
        index = @system.threads.indexOf(t.interface)
        if index >= 0
          @system.threads.splice index, 1

    t = Date.now()-time
    dt = time_limit-time
    load = t/dt*100
    @cpu_load = @cpu_load*.9+load*.1
    @system.cpu_load = Math.min(100,Math.round(@cpu_load))
    return

  createThread:(routine,delay,repeat)->
    t = new Thread @
    t.routine = routine
    @threads.push t
    t.start_time = Date.now()+delay-1000/@fps
    if repeat
      t.repeat = repeat
      t.delay = delay
    @system.threads.push t.interface
    t.interface

  sleep:(value)->
    if @current_thread?
      @current_thread.sleep_until = Date.now()+Math.max(0,value)


class @Thread
  constructor:(@runner)->
    @loop = false
    @processor = new Processor @runner
    @paused = false
    @terminated = false
    @next_calls = []
    @interface =
      pause: ()=>@pause()
      resume: ()=>@resume()
      stop: ()=>@stop()
      status: "running"

  addCall:(call)->
    if @next_calls.indexOf(call) < 0
      @next_calls.push call

  loadNext:()->
    if @next_calls.length > 0
      f = @next_calls.splice(0,1)[0]
      if f instanceof Routine
        @processor.load f
      else
        parser = new Parser(f,"")
        parser.parse()
        program = parser.program
        compiler = new Compiler(program)
        @processor.load compiler.routine
      true
    else
      false

  pause:()->
    if @interface.status == "running"
      @interface.status = "paused"
      @paused = true
      1
    else
      0

  resume:()->
    if @interface.status == "paused"
      @interface.status = "running"
      @paused = false
      1
    else
      0

  stop:()->
    @interface.status = "stopped"
    @terminated = true
    1
