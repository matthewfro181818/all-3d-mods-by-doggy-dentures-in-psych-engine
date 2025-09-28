package objects;

import backend.animation.PsychAnimationController;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;
import openfl.utils.Assets;
import haxe.Json;
import backend.Song;
import states.stages.objects.TankmenBG;
import Main;
#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end
#if flxanimate
import flxanimate.FlxAnimate;
#end

// === Typedefs ===
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

// === Character Class ===
class Character extends FlxSprite {
	public var debugMode:Bool = false; // for CharacterEditorState
	public var canAutoAnim:Bool = true; // used in PlayState

	public static inline var DEFAULT_CHARACTER:String = "bf";

	public var curCharacter:String = DEFAULT_CHARACTER;
	public var isPlayer:Bool = false;

	public var animOffsets:Map<String, Array<Dynamic>> = [];
	public var animationsArray:Array<AnimArray> = [];
	public var animationNotes:Array<Dynamic> = [];

	public var healthIcon:String = "face";
	public var healthColorArray:Array<Int> = [255, 0, 0];
	public var vocalsFile:String = "";

	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;

	public var singDuration:Float = 4;
	public var idleSuffix:String = "";
	public var danceIdle:Bool = false;
	public var danced:Bool = false;
	public var danceEveryNumBeats:Int = 2;
	public var skipDance:Bool = false;

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var stunned:Bool = false;

	public var missingCharacter:Bool = false;
	public var missingText:FlxText;
	public var hasMissAnimations:Bool = false;

