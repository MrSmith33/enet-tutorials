module serverlogic;

import std.container : DList;
import core.thread : Fiber;

import packets;

enum boardWidth = 6;
enum boardHeight = 9;
enum numRounds = 9;

struct Hex
{
	size_t playerId;
	uint numShips;
	uint systemLevel;
}

enum triPrimeX = 2;
enum triPrimeY = 3;

bool isTriPrime(size_t x, size_t y)
{
	return
		(y == 3 && x == 2) ||
		(y == 4 && (x == 2 || x == 3)) ||
		(y == 5 && x == 2);
}

// 6 x 9
struct GameBoard
{
	// 6
	private Hex[54] data;

	ref Hex triPrime() @property
	{
		return data[triPrimeX + triPrimeY * boardWidth];
	}

	ref Hex triPrime(Hex newData) @property
	{
		return data[triPrimeX + triPrimeY * boardWidth] = newData;
	}

	ref Hex opIndex(size_t x, size_t y)
	{
		// x < 6 on even row, x < 5 on odd row.
		assert(x < boardWidth - (y % 2));

		if (isTriPrime(x, y))
			return triPrime;

		return data[x + y * boardWidth];
	}

	ref Hex opIndexAssign(Hex newData, size_t x, size_t y)
	{
		// x < 6 on even row, x < 5 on odd row.
		assert(x < boardWidth - (y % 2));

		if (isTriPrime(x, y))
			return triPrime = newData;

		return data[x + y * boardWidth] = newData;
	}
}

struct Player
{
	Command[3] commands;
	Command[] remainingCommands;
	bool hasPlan;

	uint numberOfShips;
	uint score;
}

struct GameEvent
{
	//Player                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
}

struct EventQueue
{

}

struct Action
{

}

class ServerLogicFiber : Fiber
{
	DList!Action* queue;

	Action waitForAction()
	{
		import std.range : moveFront;
		if (queue.empty)
			Fiber.yield();
		return queue.moveFront;
	}

	this(DList!Action* queue)
	{
		this.queue = queue;
		super(&run);
	}

	// LOGIC

	void run()
	{
		GameBoard board;
		Player[] players;

		board = boardGen();
		start(board);
		setup();
		rounds();
		endGame();
	}

	GameBoard boardGen()
	{
		import std.random : randomShuffle, dice;

		GameBoard board;

		board.triPrime.systemLevel = 3;

		alias BorderSector = uint[5];

		BorderSector[6] borders =
		[
			[2,0,1,0,1],
			[1,0,1,2,0],
			[1,1,0,0,2],
			[0,0,2,1,1],
			[1,0,2,1,0],
			[1,1,2,0,0],
		];

		randomShuffle(borders[]);

		// place top hexes
		foreach(i; 0..3)
		{
			board[i*2, 0].systemLevel = borders[i][0];
			board[i*2 + 1, 0].systemLevel = borders[i][1];
			board[i*2, 1].systemLevel = borders[i][2];
			board[i*2, 2].systemLevel = borders[i][3];
			board[i*2 + 1, 2].systemLevel = borders[i][4];
		}

		// place bottom hexes
		foreach(i; 0..3)
		{
			board[i*2, 6].systemLevel = borders[i+3][4];
			board[i*2 + 1, 6].systemLevel = borders[i+3][3];
			board[i*2, 7].systemLevel = borders[i+3][2];
			board[i*2, 8].systemLevel = borders[i+3][1];
			board[i*2 + 1, 8].systemLevel = borders[i+3][0];
		}

		alias MiddleSector = uint[4];
		MiddleSector[2] middles = [
			[2,1,0,1], [1,0,2,1]
		];
		immutable indexes = [
			[0,1,2,3],
			[3,2,1,0],
		];

		randomShuffle(middles[]);

		// Left middle piece
		auto rand = dice(1, 1); // 0 or 1. Select rotation of sector
		board[0, 3].systemLevel = middles[0][ indexes[rand][0] ];
		board[0, 4].systemLevel = middles[0][ indexes[rand][1] ];
		board[1, 4].systemLevel = middles[0][ indexes[rand][2] ];
		board[0, 5].systemLevel = middles[0][ indexes[rand][3] ];

		// Right middle piece
		rand = dice(1, 1); // 0 or 1. Select rotation of sector
		board[4, 3].systemLevel = middles[1][ indexes[rand][0] ];
		board[4, 4].systemLevel = middles[1][ indexes[rand][1] ];
		board[5, 4].systemLevel = middles[1][ indexes[rand][2] ];
		board[4, 5].systemLevel = middles[1][ indexes[rand][3] ];

		return board;
	}
  
	void start(const ref GameBoard board)
	{
		// send board to all players
	}

	void setup()
	{
		//deploy ships
	}

	void rounds()
	{
		foreach(_; 0..numRounds)
			round();
	}

	void round()
	{
		plan();
		perform();
		exploit();
		//rotatePlayers();
	}

	// phase 1
	void plan()
	{
		//foreach(ref p; players)
		//	p.hasPlan = false;
		//uint numPlayersDonePlan;
		//while(numPlayersDonePlan < players.length)
		//{
		//	uint pid;
		//	PlanAction action = waitForAction!PlanAction(pid);
		//	if (players[pid].hasPlan) continue;
		//	players[pid].hasPlan = true;
		//	players[pid].commands = action.commands;
		//}
	}

	// phase 2
	void perform()
	{

	}

	void expand()
	{

	}

	void explore()
	{

	}

	void exterminate()
	{

	}

	// phase 3
	void exploit()
	{

	}

	void endGame()
	{

	}
}

unittest
{
	DList!Action actionList;
	auto serverLogic = new ServerLogicFiber(&actionList);
}