package online.states;

import flixel.addons.transition.FlxTransitionableState;
import objects.HealthIcon;
import states.MainMenuState;
import flixel.FlxObject;
import io.colyseus.Client.RoomAvailable;
import lime.app.Application;
#if (target.threaded)
import sys.thread.Thread;
#end

class FindRoom extends MusicBeatState {
	var swagRooms:FlxTypedSpriteGroup<RoomText>;
    public var curSelected:Int;
    public var curRoom:Room;
    public static var coolControls:Controls;
	public static var loadingIcon:HealthIcon;
	public static var connecting:Bool = false;
	public static var instance:FindRoom;

    var noRoomsText:FlxText;

    public function new() {
        super();
		instance = this;

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xff2d3683;
		bg.updateHitbox();
		bg.screenCenter();
		bg.scrollFactor.set(0, 0);
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		var lines:FlxSprite = new FlxSprite().loadGraphic(Paths.image('coolLines'));
		lines.updateHitbox();
		lines.screenCenter();
		lines.antialiasing = ClientPrefs.data.antialiasing;
		lines.scrollFactor.set(0, 0);
		add(lines);
        
		swagRooms = new FlxTypedSpriteGroup<RoomText>();
		add(swagRooms);
		curSelected = 0;

		noRoomsText = new FlxText(0, 0, 0, "(No rooms found! Refresh the list using " + #if mobileC "C)" #else "R)" #end);
		noRoomsText.setFormat("VCR OSD Mono", 25, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		noRoomsText.screenCenter(XY);
		noRoomsText.scrollFactor.set(0, 0);
		add(noRoomsText);

		loadingIcon = new HealthIcon();
		add(loadingIcon);
		loadingIcon.alpha = 0;
		loadingIcon.sprTracker = null; // so it dosen't keep updating the position on it's own
		loadingIcon.setPosition(FlxG.width - 140, FlxG.height - 140);
		FlxTween.tween(loadingIcon, {angle : 360} , 0.8, {type: FlxTweenType.LOOPING});

		#if mobileC
		addVirtualPad(UP_DOWN, A_B_C);
		#end
		
		coolControls = controls;
    }

    override function create() {
		if(swagRooms != null)
			refreshRooms();
		super.create();
		
    }

    override function update(elapsed) {
        super.update(elapsed);

		noRoomsText.visible = swagRooms.length <= 0;

		if(!connecting){

		    if ((FlxG.keys.justPressed.R #if mobileC || virtualPad.buttonC.justPressed #end) && swagRooms != null) {
		        refreshRooms();
		    }

			if (controls.UI_UP_P)
				curSelected--;
			else if (controls.UI_DOWN_P)
				curSelected++;

			if (curSelected >= swagRooms.length) {
				curSelected = 0;
			}
			else if (curSelected < 0) {
				curSelected = swagRooms.length - 1;
			}


		    if (controls.BACK) {
				FlxTransitionableState.skipNextTransIn = FlxTransitionableState.skipNextTransOut = true;
				MusicBeatState.switchState(new Lobby());
				FlxG.sound.play(Paths.sound('cancelMenu'));
		    }
		}
    }

    function refreshRooms() {
		#if (target.threaded) Thread.create(() -> {#end
		curSelected = 0;
		swagRooms.clear();

		GameClient.getAvailableRooms((err, rooms) -> {
            Waiter.put(() -> {
                if (err != null) {
					FlxG.switchState(new Lobby());
					FlxG.sound.play(Paths.sound('cancelMenu'));
					Alert.alert("Couldn't connect!", "ERROR: " + err.code + " - " + err.message + (err.code == 0 ? "\nTry again in a few minutes! The server is probably restarting!" : ""));
                    return;
                }

				curSelected = 0;
				swagRooms.clear();

                var i = 0;
                for (room in rooms) {
					var swagRoom = new RoomText(room);
					swagRoom.ID = i;
                    swagRoom.y += 30 * i;
                    swagRooms.add(swagRoom);
					i++;
                }
            });
        });
	#if (target.threaded)
	});
	#end
    }
}

class RoomText extends FlxText {
    public var code:String;
    var daText:String;

    var _prevSelected:Int = -1;

    public function new(room:RoomAvailable) {
		code = room.roomId;
		daText = "Code: " + code + " | Player: " + room.metadata.name + " | " + room.metadata.ping + "ms";

		super(0, 0, FlxG.width, daText);
	    setFormat("VCR OSD Mono", 30, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    }

    override function update(elapsed) {
        super.update(elapsed);

		if (FindRoom.instance.curSelected != _prevSelected) {
			if (FindRoom.instance.curSelected == ID) {
				text = "> " + daText + " <";
				alpha = 1;
				FlxG.camera.follow(this);
			}
			else {
				text = daText;
				alpha = 0.8;
			}
        }

		if (FindRoom.instance.curSelected == ID && (!FlxG.keys.justPressed.R #if mobileC || !MusicBeatState.instance.virtualPad.buttonC.pressed #end) && FindRoom.coolControls.ACCEPT) {
			GameClient.joinRoom(code, () -> Waiter.put(() -> {
               	trace("joining room: " + code);
				FindRoom.connecting = false;
				FindRoom.loadingIcon.alpha = 0;
				MusicBeatState.switchState(new Room());
			}));
		}

		_prevSelected = FindRoom.instance.curSelected;
    }
}
