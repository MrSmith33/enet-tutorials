module serverlogic;

import std.algorithm : canFind, remove;
import std.stdio;
import std.container : DList, SList;
import std.range;
import core.thread : Fiber;

import connection;
import server;
import packets;

import gameboard;

struct Player
{
	ClientId clientId;
	bool hasPlan;

	uint numberOfShips;
	uint score;
}

enum ActionType
{
	// - no packet data, + with packet data
	/*-*/ ready,
	/*-*/ unready,
	/*+*/ plan,
	/*-*/ deployShips
}

struct Action
{
	ActionType type;
	ClientId clientId;
	ubyte[] packetData;
}

class ServerLogicFiber : Fiber
{
	DList!Action* queue;
	Server server;

	Action waitForAction()
	{
		import std.range : moveFront;
		while (queue.empty)
		{
			Fiber.yield();
		}
		auto item = queue.front;
		queue.removeFront;
		return item;
	}

	this(DList!Action* queue, Server server)
	{
		assert(queue && server);

		this.queue = queue;
		this.server = server;
		super(&run);
	}

	Client* getClient(ClientId id)
	{
		return server.clientStorage.clients[id];
	}

	// LOGIC

	GameBoard board;
	ClientId[] players;

	void rotatePlayers()
	{
		import std.algorithm : bringToFront;
		bringToFront(players[0..1], players[1..$]);
	}

	void run()
	{
		waitForReady();
		board = boardGen();
		BoardDataPacket packet;
		packet.systemLevels = new uint[54];
		foreach(i, hex; board.data)
			packet.systemLevels[i] = hex.systemLevel;
		server.sendToAll(packet);

		deployShips();
		rounds();
		server.isRunning = false;
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

	void waitForReady()
	{
		int numReady;
		while (numReady < 3)
		{
			Action a = waitForAction();

			if (a.type == ActionType.ready && !getClient(a.clientId).isReady)
			{
				getClient(a.clientId).isReady = true;
				players ~= a.clientId;
				++numReady;
			}
			else if (a.type == ActionType.unready && getClient(a.clientId).isReady)
			{
				getClient(a.clientId).isReady = false;
				players = remove!(c => c == a.clientId)(players);
				--numReady;
			}
		}
	}
  
	void deployShips()
	{
		bool[9] occupiedSectors;
		occupiedSectors[4] = true;

		foreach(playerId; chain(players, players.retro))
		{
			server.sendToAllExcept(playerId, ClientTurnPacket(ClientTurn.deployShips, playerId));

			outerLoop:
			while(true) // Wait for valid action result
			{
				uint[] freeSectors;
				foreach (i, s; occupiedSectors)
					if (!s) freeSectors ~= i;
				server.sendTo(playerId, DeployShipsArgsPacket(freeSectors));

				while(true) // Wait for deployShips action
				{
					Action action = waitForAction();
					writefln("%s", action.type);
					if (action.type == ActionType.deployShips && action.clientId == playerId)
					{
						auto packet = server.unpackPacket!DeployShipsResultPacket(action.packetData);
						uint sector = sectorNumber(HexCoords(cast(ubyte)packet.x, cast(ubyte)packet.y));
						
						if (packet.x >= boardWidth || packet.y >= boardHeight) continue outerLoop;
						if (sector == 4 || sector >= 9) continue outerLoop;
						if (occupiedSectors[sector]) continue outerLoop;
						if (board[packet.x, packet.y].systemLevel != 1) continue outerLoop;

						occupiedSectors[sector] = true;

						board[packet.x, packet.y].playerId = playerId;
						board[packet.x, packet.y].numShips = 2;

						server.sendToAll(HexDataPacket(packet.x, packet.y, playerId, 2));
						break outerLoop;
					}
				}
			}
		}
	}

	void rounds()
	{
		foreach(_; 0..numRounds)
			round();
	}

	void round()
	{
		writeln("Plan");
		plan();
		writeln("Perform");

		server.isRunning = false;
		perform();
		exploit();
		rotatePlayers();
	}

	// phase 1
	void plan()
	{
		server.sendToAll(ClientTurnPacket(ClientTurn.plan, 0));

		uint numPlayersDonePlan;
		while(numPlayersDonePlan < players.length)
		{
			Action action = waitForAction();

			if (action.type != ActionType.plan) continue; // reject not valid action.
			if (getClient(action.clientId).commands.length != 0) continue; // reject, commands already set.

			auto packet = server.unpackPacket!PlanResultPacket(action.packetData);

			if (packet.commands.length != 3) // Invalid result.
			{
				server.sendTo(action.clientId, ClientTurnPacket(ClientTurn.plan, 0));
				continue;
			}

			getClient(action.clientId).commands = packet.commands;

			++numPlayersDonePlan;
		}

		foreach(pid; players)
			writeln(getClient(pid).commands);
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