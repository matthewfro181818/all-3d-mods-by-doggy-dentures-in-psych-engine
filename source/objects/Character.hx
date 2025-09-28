package objects;

import backend.animation.PsychAnimationController;
import backend.Song;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSort;
import haxe.Json;
import openfl.utils.Assets;
#if flxanimate
import flxanimate._PsychFlxAnimate.FlxAnimate;
#end

// ---------------- JSON types ----------------
typedef CharacterFile = {
	#if flxanimate
	public var atlas:FlxAnimate;
	#else
	public var atlas:Dynamic;
	#end

	public var animations:Array<AnimArray>;
	public var image:String;
	public var scale:Float;
	public var sing_duration:Float;
	public var healthicon:String;
	public var position:Array<Float>;
	public var camera_position:Array<Float>;
	public var flip_x:Bool;
	public var no_antialiasing:Bool;
	public var healthbar_colors:Array<Int>;
	public var vocals_file:String;
	@:optional public var _editor_isPlayer:Null<Bool>;
	// Optional model fields
	@:optional public var isModel:Null<Bool>;
	@:optional public var modelName:Null<String>;
	@:optional public var modelType:Null<String>;
	@:optional public var modelScale:Null<Float>;
	@:optional public var initYaw:Null<Float>;
	@:optional public var initPitch:Null<Float>;
	@:optional public var initRoll:Null<Float>;
	@:optional public var initX:Null<Float>;
	@:optional public var initY:Null<Float>;
	@:optional public var initZ:Null<Float>;
	@:optional public var modelSpeed:Null<Map<String, Float>>;
	@:optional public var noLoopList:Null<Array<String>>;
	@:optional public var md5Anims:Null<Map<String, String>>;
}

typedef AnimArray = {
	public var anim:String;
	public var name:String;
	public var fps:Int;
	public var loop:Bool;
	public var indices:Array<Int>;
	public var offsets:Array<Int>;
}

// ---------------- Character ----------------
class Character extends FlxSprite {
	public static final DEFAULT_CHARACTER:String = 'bf';

	// shared/state fields used across the codebase
	public var animOffsets:Map<String, Array<Dynamic>> = [];
	public var debugMode:Bool = false;
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var canAutoAnim:Bool = true;

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

	// editor helpers
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var editorIsPlayer:Null<Bool> = null;

	// AnimateAtlas support (safe even if flxanimate is not compiled)
	public var isAnimateAtlas:Bool = false;
	#if flxanimate
	public var atlas:FlxAnimate;
	#else
	public var atlas:Dynamic;
	#end

	// 3D Model flags/data
	public var isModel:Bool = false;
	public var beganLoading:Bool = false;

	public var modelName:String = "";
	public var modelType:String = "md2";
	public var modelScale:Float = 1;
	public var modelSpeed:Map<String, Float> = new Map<String, Float>();
	public var model:ModelThing;
	public var noLoopList:Array<String> = [];
	public var md5Anims:Map<String, String> = new Map<String, String>();

	public var initYaw:Float = 0;
	public var initPitch:Float = 0;
	public var initRoll:Float = 0;
	public var initX:Float = 0;
	public var initY:Float = 0;
	public var initZ:Float = 0;

	private var _lastPlayedAnimation:String = "";

	public var danced:Bool = false;

	public var danceEveryNumBeats:Int = 2;

