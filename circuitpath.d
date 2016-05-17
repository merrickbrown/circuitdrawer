module circuitpath;

struct VarPoint(T) {
	alias VPoint = VarPoint!T;

	T _x, _y;

	T x() @property {return _x;}
	T y() @property {return _y;}

	VPoint n() @property {return VPoint(  x, y+1);}
	VPoint e() @property {return VPoint(x+1, y  );}
	VPoint w() @property {return VPoint(x-1, y  );}
	VPoint s() @property {return VPoint(  x, y-1);}

	VPoint ne() @property {return n.e;}
	VPoint se() @property {return s.e;}
	VPoint nw() @property {return n.w;}
	VPoint sw() @property {return s.w;}

	VPoint[8] neighboring() @property { return [e,ne,n,nw,w,sw,s,se];}

	string toString() {
		import std.conv : to;
		return "(" ~ to!string(x) ~ "," ~ to!string(y) ~ ")";
	}

	//bool opEquals()(auto ref const VPoint p) const { return p.x == x && p.y == y;}

}
alias CoordType = int;
alias Point = VarPoint!(CoordType);
enum CellType {EMPTY , JUNCTION, WIRE }

struct Grid {

	CellType[Point] _grid;
	size_t height, width;

	bool inGrid(Point p) {
		return 0 <= p.x && p.x < width && 0 <= p.y && p.y < height;
	}

	auto at(Point p) { return _grid[p]; }

	void setPoint(CellType t, Point p) {_grid[p] = t;}

	auto neighbors(Point p) {
		Point[] result;
		bool yes(Point a) {return inGrid(a) && _grid[a] == CellType.EMPTY;}
		if (yes(p.ne)) {
			if (yes(p.n) || yes(p.e)) {result ~= p.ne;}
		}
		if (yes(p.se)) {
			if (yes(p.s) || yes(p.e)) {result ~= p.se;}
		}
		if (yes(p.nw)) {
			if (yes(p.n) || yes(p.w)) {result ~= p.nw;}
		}
		if (yes(p.sw)) {
			if (yes(p.s) || yes(p.w)) {result ~= p.sw;}
		}
		if (yes(p.n)) {result ~= p.n;}
		if (yes(p.e)) {result ~= p.e;}
		if (yes(p.s)) {result ~= p.s;}
		if (yes(p.w)) {result ~= p.w;}
		return result;
	}

	float h(Point from, Point to) {
		//import std.math : abs, SQRT2;
		//import std.algorithm : min, max;
		//float deltax = to.x - from.x;
		//float deltay = to.y - from.y;
		//return 0.99999*((SQRT2-1)*min(abs(deltax),abs(deltay)) + max(abs(deltax), abs(deltay)));
		return distance(from, to);
	}

	float preference(Point* prev, Point curr, Point next) {
/*		bool nsewfrom = false;
		bool nsewto = false;
		if (prev is null) {return 0;}
		if (prev.n == curr || prev.e == curr || prev.s == curr || prev.w == curr) {
			nsewfrom = true;
		}
		if (curr.n == next || curr.e == next || curr.s == next || curr.w == next) {
			nsewto = true;
		}
		if (nsewfrom != nsewto) {return 0.1;}
		else return 0;
*/
		if ( (prev is null) ||
			(prev.n == curr && curr.n == next) ||
			(prev.e == curr && curr.e == next) ||
			(prev.s == curr && curr.s == next) ||
			(prev.w == curr && curr.w == next) ||
			(prev.ne == curr && curr.ne == next) ||
			(prev.se == curr && curr.se == next) ||
			(prev.nw == curr && curr.nw == next) ||
			(prev.sw == curr && curr.sw == next)
			) {return 0;}
		else {return 0.1;}
	}

	float distance(Point a, Point b) {
		import std.math : sqrt;
		import std.conv : to;
		return sqrt(to!float((a.x - b.x)^^2 + (a.y - b.y)^^2)); 
	}


