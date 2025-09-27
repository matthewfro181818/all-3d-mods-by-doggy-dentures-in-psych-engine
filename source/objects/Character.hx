package objects;

import backend.animation.PsychAnimationController;
import away3d.events.AnimationStateEvent;
import away3d.library.Asset3DLibrary;
import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import flixel.text.FlxText;
import flixel.FlxSprite;
import openfl.utils.Assets;
import haxe.Json;
import backend.Song;
import states.stages.objects.TankmenBG;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;
	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	var vocals_file:String;
	@:optional var _editor_isPlayer:Null<Bool>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

class Character extends FlxSprite {
	// === Shared ===
	public static final DEFAULT_CHARACTER:String = 'bf';

	public var animOffsets:Map<String, Array<Dynamic>> = [];
	public var debugMode:Bool = false;
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4;
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false;
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];
	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var missingCharacter:Bool = false;
	public var missingText:FlxText;
	public var hasMissAnimations:Bool = false;
	public var vocalsFile:String = '';

	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;

	// === AnimateAtlas ===
	public var isAnimateAtlas:Bool = false;
	#if flxanimate
	public var atlas:FlxAnimate;
	#end

	// === 3D Models ===
	public var isModel:Bool = false;
	public var model:ModelThing;
	public var modelName:String = "";
	public var modelScale:Float = 1;
	public var modelSpeed:Map<String, Float> = [];
	public var modelType:String = "md2";
	public var md5Anims:Map<String, String> = [];
	public var noLoopList:Array<String> = [];

	public var spinYaw:Bool = false;
	public var spinYawVal:Int = 0;
	public var spinPitch:Bool = false;
	public var spinPitchVal:Int = 0;
	public var spinRoll:Bool = false;
	public var spinRollVal:Int = 0;

	public var initYaw:Float = 0;
	public var initPitch:Float = 0;
	public var initRoll:Float = 0;
	public var initX:Float = 0;
	public var initY:Float = 0;
	public var initZ:Float = 0;

	private var _lastPlayedAnimation:String = "";

	public var danced:Bool = false;

	// === Construct ===
	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false) {
		super(x, y);
		animation = new PsychAnimationController(this);
		this.isPlayer = isPlayer;
		changeCharacter(character);
		isModel = false;

		switch (curCharacter) {
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
			case 'pico-blazin', 'darnell-blazin':
				skipDance = true;
			case "steve":
				isModel = true;
				modelType = "md2";
				modelName = "steve";
				modelScale = 30;
				modelSpeed = ["default" => 126 / 75];
				noLoopList = ["idle"];
				initYaw = -45;
				initY = -28;

			case "doll":
				isModel = true;
				modelType = "md2";
				modelName = "doll";
				modelScale = 15;
				modelSpeed = ["default" => 1.66, "idle" => 1];
				noLoopList = ["singUP", "singDOWN", "singLEFT", "singRIGHT"];
				initYaw = -45;

			case "crash":
				isModel = true;
				modelType = "md2";
				modelName = "crash";
				modelScale = 15;
				modelSpeed = ["default" => 2.6, "idle" => 1.8];
				noLoopList = ["idle", "singUP", "singDOWN", "singLEFT", "singRIGHT"];
				initYaw = -45;
				initY = -140;
				initZ = -25;

			case "endo":
				isModel = true;
				modelType = "md5";
				modelName = "Collection";
				modelScale = 25;
				initYaw = -45;
				initY = -115;
				md5Anims = [
					"idle" => "Collection_11",
					"singUP" => "Collection_4",
					"singLEFT" => "Collection_17",
					"singDOWN" => "Collection_6",
					"singRIGHT" => "Collection_14"
				];
				modelSpeed = [
					"default" => 1,
					"singRIGHT" => 1.7,
					"singLEFT" => 2,
					"singUP" => 1.5,
					"singDOWN" => 1.5
				];

			case "skeleton":
				isModel = true;
				modelType = "awd";
				modelName = "skeleton";
				modelScale = 150;
				initYaw = 90;
				initY = 50;
				modelSpeed = ["default" => 1];

			default:
				loadFromJson(character);
		}
	}

	public function changeCharacter(character:String) {
		animationsArray = [];
		animOffsets = [];
		curCharacter = character;
		var characterPath:String = 'characters/$character.json';

		var path:String = Paths.getPath(characterPath, TEXT);
		#if MODS_ALLOWED
		if (!FileSystem.exists(path))
		#else
		if (!Assets.exists(path))
		#end
		{
			path = Paths.getSharedPath('characters/' + DEFAULT_CHARACTER + '.json');
			missingCharacter = true;
			missingText = new FlxText(0, 0, 300, 'ERROR:\n$character.json', 16);
			missingText.alignment = CENTER;
		}

		try {
			#if MODS_ALLOWED
			loadCharacterFile(Json.parse(File.getContent(path)));
			#else
			loadCharacterFile(Json.parse(Assets.getText(path)));
			#end
		} catch (e:Dynamic) {
			trace('Error loading character file of "$character": $e');
		}

		skipDance = false;
		hasMissAnimations = hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss');
		recalculateDanceIdle();
		dance();
	}

	// === JSON loading ===
	private function loadFromJson(character:String) {
		var characterPath:String = 'characters/$character.json';
		var path:String = Paths.getPath(characterPath, TEXT);
		try {
			#if MODS_ALLOWED
			loadCharacterFile(Json.parse(File.getContent(path)));
			#else
			loadCharacterFile(Json.parse(Assets.getText(path)));
			#end
		} catch (e:Dynamic) {
			trace('Error loading $character: $e');
		}
	}

	// === Update ===
	override function update(elapsed:Float) {
		if (isModel) {
			if (model != null && model.currentAnim != null && model.currentAnim.startsWith("sing"))
				holdTimer += elapsed;

			if (!isPlayer && holdTimer >= Conductor.stepCrochet * 0.0011 * singDuration) {
				dance();
				holdTimer = 0;
			}

			if (spinYaw) model.addYaw(elapsed * spinYawVal);
			if (spinPitch) model.addPitch(elapsed * spinPitchVal);
			if (spinRoll) model.addRoll(elapsed * spinRollVal);
		} else {
			if (isAnimateAtlas) atlas.update(elapsed);

			if (getAnimationName() != null && getAnimationName().startsWith("sing"))
				holdTimer += elapsed;
			else if (isPlayer)
				holdTimer = 0;

			if (!isPlayer && holdTimer >= Conductor.stepCrochet * 0.0011 * singDuration) {
				dance();
				holdTimer = 0;
			}
		}
		super.update(elapsed);
	}

	// === Anim control ===
	public function playAnim(name:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
		specialAnim = false;

		if (isModel) {
			if (modelType == "md5" && md5Anims.exists(name))
				model.playAnim(md5Anims.get(name), force, frame);
			else
				model.playAnim(name, force, frame);
			_lastPlayedAnimation = name;
			return;
		}

		if (!isAnimateAtlas)
			animation.play(name, force, reversed, frame);
		else {
			atlas.anim.play(name, force, reversed, frame);
			atlas.update(0);
		}
		_lastPlayedAnimation = name;

		if (hasAnimation(name)) {
			var daOffset = animOffsets.get(name);
			offset.set(daOffset[0], daOffset[1]);
		}
	}

	// === Dance ===
	public function dance() {
		if (isModel) {
			if (!noLoopList.contains("idle"))
				playAnim("idle", true);
		} else {
			if (danceIdle) {
				danced = !danced;
				if (danced)
					playAnim("danceRight" + idleSuffix);
				else
					playAnim("danceLeft" + idleSuffix);
			} else if (hasAnimation("idle" + idleSuffix))
				playAnim("idle" + idleSuffix);
		}
	}

	// === End-of-anim ===
	function animationEnd(name:String) {
		switch (curCharacter) {
			case "skeleton", "endo", "crash":
				if (name.startsWith("sing"))
					playAnim("idle", true);
		}
	}

	// === Helpers ===
	inline public function hasAnimation(anim:String):Bool
		return animOffsets.exists(anim);

	inline public function getAnimationName():String
		return _lastPlayedAnimation;

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
		animOffsets[name] = [x, y];

	// === Draw override ===
	#if flxanimate
	public override function draw() {
		var lastAlpha:Float = alpha;
		var lastColor:FlxColor = color;
		if (missingCharacter) {
			alpha *= 0.6;
			color = FlxColor.BLACK;
		}

		if (isModel && model != null) {
			model.render(x + initX, y + initY, initZ);
			if (model.mesh != null) {
				model.mesh.rotationX = initPitch;
				model.mesh.rotationY = initYaw;
				model.mesh.rotationZ = initRoll;
				model.mesh.visible = visible;
				if (model.mesh.material != null)
					model.mesh.material.alpha = alpha;
			}
			alpha = lastAlpha;
			color = lastColor;
			return;
		}

		if (isAnimateAtlas) {
			if (atlas.anim.curInstance != null) {
				copyAtlasValues();
				atlas.draw();
				alpha = lastAlpha;
				color = lastColor;
			}
			return;
		}

		super.draw();
	}
	#end

	#if flxanimate
	public function copyAtlasValues() {
		@:privateAccess {
			atlas.cameras = cameras;
			atlas.scrollFactor = scrollFactor;
			atlas.scale = scale;
			atlas.offset = offset;
			atlas.origin = origin;
			atlas.x = x;
			atlas.y = y;
			atlas.angle = angle;
			atlas.alpha = alpha;
			atlas.visible = visible;
			atlas.flipX = flipX;
			atlas.flipY = flipY;
			atlas.shader = shader;
			atlas.antialiasing = antialiasing;
			atlas.colorTransform = colorTransform;
			atlas.color = color;
		}
	}
	#end

	// === Compatibility Helpers ===
	public inline function isAnimationNull():Bool {
		if (isModel) return model == null || model.currentAnim == null;
		return !isAnimateAtlas ? (animation.curAnim == null) : (atlas.anim.curInstance == null || atlas.anim.curSymbol == null);
	}

	public inline function isAnimationFinished():Bool {
		if (isModel) return false;
		if (isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.finished : atlas.anim.finished;
	}

	public function finishAnimation():Void {
		if (isModel) return;
		if (isAnimationNull()) return;
		if (!isAnimateAtlas) animation.curAnim.finish();
		else atlas.anim.curFrame = atlas.anim.length - 1;
	}

	public var animPaused(get, set):Bool;
	private function get_animPaused():Bool {
		if (isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.paused : !atlas.anim.isPlaying;
	}
	private function set_animPaused(value:Bool):Bool {
		if (isAnimationNull()) return value;
		if (!isAnimateAtlas) animation.curAnim.paused = value;
		else {
			if (value) atlas.pauseAnimation();
			else atlas.resumeAnimation();
		}
		return value;
	}

	public var danceEveryNumBeats:Int = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle():Void {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix));

		if (settingCharacterUp) {
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		} else if (lastDanceIdle != danceIdle) {
			var calc:Float = danceEveryNumBeats;
			if (danceIdle) calc /= 2; else calc *= 2;
			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	private function loadMappedAnims():Void {
		try {
			var songData:SwagSong = Song.getChart('picospeaker', Paths.formatToSongPath(Song.loadedSongName));
			if (songData != null)
				for (section in songData.notes)
					for (songNotes in section.sectionNotes)
						animationNotes.push(songNotes);

			TankmenBG.animationNotes = animationNotes;
			animationNotes.sort((a, b) -> FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]));
		}
		catch (e:Dynamic) {
			trace("loadMappedAnims failed: " + e);
		}
	}
}