	private var settingCharacterUp:Bool = true;

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false) {
		super(x, y);

		animation = new PsychAnimationController(this);

		animOffsets = new Map<String, Array<Dynamic>>();
		this.isPlayer = isPlayer;
		changeCharacter(character);

		switch (curCharacter) {
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
			case 'pico-blazin', 'darnell-blazin':
				skipDance = true;
		}
	}

	// ---------------- Character Loading ----------------
	public function changeCharacter(character:String) {
		animationsArray = [];
		animOffsets = [];
		curCharacter = character;

		var characterPath:String = 'characters/$character.json';
		var path:String = Paths.getPath(characterPath, TEXT);

		#if MODS_ALLOWED
		if (!sys.FileSystem.exists(path))
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
			loadCharacterFile(Json.parse(sys.io.File.getContent(path)));
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

	public function loadCharacterFile(json:Dynamic) {
		// Detect models from JSON (optional)
		if ((Reflect.hasField(json, "isModel") && json.isModel == true)
			|| Reflect.hasField(json, "modelName")
			|| Reflect.hasField(json, "modelType")) {
			isModel = true;
			modelType = Reflect.hasField(json, "modelType") ? json.modelType : "md2";
			modelName = Reflect.hasField(json, "modelName") ? json.modelName : json.image;

			modelScale = Reflect.hasField(json, "modelScale") ? json.modelScale : (Reflect.hasField(json, "scale") ? json.scale : 1);
			initYaw = Reflect.hasField(json, "initYaw") ? json.initYaw : 0;
			initPitch = Reflect.hasField(json, "initPitch") ? json.initPitch : 0;
			initRoll = Reflect.hasField(json, "initRoll") ? json.initRoll : 0;
			initX = Reflect.hasField(json, "initX") ? json.initX : 0;
			initY = Reflect.hasField(json, "initY") ? json.initY : 0;
			initZ = Reflect.hasField(json, "initZ") ? json.initZ : 0;

			noLoopList = Reflect.hasField(json, "noLoopList") ? cast json.noLoopList : [];
			md5Anims = Reflect.hasField(json, "md5Anims") ? cast json.md5Anims : new Map<String, String>();
			modelSpeed = Reflect.hasField(json, "modelSpeed") ? cast json.modelSpeed : new Map<String, Float>();

			setupModel();
			// show 3D snapshot on a FlxSprite so positioning works as usual
			if (Main.modelView != null && Main.modelView.sprite != null) {
				loadGraphicFromSprite(Main.modelView.sprite);
				updateHitbox();
			}
			// even when loading a model, still let the rest of JSON fill standard character fields below
		}

		// AnimateAtlas?
		isAnimateAtlas = false;
		#if flxanimate
		var animToFind:String = Paths.getPath('images/' + json.image + '/Animation.json', TEXT);
		if (#if MODS_ALLOWED sys.FileSystem.exists(animToFind) || #end Assets.exists(animToFind))
			isAnimateAtlas = true;
		#end

		scale.set(1, 1);
		updateHitbox();

		if (!isAnimateAtlas) {
			frames = Paths.getMultiAtlas(json.image.split(','));
		} else {
			#if flxanimate
			atlas = new FlxAnimate();
			atlas.showPivot = false;
			// NOTE: depends on Paths.loadAnimateAtlas expecting flxanimate.FlxAnimate
			Paths.loadAnimateAtlas(atlas, json.image);
			#end
		}

		// Core JSON props
		imageFile = json.image;
		jsonScale = json.scale;
		if (json.scale != 1) {
			scale.set(jsonScale, jsonScale);
			updateHitbox();
		}

		positionArray = json.position;
		cameraPosition = json.camera_position;

		healthIcon = json.healthicon;
		singDuration = json.sing_duration; // <- required by other classes

		flipX = (json.flip_x != isPlayer);
		healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];
		vocalsFile = json.vocals_file != null ? json.vocals_file : '';
		originalFlipX = (json.flip_x == true);
		editorIsPlayer = json._editor_isPlayer;

		noAntialiasing = (json.no_antialiasing == true);
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;
		if (animationsArray != null && animationsArray.length > 0) {
			for (anim in animationsArray) {
				var animAnim:String = '' + anim.anim;
				var animName:String = '' + anim.name;
				var animFps:Int = anim.fps;
				var animLoop:Bool = !!anim.loop;
				var animIndices:Array<Int> = anim.indices;

				if (!isAnimateAtlas) {
					if (animIndices != null && animIndices.length > 0)
						animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
					else
						animation.addByPrefix(animAnim, animName, animFps, animLoop);
				}
				#if flxanimate
				else {
					if (animIndices != null && animIndices.length > 0)
						atlas.anim.addBySymbolIndices(animAnim, animName, animIndices, animFps, animLoop);
					else
						atlas.anim.addBySymbol(animAnim, animName, animFps, animLoop);
				}
				#end

				if (anim.offsets != null && anim.offsets.length > 1)
					addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				else
					addOffset(anim.anim, 0, 0);
			}
		}
		#if flxanimate
		if (isAnimateAtlas)
			copyAtlasValues();
		#end
	}

	// ---------------- Update ----------------
	override function update(elapsed:Float) {
		#if flxanimate
		if (isAnimateAtlas && atlas != null)
			atlas.update(elapsed);
		#end

		// (matching expected behavior elsewhere in codebase)
		if (debugMode
			|| (!isAnimateAtlas && animation.curAnim == null)
			|| (isAnimateAtlas && (atlas == null || atlas.anim.curInstance == null || atlas.anim.curSymbol == null))) {
			super.update(elapsed);
			return;
		}

		if (heyTimer > 0) {
			var rate:Float = (PlayState.instance != null ? PlayState.instance.playbackRate : 1.0);
			heyTimer -= elapsed * rate;
			if (heyTimer <= 0) {
				var anim:String = getAnimationName();
				if (specialAnim && (anim == 'hey' || anim == 'cheer')) {
					specialAnim = false;
					dance();
				}
				heyTimer = 0;
			}
		} else if (specialAnim && isAnimationFinished()) {
			specialAnim = false;
			dance();
		} else if (getAnimationName().endsWith('miss') && isAnimationFinished()) {
			dance();
			finishAnimation();
		}

		if (getAnimationName().startsWith('sing'))
			holdTimer += elapsed;
		else if (isPlayer)
			holdTimer = 0;

		if (!isPlayer
			&& holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration) {
			dance();
			holdTimer = 0;
		}

		var nm = getAnimationName();
		if (isAnimationFinished() && hasAnimation('$nm-loop'))
			playAnim('$nm-loop');

		super.update(elapsed);
	}

	// ---------------- Small helpers used by other classes ----------------
	inline public function isAnimationNull():Bool {
		if (isModel)
			return model == null || model.currentAnim == null;
		#if flxanimate
		if (isAnimateAtlas)
			return atlas == null || atlas.anim.curInstance == null || atlas.anim.curSymbol == null;
		#end
		return animation.curAnim == null;
	}

	inline public function getAnimationName():String {
		return _lastPlayedAnimation;
	}

	public function isAnimationFinished():Bool {
		if (isAnimationNull())
			return false;
		#if flxanimate
		if (isAnimateAtlas)
			return atlas.anim.finished;
		#end
		return animation.curAnim.finished;
	}

	public function finishAnimation():Void {
		if (isAnimationNull())
			return;
		#if flxanimate
		if (isAnimateAtlas) {
			atlas.anim.curFrame = atlas.anim.length - 1;
			return;
		}
		#end
		animation.curAnim.finish();
	}

	public function hasAnimation(anim:String):Bool {
		// works for both frame & atlas because we fill animOffsets when we add animations
		return animOffsets.exists(anim);
	}

	public var animPaused(get, set):Bool;

	private function get_animPaused():Bool {
		if (isAnimationNull())
			return false;
		#if flxanimate
		if (isAnimateAtlas)
			return !atlas.anim.isPlaying;
		#end
		return animation.curAnim.paused;
	}

	private function set_animPaused(value:Bool):Bool {
		if (isAnimationNull())
			return value;
		#if flxanimate
		if (isAnimateAtlas) {
			// best-effort control; some forks only expose play/pause on anim
			if (value)
				atlas.anim.pause();
			else
				atlas.anim.resume();
			return value;
		}
		#end
		animation.curAnim.paused = value;
		return value;
	}

	// ---------------- Dances & playAnim ----------------
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix));

		if (settingCharacterUp) {
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		} else if (lastDanceIdle != danceIdle) {
			var calc:Float = danceEveryNumBeats;
			if (danceIdle)
				calc /= 2;
			else
				calc *= 2;
			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	public function dance() {
		if (!debugMode && !skipDance && !specialAnim) {
			if (danceIdle) {
				danced = !danced;
				if (danced)
					playAnim('danceRight' + idleSuffix);
				else
					playAnim('danceLeft' + idleSuffix);
			} else if (hasAnimation('idle' + idleSuffix))
				playAnim('idle' + idleSuffix);
		}
	}

	public function playAnim(name:String, force:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
		specialAnim = false;

		// 3D models
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

		// 2D
		#if flxanimate
		if (isAnimateAtlas) {
			atlas.anim.play(name, force, reversed, frame);
			atlas.update(0);
		} else
		#end
		{
			animation.play(name, force, reversed, frame);
		}
		_lastPlayedAnimation = name;

		if (hasAnimation(name)) {
			var daOffset = animOffsets.get(name);
			offset.set(daOffset[0], daOffset[1]);
		}

		// gf logic
		if (curCharacter.startsWith('gf-') || curCharacter == 'gf') {
			if (name == 'singLEFT')
				danced = true;
			else if (name == 'singRIGHT')
				danced = false;
			if (name == 'singUP' || name == 'singDOWN')
				danced = !danced;
		}
	}

	// ---------------- Offsets & quick add ----------------
	public function addOffset(name:String, x:Float = 0, y:Float = 0) {
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String) {
		animation.addByPrefix(name, anim, 24, false);
	}

	// ---------------- AnimateAtlas draw & copy ----------------
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

	// ---------------- Pico speaker mapping (no TankmenBG dependency) ----------------
	function loadMappedAnims():Void {
		try {
			var songData:SwagSong = Song.getChart('picospeaker', Paths.formatToSongPath(Song.loadedSongName));
			if (songData != null)
				for (section in songData.notes)
					for (songNotes in section.sectionNotes)
						animationNotes.push(songNotes);

			animationNotes.sort((a, b) -> FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]));
		} catch (e:Dynamic) {}
	}

	// ---------------- Model hookup ----------------
	function setupModel():Void {
		model = new ModelThing(modelType, // type
			modelName, // fileName
			Main.modelView, modelScale, modelSpeed, initYaw, initPitch, initRoll, 1.0, initX,
			initY, initZ, noLoopList, md5Anims);

		if (model != null && model.mesh != null && Main.modelView != null) {
			Main.modelView.addModel(model.mesh);
			Main.modelView.addedModels.push(model);
		}

		if (Main.modelView != null && Main.modelView.sprite != null) {
			loadGraphicFromSprite(Main.modelView.sprite);
			updateHitbox();
		}
	}
}