	public var imageFile:String = "";
	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];

	// === AnimateAtlas ===
	@:allow(states.editors.CharacterEditorState)
	public var isAnimateAtlas(default, null):Bool = false;
	#if flxanimate
	public var atlas:FlxAnimate;
	#end

	// === 3D Model Support ===
	public var isModel:Bool = false;
	public var beganLoading:Bool = false;
	public var modelName:String;
	public var modelScale:Float = 1;
	public var modelSpeed:Map<String, Float> = new Map<String, Float>();
	public var model:ModelThing;
	public var noLoopList:Array<String> = [];
	public var modelType:String = "md2";
	public var md5Anims:Map<String, String> = new Map<String, String>();

	public var spinYaw:Bool = false;
	public var spinYawVal:Int = 0;
	public var spinPitch:Bool = false;
	public var spinPitchVal:Int = 0;
	public var spinRoll:Bool = false;
	public var spinRollVal:Int = 0;
	public var yTween:FlxTween;
	public var xTween:FlxTween;
	public var circleTween:FlxTween;
	public var originalY:Float = -1;
	public var originalX:Float = -1;

	public var initYaw:Float = 0;
	public var initPitch:Float = 0;
	public var initRoll:Float = 0;
	public var initX:Float = 0;
	public var initY:Float = 0;
	public var initZ:Float = 0;

	private var _lastPlayedAnimation:String = "";

	public function new(x:Float, y:Float, ?character:String = "bf", ?isPlayer:Bool = false) {
		super(x, y);
		animation = new PsychAnimationController(this);
		this.isPlayer = isPlayer;
		changeCharacter(character);

		switch (curCharacter) {
			case "pico-speaker":
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
			case "pico-blazin", "darnell-blazin":
				skipDance = true;
		}
	}

	// === Model setup ===
	public function setupModel():Void {
		model = new ModelThing(modelType, // type
			modelName, // fileName
			Main.modelView, // ModelView ref
			modelScale, // scale
			modelSpeed, // anim speed map
			initYaw, initPitch, initRoll, 1.0, // alpha
			initX, initY, initZ, noLoopList, md5Anims);

		if (model != null && model.mesh != null && Main.modelView != null) {
			Main.modelView.addModel(model.mesh);
			Main.modelView.addedModels.push(model);
		}
		if (Main.modelView != null && Main.modelView.sprite != null) {
			loadGraphicFromSprite(Main.modelView.sprite);
			updateHitbox();
		}
	}

	// === Change character ===
	public function changeCharacter(character:String):Void {
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
			path = Paths.getSharedPath('characters/$DEFAULT_CHARACTER.json');
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
		hasMissAnimations = hasAnimation("singLEFTmiss") || hasAnimation("singDOWNmiss") || hasAnimation("singUPmiss") || hasAnimation("singRIGHTmiss");
		recalculateDanceIdle();
		dance();
	}

	// === Load Character File ===
	public function loadCharacterFile(json:Dynamic):Void {
		isAnimateAtlas = false;
		isModel = false;

		// === Check for explicit model flag ===
		if (json.isModel == true) {
			isModel = true;
			modelType = (json.modelType != null ? json.modelType : "md2");
			modelName = (json.modelFile != null ? json.modelFile : json.image);
			modelScale = (json.modelScale != null ? json.modelScale : 1);
			if (json.modelSpeed != null)
				modelSpeed = json.modelSpeed;
			if (json.initYaw != null)
				initYaw = json.initYaw;
			if (json.initPitch != null)
				initPitch = json.initPitch;
			if (json.initRoll != null)
				initRoll = json.initRoll;
			if (json.initX != null)
				initX = json.initX;
			if (json.initY != null)
				initY = json.initY;
			if (json.initZ != null)
				initZ = json.initZ;
			if (json.noLoopList != null)
				noLoopList = json.noLoopList;
			if (json.md5Anims != null)
				md5Anims = json.md5Anims;

			setupModel();
			return;
		}

		// === AnimateAtlas detection ===
		#if flxanimate
		var animToFind:String = Paths.getPath('images/' + json.image + '/Animation.json', TEXT);
		if (#if MODS_ALLOWED FileSystem.exists(animToFind) || #end Assets.exists(animToFind))
			isAnimateAtlas = true;
		#end

		// === Normal sprite loading ===
		scale.set(1, 1);
		updateHitbox();

		if (!isAnimateAtlas) {
			frames = Paths.getMultiAtlas(json.image.split(","));
		}
		#if flxanimate
		else {
			atlas = new FlxAnimate();
			atlas.showPivot = false;
			try {
				Paths.loadAnimateAtlas(cast atlas, json.image);
			} catch (e:haxe.Exception) {
				FlxG.log.warn('Could not load atlas ${json.image}: $e');
				trace(e.stack);
			}
		}
		#end

		// === Core character setup ===
		imageFile = json.image;
		jsonScale = json.scale;
		if (json.scale != 1) {
			scale.set(jsonScale, jsonScale);
			updateHitbox();
		}

		positionArray = json.position;
		cameraPosition = json.camera_position;
		healthIcon = json.healthicon;
		singDuration = json.sing_duration;
		flipX = (json.flip_x != isPlayer);
		originalFlipX = (json.flip_x == true);
		editorIsPlayer = json._editor_isPlayer;
		healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];
		vocalsFile = json.vocals_file != null ? json.vocals_file : "";

		noAntialiasing = (json.no_antialiasing == true);
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// === Animations ===
		animationsArray = json.animations;
		for (anim in animationsArray) {
			if (!isAnimateAtlas) {
				if (anim.indices != null && anim.indices.length > 0)
					animation.addByIndices(anim.anim, anim.name, anim.indices, "", anim.fps, anim.loop);
				else
					animation.addByPrefix(anim.anim, anim.name, anim.fps, anim.loop);
			}
			#if flxanimate
			else {
				if (anim.indices != null && anim.indices.length > 0)
					atlas.anim.addBySymbolIndices(anim.anim, anim.name, anim.indices, anim.fps, anim.loop);
				else
					atlas.anim.addBySymbol(anim.anim, anim.name, anim.fps, anim.loop);
			}
			#end

			if (anim.offsets != null && anim.offsets.length > 1)
				addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
			else
				addOffset(anim.anim, 0, 0);
		}

		#if flxanimate
		if (isAnimateAtlas)
			copyAtlasValues();
		#end
	}

	// === Anim control ===
	public function playAnim(name:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
		specialAnim = false;

		if (isModel) {
			if (model == null)
				return;
			if (modelType == "md5" && md5Anims.exists(name))
				model.playAnim(md5Anims.get(name), force, frame);
			else
				model.playAnim(name, force, frame);
			_lastPlayedAnimation = name;
			return;
		}

		if (!isAnimateAtlas)
			animation.play(name, force, reversed, frame);
		#if flxanimate
		else {
			atlas.anim.play(name, force, reversed, frame);
			atlas.update(0);
		}
		#end

		_lastPlayedAnimation = name;

		if (hasAnimation(name)) {
			var daOffset = animOffsets.get(name);
			offset.set(daOffset[0], daOffset[1]);
		}
	}

	// === Helpers ===
	public function isAnimationNull():Bool {
		if (isModel)
			return model.currentAnim == null || model.currentAnim == "";
		#if flxanimate
		return !isAnimateAtlas ? (animation.curAnim == null) : (atlas.anim.curInstance == null || atlas.anim.curSymbol == null);
		#else
		return animation.curAnim == null;
		#end
	}

	public function getAnimationName():String {
		if (isModel)
			return model.currentAnim;
		return _lastPlayedAnimation;
	}

	public function isAnimationFinished():Bool {
		if (isModel)
			return false;
		if (isAnimationNull())
			return false;
		#if flxanimate
		return !isAnimateAtlas ? animation.curAnim.finished : atlas.anim.finished;
		#else
		return animation.curAnim.finished;
		#end
	}

	public function finishAnimation():Void {
		if (isModel)
			return;
		if (isAnimationNull())
			return;
		if (!isAnimateAtlas)
			animation.curAnim.finish();
		#if flxanimate
		else
			atlas.anim.curFrame = atlas.anim.length - 1;
		#end
	}

	public function hasAnimation(anim:String):Bool {
		if (isModel)
			return true; // assume models have all anims mapped
		return animOffsets.exists(anim);
	}

	// Pause/resume
	public var animPaused(get, set):Bool;

	private function get_animPaused():Bool {
		if (isAnimationNull())
			return false;
		if (isModel)
			return false;
		return !isAnimateAtlas ? animation.curAnim.paused : !atlas.anim.isPlaying;
	}

	private function set_animPaused(value:Bool):Bool {
		if (isAnimationNull())
			return value;

		if (!isAnimateAtlas) {
			animation.curAnim.paused = value;
		} else {
			if (value)
				atlas.anim.pause();
			else {
				atlas.anim.play();
				atlas.update(0); // refresh instantly
			}
		}
		return value;
	}

	// === Dance logic ===
	public function dance():Void {
		if (!skipDance && !specialAnim) {
			if (danceIdle) {
				danced = !danced;
				playAnim(danced ? "danceRight" + idleSuffix : "danceLeft" + idleSuffix);
			} else if (hasAnimation("idle" + idleSuffix))
				playAnim("idle" + idleSuffix);
		}
	}

	// === Atlas drawing ===
	#if flxanimate
	public override function draw() {
		if (isAnimateAtlas && atlas != null && atlas.anim.curInstance != null) {
			copyAtlasValues();
			atlas.draw();
			if (missingCharacter && visible) {
				missingText.x = getMidpoint().x - 150;
				missingText.y = getMidpoint().y - 10;
				missingText.draw();
			}
			return;
		}
		super.draw();
		if (missingCharacter && visible) {
			missingText.x = getMidpoint().x - 150;
			missingText.y = getMidpoint().y - 10;
			missingText.draw();
		}
	}

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

	public override function destroy() {
		atlas = FlxDestroyUtil.destroy(atlas);
		super.destroy();
	}
	#end

	// === Animation mapping for Pico Speaker ===
	function loadMappedAnims():Void {
		try {
			var songData:SwagSong = Song.getChart("picospeaker", Paths.formatToSongPath(Song.loadedSongName));
			if (songData != null)
				for (section in songData.notes)
					for (songNotes in section.sectionNotes)
						animationNotes.push(songNotes);
			TankmenBG.animationNotes = animationNotes;
			animationNotes.sort((a, b) -> FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]));
		} catch (e:Dynamic) {}
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0) {
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String) {
		animation.addByPrefix(name, anim, 24, false);
	}

	// Recalculate dance style
	private var settingCharacterUp:Bool = true;

	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (hasAnimation("danceLeft" + idleSuffix) && hasAnimation("danceRight" + idleSuffix));

		if (settingCharacterUp)
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		else if (lastDanceIdle != danceIdle) {
			var calc:Float = danceEveryNumBeats;
			if (danceIdle)
				calc /= 2;
			else
				calc *= 2;
			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}
}
