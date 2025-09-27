package;

#if android
import android.content.Context;
#end

import debug.FPSCounter;
import flixel.FlxGame;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import openfl.Lib;
import lime.app.Application;
import states.TitleState;
import backend.Highscore;

#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import psychlua.HScript.HScriptInfos;
#end

#if (linux || mac)
import lime.graphics.Image;
#end

#if desktop
import backend.ALSoftConfig;
#end

#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

class Main extends Sprite
{
	public static final game = {
		width: 1280,
		height: 720,
		initialState: TitleState,
		framerate: 60,
		skipSplash: true,
		startFullscreen: false
	};

	public static var fpsVar:FPSCounter;
	public static var modelView:ModelView; // ✅ global 3D sprite

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();

		#if (cpp && windows)
		backend.Native.fixScaling();
		#end

		#if android
		Sys.setCwd(Path.addTrailingSlash(Context.getExternalFilesDir()));
		#elseif ios
		Sys.setCwd(lime.system.System.applicationStorageDirectory);
		#end

		// Create modelView early so it’s never null
		modelView = new ModelView();

		FlxG.save.bind('funkin', CoolUtil.getSavePath());
		Highscore.load();

		// Add the Flixel game
		addChild(new FlxGame(game.width, game.height, game.initialState,
			game.framerate, game.framerate, game.skipSplash, game.startFullscreen));

		#if !mobile
		fpsVar = new FPSCounter(10, 3, 0xFFFFFF);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		#end

		#if (linux || mac)
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
	}
}
