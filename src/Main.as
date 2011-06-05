package 
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.utils.getTimer;
	
	import Box2D.Dynamics.*;
	import Box2D.Collision.*;
	import Box2D.Collision.Shapes.*;
	import Box2D.Common.Math.*;
	
	/**
	 * ...
	 * @author Yadu Rajiv
	 */
	public class Main extends Sprite 
	{
		
		private var _world:b2World;
		private var _debugDrawSprite:Sprite;
		
		private var _friction:Number = 0.8;
		private var _restitution:Number = 0.3;
		private var _density:Number = 0.7;
		private var _ratio:Number = 30; //1m : 30px
		
		private var _mouseLastX:Number;
		private var _mouseLastY:Number;
		
		private var _endX:Number;
		private var _endY:Number;
		
		private var _mouseDown:Boolean;
		
		private var _gfxTmp:Sprite;
		
		private var _currentInk:uint;
		private var _drawAlpha:Number;
        private var _borderColor:uint;
        private var _borderSize:uint;
		
		private var _objPoints:Array;
		
		private var _pixel_dist:Number = 20;
		
		private var _polyWidth:Number = 0;
		private var _polyHeight:Number = 0;
		
		private var _groundBodyDef:b2BodyDef;
		private var _groundObj:b2Body;
		
		private var _elapsed:Number;
		private var _endTime:Number;
		
		private var triangulate:Triangulate = new Triangulate();
		
		public function Main():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
			
		}
		
		private function init(e:Event = null):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			// entry point
			
			/**
			 * init world
			 */
			var gravity:b2Vec2 = new b2Vec2(0, 9.8);
			_world = new b2World(gravity, true)
			
			/**
			 * setup debug draw
			 */
			_debugDrawSprite = new Sprite()
			addChild(_debugDrawSprite);
			
			var debugDraw:b2DebugDraw = new b2DebugDraw();
			debugDraw.SetSprite(_debugDrawSprite);
			debugDraw.SetDrawScale(_ratio);
			debugDraw.SetFillAlpha(0.8);
			debugDraw.SetLineThickness(1.0);
			debugDraw.SetFlags(b2DebugDraw.e_shapeBit | b2DebugDraw.e_jointBit | b2DebugDraw.e_centerOfMassBit);
			_world.SetDebugDraw(debugDraw);
			
			/**
			 * setup some ground to fall on
			 * 640 is the width and 100 is the height
			 */
			var boxShape:b2PolygonShape = new b2PolygonShape();
			boxShape.SetAsBox((640 / 2) / _ratio, (100 / 2) / _ratio);
			
			var fixDef:b2FixtureDef = new b2FixtureDef();
			fixDef.density = _density;
			fixDef.restitution = _restitution;
			fixDef.friction = _friction;
			fixDef.shape = boxShape;
			
			_groundBodyDef = new b2BodyDef();
			_groundBodyDef.position.Set((0 + (640 / 2)) / _ratio, (400 + (100 / 2)) / _ratio);
			_groundBodyDef.type = b2Body.b2_staticBody;
			
			_groundObj = _world.CreateBody(_groundBodyDef);
			_groundObj.CreateFixture(fixDef);
			
			/**
			 * reset timer to calculate time elapsed
			 */
			_endTime = getTimer();
			
			/**
			 * render callback for each frame
			 */
			addEventListener(Event.ENTER_FRAME, render);
			
			/**
			 * default drawing options
			 */
			_currentInk = 0x000000;
			_drawAlpha = 1;
			_borderColor = 0x333333;
			_borderSize = 4;
			
			/**
			 * register mouse event callbacks
			 */
			stage.addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
			stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseMove);
			stage.addEventListener(MouseEvent.MOUSE_UP, mouseUp);
		}
		
		public function render(event:Event):void {
			/**
			 * update world and draw
			 */
			_elapsed = (getTimer() - _endTime)/1000;
			_world.Step(_elapsed, 10, 10);
			_world.ClearForces();
			
			
			/**
			 * remove sleeping bodies if any
			 */
			var tmpBody:b2Body = _world.GetBodyList();
			while (tmpBody != null) {
				if (!tmpBody.IsAwake() && tmpBody.GetType() == b2Body.b2_dynamicBody) {
					_world.DestroyBody(tmpBody);
				}
				tmpBody = tmpBody.GetNext();
			}
			
			// draw 
			_world.DrawDebugData();
			
			_endTime = getTimer();
			
		}
		
		public function mouseDown(event:MouseEvent):void {
			
				_polyWidth = _endX  = _mouseLastX = event.stageX;
				_polyHeight = _endY  = _mouseLastY = event.stageY;
				
				/**
				 * create a new sprite to do a temp on screen drawing
				 */
				_gfxTmp = new Sprite();
				
				/**
				 * line style start to draw and set position of cursor to 
				 * current screen x and y.
				 */
				_gfxTmp.graphics.beginFill(_currentInk, _drawAlpha);
				_gfxTmp.graphics.lineStyle(_borderSize, _borderColor, _drawAlpha);
				_gfxTmp.graphics.moveTo(_mouseLastX, _mouseLastY);
				
				/**
				 * re-create the array to store actual screen cords and
				 * the first x and y are pushed in as a flash.geom.Point
				 */
				_objPoints = new Array();
				_objPoints.push(new Point(_mouseLastX, _mouseLastY));
				
				/**
				 * add temp sprite to screen for everyone to see
				 */
				addChild(_gfxTmp);
		}
		
		public function mouseMove(event:MouseEvent):void {
			/**
			 * Code taken from example given by Emanuele Feronato
			 * http://www.emanueleferonato.com/2009/12/29/way-of-an-idea-box2d-prototype/#more-2131
			 */
			var dist_x:int = event.stageX -_mouseLastX;
			var dist_y:int = event.stageY -_mouseLastY;

			/**
			 * we calculate the distance from our last point to our current
			 * position, and if it is bigger than the limit we imposed at
			 * 'pixel_dist = 20'(20pixels) then plot to the current x and y
			 */
			if (dist_x*dist_x+dist_y*dist_y>_pixel_dist*_pixel_dist) {
				
				/**
				 * plot line using current x and y
				 */
				_gfxTmp.graphics.lineTo(event.stageX, event.stageY);
				
				/**
				 * push position, actual position in the world and not screen position,
				 * to an array to be used later
				 */
				_objPoints.push(new Point(event.stageX, event.stageY));
				
				/**
				 * saving last mouse position
				 */
				_mouseLastX = event.stageX;
				_mouseLastY = event.stageY;
				
				/**
				 * saving the top x and y positions to calculate width and height
				 */
				if (event.stageX < 0 && _polyWidth <=0) {
					if(_polyWidth < event.stageX) {
						_polyWidth = event.stageX;
					}
				} else {
					if(_polyWidth < event.stageX) {
						_polyWidth = event.stageX;
					}
				}
				
				if (event.stageY < 0 && _polyHeight <=0) {
					if(_polyHeight < event.stageY) {
						_polyHeight = event.stageY;
					}
				} else { 
					if(_polyHeight < event.stageY) {
						_polyHeight = event.stageY;
					}
				}
				
				/**
				 * your actual endx and y are going to be somewhere else other
				 * than where you actually started, if you move your mouse up
				 * or to the back from your actual starting point. so you need
				 * to change them and store them to find out the actual x and y 
				 * of your object
				 */
				if (_endX > event.stageX) {
					_endX =  event.stageX;
				}						
				
				if (_endY > event.stageY) {
					_endY = event.stageY;
				}
			}
						
		}
		
		public function mouseUp(event:MouseEvent):void {
			/**
			 * finish drawing the graphics
			 */
			_gfxTmp.graphics.endFill();

			/**
			 * width and height of the polygon
			 */
			_polyWidth = Math.abs(_polyWidth - _endX) + _borderSize;
			_polyHeight = Math.abs(_polyHeight - _endY) + _borderSize;

			/**
			 * Remove temporary sprite drawn on screen
			 */
			removeChild(_gfxTmp);
			
			/**
			 * creating the body
			 */
			try {
				
				/**
				 * our x any y minus the border
				 */
				_endX = _endX - _borderSize / 2;
				_endY =  _endY - _borderSize / 2;
				
				/**
				 * center of the polygon
				 */
				var cx:Number = _endX + (_polyWidth / 2);
				var cy:Number = _endY + (_polyHeight / 2);
				
				var scaledPoints:Array = new Array();
				/**
				 * scaling the points relative to its center and storing them as a b2Vec2
				 */
				for (var i:uint = 0; i < _objPoints.length; i++) {
					scaledPoints.push(new b2Vec2( (_objPoints[i].x - cx) / _ratio, (_objPoints[i].y - cy) / _ratio) );
				}
				
				var complex:Boolean = false;
				var boxShape:b2PolygonShape = new b2PolygonShape();
				
				/**
				 * if its clockwise then we reverse it
				 */
				if (Bourke.ClockWise(scaledPoints) == Bourke.CLOCKWISE) {
					scaledPoints.reverse();
				}
				
				/**
				 * if its concave then we flag it 
				 */
				if (Bourke.Convex(scaledPoints) == Bourke.CONCAVE) {
					complex = true;
				}
				
				
				var fixDef:b2FixtureDef;
				var bodyDef:b2BodyDef = new b2BodyDef();
				bodyDef.position.Set(cx/_ratio, cy/_ratio);
				bodyDef.type = b2Body.b2_dynamicBody;
				
				var obj:b2Body = _world.CreateBody(bodyDef);
				
				
				/**
				 * since its complex we try to triangulate else it throws an error and kills the body that was created
				 */
				if (complex) {
					var tmp:Array = triangulate.process(scaledPoints);
					
					if(tmp !=null) {
					
						for (i = 0; i < tmp.length; i = i + 3) {
							boxShape = new b2PolygonShape();
							boxShape.SetAsArray(new Array(tmp[i], tmp[i + 1], tmp[i + 2]));
							
							fixDef = new b2FixtureDef();
							fixDef.density = _density;
							fixDef.restitution = _restitution;
							fixDef.friction = _friction;
							fixDef.shape = boxShape;
							
							obj.CreateFixture(fixDef);
						} 
					} else {
						throw(new Error("null from Triangulate.process()"));
					}
					
				} else {
					
					boxShape.SetAsArray(scaledPoints,scaledPoints.length)
					
					fixDef = new b2FixtureDef();
					fixDef.density = _density;
					fixDef.restitution = _restitution;
					fixDef.friction = _friction;
					fixDef.shape = boxShape;
					
					obj.CreateFixture(fixDef);
				}
				
			} catch (err:Error) {
				trace(err.message);
				_world.DestroyBody(obj);
			}
		}
		
	}
	
}