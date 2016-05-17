import std.typecons;
import std.stdio : writeln;
import std.conv : to;

import gfm.sdl2;
import derelict.sdl2.sdl;

import utils;
import circuitpath;


enum {DEFAULT_HEIGHT  = 640, DEFAULT_WIDTH = 640}
enum {DEFAULT_WINDOW_FLAGS = SDL_WINDOW_SHOWN}
enum TILE_SIZE = 64;
enum Filenames {ELEMENTS = "elements.png"}
enum MSECS_PER_ANIMFRAME = 1000/10;
enum State {ZERO_SET = 0, ONE_SET = 1, TWO_SET = 2};
enum Element {E = 0, NE=1, N=2, NW=3, W=4, SW=5, S=6, SE=7, ELT_EMPTY, ELT_JUNCTION}

Element elementOf(int x, int y) {
	switch (x) {
		case -1 :
		switch (y) {
			case -1 :
			return Element.SW;
			case 0 :
			return Element.W;
			case 1 :
			return Element.NW;
			default :
			assert(0, "bad input");
		}
		case 0 :
		switch (y) {
			case -1 :
			return Element.S;
			case 0 :
			return Element.ELT_EMPTY;
			case 1 :
			return Element.N;
			default :
			assert(0, "bad input");
		}
		case 1 :
		switch (y) {
			case -1 :
			return Element.SE;
			case 0 :
			return Element.E;
			case 1 :
			return Element.NE;
			default :
			assert(0, "bad input");
		}
		default :
		assert(0, "bad input");
	}
} 

//Element[2] elementPair(Point* prev, Point curr, Point* next) {
//	if (prev is null && next is null) return [Element.ELT_EMPTY, Element.ELT_EMPTY];
//	if (prev is null) {
//		return [Element.ELT_JUNCTION, elementOf(next.x - curr.x, next.y - curr.y)];
//	}
//	if (next is null) {
//		return [elementOf(curr.x - prev.x, curr.y - prev.y), Element.ELT_JUNCTION];
//	}
//	return [elementOf(curr.x - prev.x, curr.y - prev.y),elementOf(next.x - curr.x, next.y - curr.y)];
//} 


class Game {

	bool isrunning = false;
	SDL2 sdl2instance = null;
	SDLImage imageloader = null;
	Blitter elements;
	SDL2Window mainwindow = null;
	SDL2Renderer renderer = null;
	Blocker!("usecs") speedlimiter;
	Grid canvas;
	Point[][] paths;
	Point begin;
	Point end;
	State state;


	void addPath(Point[] path) {
		if (path.length > 0) 
		{
				paths ~= path;
				canvas.blockPath(path);
		}
	}

	void renderPath(Point[] path) {
		if (path.length > 1) 
		{
			for(int i = 0; i < path.length-1; i++) {
				auto curr = path[i];
				auto next = path[i+1];
				auto desta = SDL_Rect(TILE_SIZE*curr.x-TILE_SIZE/2, 
									 TILE_SIZE*curr.y-TILE_SIZE/2, 
									 2*TILE_SIZE, 2*TILE_SIZE);
				auto destb = SDL_Rect(TILE_SIZE*next.x-TILE_SIZE/2, 
									 TILE_SIZE*next.y-TILE_SIZE/2, 
									 2*TILE_SIZE, 2*TILE_SIZE);
				int dx = next.x - curr.x;
				int dy = next.y - curr.y;
				elements.render(elementOf(dx,-dy), desta);
				elements.render(elementOf(-dx,dy), destb);
			}
		} else {
			auto dest = SDL_Rect(TILE_SIZE*path[0].x-TILE_SIZE/2, 
									 TILE_SIZE*path[0].y-TILE_SIZE/2, 
									 2*TILE_SIZE, 2*TILE_SIZE);
			elements.render(Element.ELT_JUNCTION, dest);
		}
	}



	void clear() {
		canvas = Grid(DEFAULT_WIDTH/TILE_SIZE, DEFAULT_HEIGHT/TILE_SIZE);
		state = State.ZERO_SET;
		paths.length = 0;
		renderer.clear();
	}