	Point[] minPath(Point begin, Point end) {
		import std.container: BinaryHeap, heapify, Array;
		Point[Point] evaluatedCells;
		float[Point] g_score;
		float[Point] f_score;
		Point[Point] prevMap;

		struct FSPoint {
			Point p;
			float f_score;

			int opCmp(ref const FSPoint rhs) const {return (f_score - rhs.f_score > 0) ? 1 : -1;}
		} 

		Array!(FSPoint) startarray = [FSPoint(begin, h(begin,end))];
		Point[Point] underlyingtoCheck;
		auto toCheck = heapify!("a > b", Array!(FSPoint))(startarray, 1);
		toCheck.acquire(startarray);
		underlyingtoCheck[begin] = begin;
		g_score[begin] = 0.0;

		while (!toCheck.empty) {
			auto fscurrent = toCheck.front;
			auto current = fscurrent.p; 
			//import std.stdio : writeln;
			//writeln(neighbors(current));
			if (current == end) {return reconstructpath(prevMap, end);}
			evaluatedCells[current] = current;
			toCheck.popFront;
			underlyingtoCheck.remove(current);

			foreach(neighbor; neighbors(current)) {
				if (neighbor in evaluatedCells) {continue;}
				auto temp_g_score = g_score[current] + distance(current, neighbor) + preference(current in prevMap,current, neighbor);
				if (((neighbor in underlyingtoCheck) is null) || temp_g_score < g_score[neighbor]) {
					prevMap[neighbor] = current;
					g_score[neighbor] = temp_g_score;
					auto fsneighbor = FSPoint(neighbor, g_score[neighbor] + h(neighbor, end));
					if (!(neighbor in underlyingtoCheck)) {
						toCheck.insert(fsneighbor);
						underlyingtoCheck[neighbor] = neighbor;
					}
				}
			}
		}
		return [];
	}

	this(size_t iwidth, size_t iheight) {
		width = iwidth;
		height = iheight;
		CoordType ix,jy = 0;
		while(ix < width && jy < height) {
			_grid[Point(ix,jy)] = CellType.EMPTY;
			ix++;
			if (jy < height && ix == width) {
				jy++;
				ix = 0;
			}
		}
	}

	void blockPath(Point[] path) {
		if (path.length == 0 ) return;
		foreach(i, p ; path) {
			_grid[p] = CellType.WIRE;
		}
		_grid[path[0]] = CellType.JUNCTION;
		_grid[path[$-1]] = CellType.JUNCTION;
	}

	string toString() {
		dchar[] result;
		result.length = height*(width+1);
		foreach(key, val ; _grid) {
			dchar t = ' ';
			switch (val) {
				case CellType.JUNCTION :
				t = 'X';
				break;
				case CellType.WIRE :
				t = '*';
				break;
				default :
				break; 
			}
			result[key.x + (width+1)*key.y] = t;
		}
		for(size_t h = 0; h < height; h++) {result[width + h*(width+1)] = '\n';}
		import std.conv : toImpl;
		return toImpl!(string, dchar[])(result); 
	}
}

private auto reconstructpath(Point[Point] prevMap, Point end) {
	auto prev = prevMap[end];
	Point[] path = [end];
	while (prev in prevMap) {
		path ~= prev;
		prev = prevMap[prev];
	}
	path ~= prev;
	return path.reverse;
}
/*
void main() {
	import std.stdio : writeln;
	import std.random : uniform;
	auto mygrid = Grid(32,32);
	size_t rx1, rx2, ry1, ry2;
	for(int i = 0; i < 15; i++) {
		do {
			rx1 = uniform(2,30);
			ry1 = uniform(2,30);
		} while (mygrid._grid[Point(rx1,ry1)] != CellType.EMPTY);
		do {
			rx2 = uniform(2,30);
			ry2 = uniform(2,30);
		} while (mygrid._grid[Point(rx2,ry2)] != CellType.EMPTY);
		auto path = mygrid.minPath(Point(rx1, ry1), Point(rx2, ry2));
		if (path.length > 0) {mygrid.blockPath(path); writeln(mygrid);}
		else {i--;}
	}
	mygrid.blockPath(mygrid.minPath(Point(2,2),Point(31,19)));
	mygrid.blockPath(mygrid.minPath(Point(2,3),Point(30,23)));
	mygrid.blockPath(mygrid.minPath(Point(2,4),Point(29,24)));
	mygrid.blockPath(mygrid.minPath(Point(2,5),Point(30,31)));
	mygrid.blockPath(mygrid.minPath(Point(2,6),Point(15,31)));
	mygrid.blockPath(mygrid.minPath(Point(2,30),Point(30,2)));
	writeln(mygrid);
}*/