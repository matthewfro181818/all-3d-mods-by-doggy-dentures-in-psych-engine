package;

import flixel.FlxSprite;
import away3d.containers.View3D;
import away3d.controllers.HoverController;
import away3d.lights.DirectionalLight;
import away3d.materials.lightpickers.StaticLightPicker;
import away3d.materials.methods.FilteredShadowMapMethod;
import openfl.display.BitmapData;
import openfl.geom.Vector3D;

class ModelView extends FlxSprite
{
	public var view:View3D;
	public var cameraController:HoverController;
	public var light:DirectionalLight;
	public var lightPicker:StaticLightPicker;
	public var shadowMapMethod:FilteredShadowMapMethod;

	private var bmd:BitmapData;
	private var _lookAtPosition:Vector3D = new Vector3D();

	public function new()
	{
		super();

		view = new View3D();
		view.width = 720;
		view.height = 720;

		// Camera setup
		view.camera.lens.far = 5000;
		cameraController = new HoverController(view.camera, null, 90, 0, 300);
		cameraController.lookAtPosition = _lookAtPosition;

		// Lighting
		light = new DirectionalLight(-0.5, -1, -1);
		light.ambient = 1;
		light.specular = 1;
		light.diffuse = 1;
		view.scene.addChild(light);

		lightPicker = new StaticLightPicker([light]);
		shadowMapMethod = new FilteredShadowMapMethod(light);

		// BitmapData to render into
		bmd = new BitmapData(Std.int(view.width), Std.int(view.height), true, 0x0);
		loadGraphic(bmd);
	}

	public function updateView():Void
	{
		if (view == null) return;

		view.backgroundAlpha = 0;
		view.renderer.queueSnapshot(bmd);
		view.render();
		view.backgroundAlpha = 1;

		loadGraphic(bmd);
		if (graphic != null) graphic.persist = true;
	}

	public function addModel(model:away3d.entities.Mesh)
	{
		if (view != null) view.scene.addChild(model);
	}

	public function clear()
	{
		if (view == null) return;
		while (view.scene.numChildren > 0)
		{
			view.scene.removeChildAt(0);
		}
	}
}
