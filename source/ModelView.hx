package;

import sys.io.FileOutput;
import flixel.FlxSprite;
import flixel.FlxG;
import away3d.containers.*;
import away3d.controllers.*;
import away3d.entities.*;
import away3d.lights.*;
import away3d.loaders.parsers.*;
import away3d.materials.*;
import away3d.materials.lightpickers.*;
import away3d.materials.methods.*;
import away3d.utils.Cast;
import openfl.display.*;
import openfl.geom.*;
import openfl.utils.ByteArray;
import openfl.Assets;

class ModelView {
	public var view:View3D;
	public var cameraController:HoverController;

	private var _lookAtPosition:Vector3D = new Vector3D();

	public var light:DirectionalLight;
	public var lightPicker:StaticLightPicker;
	public var shadowMapMethod:FilteredShadowMapMethod;

	private var bmd:BitmapData;
	public var sprite:FlxSprite = new FlxSprite();

	public var addedModels:Array<ModelThing> = [];

	public function new() {
		view = new View3D();
		view.width = 720;
		view.height = 720;

		FlxG.addChildBelowMouse(view);

		view.camera.lens.far = 5000;
		cameraController = new HoverController(view.camera, null, 90, 0, 300);
		cameraController.lookAtPosition = _lookAtPosition;

		light = new DirectionalLight(-0.5, -1, -1);
		lightPicker = new StaticLightPicker([light]);
		view.scene.addChild(light);
		light.ambient = 1;
		light.specular = 1;
		light.diffuse = 1;

		shadowMapMethod = new FilteredShadowMapMethod(light);

		bmd = new BitmapData(Std.int(view.width), Std.int(view.height), true, 0x0);
		sprite.loadGraphic(bmd);
	}

	public function update() {
		view.backgroundAlpha = 0;
		view.renderer.queueSnapshot(bmd);
		view.render();
		view.backgroundAlpha = 1;

		sprite.loadGraphic(bmd);
		sprite.graphic.persist = true;
	}

	public function addModel(model:Mesh) {
		view.scene.addChild(model);
	}

	public function clear() {
		var toRemove:Array<ObjectContainer3D> = [];
		for (i in 0...view.scene.numChildren) {
			var c = view.scene.getChildAt(i);
			if (c != null) toRemove.push(c);
		}
		for (c in toRemove) view.scene.removeChild(c);
	}
}
