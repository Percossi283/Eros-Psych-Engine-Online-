package online;

import backend.TouchFunctions;
import online.states.OpenURL;
import flixel.math.FlxRect;
import openfl.events.KeyboardEvent;
import lime.system.Clipboard;

// this class took me 2 days to make because my ass iz addicted to websites HELP
class ChatBox extends FlxTypedSpriteGroup<FlxSprite> {
	public static var instance:ChatBox;
	var prevMouseVisibility:Bool = false;

    public var focused(default, set):Bool = false;
	public var typing:Bool = false;
	function set_focused(v) {
		if (v) {
			prevMouseVisibility = FlxG.mouse.visible;
			FlxG.mouse.visible = true;
			var shit = #if android " - Press BACK on your phone to close ChatBox)" #else ")" #end;
			typeTextHint.text = #if mobile "(Touch here to open your keyboard" + shit #else "(Type something to input the message, ACCEPT to send)" #end;
		}
		else {
			FlxG.mouse.visible = prevMouseVisibility;
			typeTextHint.text = #if mobile "(Touch here to open your keyboard)" #else "(Press TAB to open chat!)" #end;
		}
		targetAlpha = v ? 3 : 0;
		return focused = v;
	}

	var bg:FlxSprite;
	var chatGroup:FlxTypedSpriteGroup<ChatMessage>;
	var typeBg:FlxSprite;
    var typeText:FlxText;
    var typeTextHint:FlxText; // i can call it a hint or tip whatever i want
	var hitbox:FlxSprite;

	var targetAlpha:Float;

    public function new() {
		
		super();
		instance = this;
        
        bg = new FlxSprite();
        bg.makeGraphic(600, 400, FlxColor.BLACK);
		bg.alpha = 0.6;
        add(bg);

		typeTextHint = new FlxText(0, 0, bg.width, #if mobile "(Touch here to open your keyboard)" #else "(Type something to input the message, ACCEPT to send)" #end);
		typeTextHint.setFormat("VCR OSD Mono", 16, FlxColor.WHITE);
		typeTextHint.alpha = 0.6;

		typeBg = new FlxSprite(0, bg.y + bg.height);
		typeBg.makeGraphic(/*Std.int(bg.width)*/ FlxG.width, Std.int(typeTextHint.height), FlxColor.BLACK);
		add(typeBg);

		chatGroup = new FlxTypedSpriteGroup<ChatMessage>();
		add(chatGroup);

		typeText = new FlxText(0, 0, typeBg.width);
		typeText.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

		typeTextHint.y = typeBg.y;
		typeText.y = typeBg.y;

		hitbox = new FlxSprite(0, FlxG.height-340);
		hitbox.makeGraphic(Std.int(FlxG.width / 2.5), 40, FlxColor.TRANSPARENT);

		add(typeTextHint);
		add(typeText);
		add(hitbox);

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);

		focused = false; // initial update

		if (GameClient.isConnected())
			GameClient.room.onMessage("log", function(message) {
				Waiter.put(() -> {
					addMessage(message);
					var sond = FlxG.sound.play(Paths.sound('scrollMenu'));
					sond.pitch = 1.5;
				});
			});
    }

	override function destroy() {
		super.destroy();

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
	}

    public function addMessage(message:String) {
		targetAlpha = 3;

		var chat = new ChatMessage(bg.width, message);
		chatGroup.insert(0, chat);

		if (chatGroup.length >= 22) {
			chatGroup.remove(chatGroup.members[chatGroup.length - 1], true);
		}
    }

    override function update(elapsed) {
		if (focused || alpha > 0) {
			var i = -1;
			while (++i < chatGroup.length) {
				var msg = chatGroup.members[i];

				if (i == 0) {
					msg.y = typeBg.y - msg.height;
				}
				else if (chatGroup.members[i - 1] != null) {
					msg.y = chatGroup.members[i - 1].y - msg.height;
				}

				msg.alpha = 0.8;
				if (msg != null && FlxG.mouse.visible && FlxG.mouse.overlaps(msg)) {
					msg.alpha = 1;
					if (FlxG.mouse.justPressed && msg.link != null) {
						focused = false;
						OpenURL.open(msg.link);
					}
				}

				var newClipRect = (msg.clipRect != null) ? msg.clipRect : new FlxRect();
				newClipRect.height = bg.height;
				newClipRect.width = bg.width;
				newClipRect.y = bg.y - msg.y;
				msg.clipRect = newClipRect;
			}
		}

		if (bg.alpha > 0.6)
			bg.alpha = 0.6;
		if (typeTextHint.alpha > 0.6)
			typeTextHint.alpha = 0.6;

        super.update(elapsed);

		#if mobileC
		if (TouchFunctions.touchJustPressed && TouchFunctions.touchOverlapObject(hitbox) && focused)
			typing = FlxG.stage.window.textInputEnabled = true;
		else if(TouchFunctions.touchJustReleased && !TouchFunctions.touchOverlapObject(this) && focused)
			typing = FlxG.stage.window.textInputEnabled = false;
		if(#if android FlxG.android.justReleased.BACK #else MusicBeatState.instance.virtualPad != null && (MusicBeatState.instance.virtualPad.buttonB.justPressed || MusicBeatState.instance.virtualPad.buttonC.justPressed) #end)
			focused = false;
		#else
		if (FlxG.keys.justPressed.TAB || FlxG.keys.justPressed.ESCAPE)
			focused = !focused;
		#end


		typeTextHint.visible = focused ? (typeText.text.length <= 0) : true;

		if(!focused && targetAlpha > 0.)
			targetAlpha -= elapsed;
		alpha = targetAlpha;
    }

	// some code from FlxInputText
	function onKeyDown(e:KeyboardEvent) {
		if (!focused #if mobile && !typing #end)
			return;

		var key = e.keyCode;

		if (e.charCode == 0) { // non-printable characters crash String.fromCharCode
			return;
		}

		if (key == 46) { // delete
			return;
		}

		if (key == 8) { // bckspc
			typeText.text = typeText.text.substring(0, typeText.text.length - 1);
			return;
		}
		else if (key == 13) { // enter
			GameClient.send("chat", typeText.text);
			typeText.text = "";
			return;
		}
		else if (key == 27) { // esc
			return;
		}

		var newText:String = String.fromCharCode(e.charCode);
		if (key == 86 && e.ctrlKey) {
			newText = Clipboard.text;
		}
		if (e.shiftKey) {
			newText = newText.toUpperCase();
		}

		if (newText.length > 0) {
			typeText.text += newText;
		}
	}
}

class ChatMessage extends FlxText {
	public var link:String = null;

	public function new(fieldWidth:Float = 0, message:String) {
		super(0, 0, fieldWidth, message);
		setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

		var _split = message.split("");
		var i = -1;
		var str = "";
		var formatBeg:Int = 0;
		var formatEnd:Int = 0;
		while (++i < message.length) {
			if (this.link == null && str.startsWith("https://")) {
				if (_split[i].trim() == "") {
					this.link = str;
					formatEnd = i;
				}
				else if (i == message.length - 1) {
					this.link = str + _split[i].trim();
					formatEnd = i + 1;
				}
			}

			str += _split[i];

			if (this.link == null && str.endsWith("https://")) {
				str = "https://";
				formatBeg = i - 7;
			}
		}

		if (link != null)
			addFormat(new FlxTextFormat(FlxColor.CYAN), formatBeg, formatEnd);
	}
}