	int onExecute() {
		if (!initialize()) {
			return -1; 
		} else {

			SDL_Event event;

			while(isrunning) 
			{
				while(sdl2instance.pollEvent(&event)) {
					onEvent(&event);
				}
				onLoop();
				onRender();
			}

			cleanup();

			return 0;
		}
	}

	bool initialize() {
		if (isrunning) {return false;}
		else {
			writeln("Initializing:");
			// initialize SDL2
			sdl2instance = new SDL2(null); //null means no logger
			sdl2instance.subSystemInit(SDL_INIT_VIDEO);
			imageloader = new SDLImage(sdl2instance);

			writeln("SDL2 loaded");

			mainwindow = fibwindow(sdl2instance, DEFAULT_WIDTH, DEFAULT_HEIGHT, DEFAULT_WINDOW_FLAGS);
			renderer = new SDL2Renderer(mainwindow);
			if (renderer is null) {
				throw new SDL2Exception("Renderer not loaded");
			}
			writeln("Renderer loaded");
			elements = Blitter(sdl2instance, renderer, imageloader, Filenames.ELEMENTS);
			elements.addTiles(10,1);
			writeln("Bitmaps loaded");
			elements._texture.setBlendMode(SDL_BLENDMODE_BLEND);
			renderer.setColor(255,255,255);
			renderer.clear();

			canvas = Grid(DEFAULT_WIDTH/TILE_SIZE, DEFAULT_HEIGHT/TILE_SIZE);

			isrunning = true;
			speedlimiter = new Blocker!("usecs")(1000000/60);
			return true;
		}
	}
	void onEvent(SDL_Event* event) {
		switch (event.type)
		{
//Quit event:
	//user-requested quit
			case SDL_QUIT :
			isrunning = false;
			break;
//Window events:
	//window state change
			case SDL_WINDOWEVENT :
			switch (event.window.event) 
			{
				case SDL_WINDOWEVENT_CLOSE :
				isrunning = false;
				break;
				default :
				break;
			}
			break;
	//system specific event
			case SDL_SYSWMEVENT :

			break;
//Keyboard events:
	//key pressed
			case SDL_KEYDOWN :
	//key released
			case SDL_KEYUP :
			if (event.key.state == SDL_RELEASED) {
				clear();
			}
			break;
	//keyboard text editing (composition)
			case SDL_TEXTEDITING :

			break;
	//keyboard text input
			case SDL_TEXTINPUT :

			break;
//Mouse events:
	//mouse moved
			case SDL_MOUSEMOTION :

			break;
	//mouse button pressed
			case SDL_MOUSEBUTTONDOWN :

			break;
	//mouse button released
			case SDL_MOUSEBUTTONUP :
			if (event.button.button == SDL_BUTTON_LEFT && state != State.TWO_SET) {
				Point p = Point(tilex(sdl2instance.mouse().x()), tiley(sdl2instance.mouse().y()));
				switch(canvas._grid[p]) {
					case CellType.EMPTY :
					switch (state) {
						case State.ZERO_SET :
						begin = p;
						state = State.ONE_SET;
						break;
						case State.ONE_SET :
						if (p == begin) {
							state = State.ZERO_SET;
							renderer.clear();
						} else {
							end = p;
							state = State.TWO_SET;
						}
						break;
						case State.TWO_SET :
						break;
						default :
						break;
					}
					break;
					case CellType.JUNCTION :
					case CellType.WIRE :
					default :
					break;
				}
			}

			break;
	//mouse wheel motion
			case SDL_MOUSEWHEEL :

			break;
//Joystick events:
	//joystick axis motion
			case SDL_JOYAXISMOTION :

			break;
	//joystick trackball motion
			case SDL_JOYBALLMOTION :

			break;
	//joystick hat position change
			case SDL_JOYHATMOTION :

			break;
	//joystick button pressed
			case SDL_JOYBUTTONDOWN :

			break;
	//joystick button released
			case SDL_JOYBUTTONUP :

			break;
	//joystick connected
			case SDL_JOYDEVICEADDED :

			break;
	//joystick disconnected
			case SDL_JOYDEVICEREMOVED :

			break;
//Controller events:
	//controller axis motion
			case SDL_CONTROLLERAXISMOTION :

			break;
	//controller button pressed
			case SDL_CONTROLLERBUTTONDOWN :

			break;
	//controller button released
			case SDL_CONTROLLERBUTTONUP :

			break;
	//controller connected
			case SDL_CONTROLLERDEVICEADDED :

			break;
	//controller disconnected
			case SDL_CONTROLLERDEVICEREMOVED :

			break;
	//controller mapping updated
			case SDL_CONTROLLERDEVICEREMAPPED :

			break;
//Touch events:
	//user has touched input device
			case SDL_FINGERDOWN :

			break;
	//user stopped touching input device
			case SDL_FINGERUP :

			break;
	//user is dragging finger on input device
			case SDL_FINGERMOTION :

			break;
//Gesture events:
			case SDL_DOLLARGESTURE :

			break;
			case SDL_DOLLARRECORD :

			break;
			case SDL_MULTIGESTURE :

			break;
//Clipboard events:
	//the clipboard changed
			case SDL_CLIPBOARDUPDATE :

			break;
//Drag and drop events:
	//the system requests a file open
			case SDL_DROPFILE :

			break;
//End of event.type switch
		default :
		import std.stdio : stderr, writefln;
		stderr.writefln("Unknown SDL_Event type: %0#4x",event.type);
		break;
		}
	}

