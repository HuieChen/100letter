extends SceneTree
const Director=preload("res://scripts/rebuild/street_camera_director.gd")
var out:="user://qa/camera-cadence/"
var checks:=0
var failures:Array[String]=[]
var rows:Array=[]
func _initialize():
 root.unfocusable=true
 for argument:String in OS.get_cmdline_user_args():
  if argument.begins_with("--qa-out="):out=argument.trim_prefix("--qa-out=").trim_suffix("/")+"/"
 run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func fresh():
 var driver=Director.new();root.add_child(driver);driver.process_mode=Node.PROCESS_MODE_DISABLED
 driver.frame_foot(1500.0,10000.0)
 return driver
func run():
 DirAccess.make_dir_recursive_absolute(out)
 var reference_lag:=0.0
 for fps:int in [60,5,10,15,20,30,144]:
  var driver=fresh()
  var foot:=1500.0
  var previous:float=driver.scroll
  var monotone:=true
  for frame:int in range(fps*5):
   foot+=200.0/float(fps)
   driver.frame_foot(foot,10000.0)
   driver.advance(1.0/float(fps))
   monotone=monotone and is_finite(driver.scroll) and driver.scroll>=previous and driver.scroll<=driver.target.position.x
   previous=driver.scroll
  var lag:float=driver.target.position.x-driver.scroll
  if fps==60:reference_lag=lag
  check(monotone,"%d FPS is finite, monotone and does not overshoot"%fps)
  check(lag>5 and lag<45,"%d FPS retains gentle bounded follow lag"%fps)
  check(absf(lag-reference_lag)<1.5,"%d FPS settled lag differs by less than 1.5 px from 60 Hz"%fps)
  for frame:int in range(fps):driver.advance(1.0/float(fps))
  var stopped:float=driver.target.position.x-driver.scroll
  check(absf(stopped)<.02,"%d FPS settles within one second"%fps)
  rows.append({"fps":fps,"linear_lag":lag,"stopped_lag":stopped})
  driver.free()
 # Invalid/no-time calls cannot poison the upstream solver, even while resting.
 var inert=fresh()
 var before:Transform2D=inert.phantom.get_transform_output()
 var velocity:Vector2=inert.phantom.get("_follow_velocity_ref")
 for delta:float in [0.0,-.1,INF,NAN]:
  inert.advance(delta)
  check(inert.phantom.get_transform_output()==before and inert.phantom.get("_follow_velocity_ref")==velocity,"zero/negative/nonfinite delta is inert: "+str(delta))
 inert.frame_foot(1503.0,10000.0);inert.advance(1.0/60.0)
 check(is_finite(inert.scroll) and inert.phantom.get("_follow_velocity_ref").is_finite(),"normal frame after invalid delta remains finite")
 var frozen:float=inert.scroll
 var frozen_transform:Transform2D=inert.phantom.get_transform_output()
 for frame:int in range(30):inert.advance(.2,false)
 check(inert.scroll==frozen and inert.phantom.get_transform_output()==frozen_transform,"disabled camera preserves composition and solver state")
 for frame:int in range(60):inert.advance(1.0/60.0)
 check(absf(inert.scroll-inert.target.position.x)<.02,"resume settles onto the same target")
 inert.frame_foot(9900.0,10000.0)
 check(inert.scroll==8400.0,"right arrival teleports to the panorama limit")
 inert.advance(.2)
 check(inert.scroll==8400.0,"low-rate step after teleport keeps the right edge fixed")
 inert.frame_foot(100.0,10000.0);inert.advance(.2)
 check(inert.scroll==0.0,"left arrival snaps and remains fixed")
 inert.free()
 var long_frame=fresh();var bounded=fresh()
 long_frame.frame_foot(1550.0,10000.0);bounded.frame_foot(1550.0,10000.0)
 long_frame.advance(5.0);bounded.advance(.25)
 check(long_frame.phantom.get_transform_output()==bounded.phantom.get_transform_output(),"long frame uses the courier's 250 ms maximum")
 long_frame.free();bounded.free()
 # Match the established direct one-step Phantom route at normal refresh.
 var current=fresh();var direct=fresh()
 var same:=true
 for frame:int in range(180):
  var foot:=1500.0+float(frame+1)*200.0/60.0
  current.frame_foot(foot,10000.0);direct.frame_foot(foot,10000.0)
  current.advance(1.0/60.0);direct.phantom.process_logic(1.0/60.0)
  same=same and current.phantom.get_transform_output()==direct.phantom.get_transform_output()
 check(same,"60 Hz transform is identical to the original one-step Phantom solve")
 current.free();direct.free()
 FileAccess.open(out+"receipt.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"cadence":rows,"method":"Actual PhantomCamera2D driver, deterministic scene-local coordinates; no OS input. 5–144 Hz, unchanged 60 Hz solve, invalid/disabled deltas, resume, teleport, bounds and courier delta cap."},"  "))
 print("PHANTOM_CAMERA_CADENCE_20261108 ",checks," checks / ",failures.size()," failures")
 await process_frame
 quit(0 if failures.is_empty() else 1)