	void onLoop() {
		if (state == State.TWO_SET) {
			auto p = canvas.minPath(begin,end);
			if (p.length > 0)
			{ 
				addPath(canvas.minPath(begin,end));
				canvas._grid[begin] = CellType.JUNCTION;
				canvas._grid[end] = CellType.JUNCTION;
				state = State.ZERO_SET;
				} else {
					state = State.ZERO_SET;
				}
		}
		speedlimiter.block();
	}

	void onRender() {
		if (state == State.ONE_SET || state == State.TWO_SET) {
			auto destb = SDL_Rect(TILE_SIZE*begin.x-TILE_SIZE/2, 
								  TILE_SIZE*begin.y-TILE_SIZE/2, 
								  2*TILE_SIZE, 2*TILE_SIZE);
			elements.render(9, destb);
		}
		if (state == State.TWO_SET) {
			auto deste = SDL_Rect(TILE_SIZE*end.x - TILE_SIZE/2, 
								  TILE_SIZE*end.y - TILE_SIZE/2, 
								  2*TILE_SIZE, 
								  2*TILE_SIZE);
			elements.render(9, deste);
		}
		foreach(p; paths) {
			renderPath(p);
		}
		foreach(p, t; canvas._grid) {
			if (t == CellType.JUNCTION) {
				auto dest = SDL_Rect(TILE_SIZE*p.x - TILE_SIZE/2, 
									 TILE_SIZE*p.y - TILE_SIZE/2, 
									 2*TILE_SIZE, 
									 2*TILE_SIZE);
				elements.render(9,dest);
			}
		}

		renderer.present();
	}
	
	void cleanup() {
		writeln("Cleaning up:");
		imageloader.close();
		writeln("SDLImage closed");
		elements.close();
		writeln("glyphs closed");
		renderer.close();
		writeln("renderer closed");
		mainwindow.close();
		writeln("mainwindow closed");
		sdl2instance.close();
		writeln("sdl2instance closed");
	}

	int tilex(int relx) {
		return relx / TILE_SIZE;		
	}

	int tiley(int rely) {
		return rely / TILE_SIZE;
	}

}


// MMMM GOLDEN RATIO HEADSPACE
auto fibwindow(SDL2 sdl2inst, int width, int height, int flags) {
	return new SDL2Window(sdl2inst, 
						  sdl2inst.firstDisplaySize().x/2 - width/2, 
						  13*(sdl2inst.firstDisplaySize().y-height)/34, 
						  width, 
						  height, 
						  flags
						 );
}


int main() {

	import std.stdio : writeln;
	Game mainGame = new Game();
	int endcode = mainGame.onExecute();
	writeln("QUIT");
	return endcode;
}