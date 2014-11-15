module serverlogic;

import core.thread : Fiber;
import std.stdio : writeln, writefln;
import std.container : DList;

import connection;
import server;
import packets;

import gameboard;

struct Player
{
	ClientId clientId;

	uint numShips;
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

import std.range : isInputRange;
auto getPopFront(IR)(ref IR inputRange)
	if (isInputRange!IR)
{
	import std.range : front, popFront;
	auto frontItem = inputRange.front;
	inputRange.popFront();
	return frontItem;
}

class ServerLogicFiber : Fiber
{
	DList!Action* queue;
	Server server;

	Action waitForAction()
	{
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
	ClientId triPrimeOwner; // 0 if none

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
		endGame();
		server.isRunning = false;
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
				import std.algorithm : remove;
				getClient(a.clientId).isReady = false;
				players = remove!(c => c == a.clientId)(players);
				--numReady;
			}
		}
	}

	void deployShip(ClientId playerId, bool[] occupiedSectors)
	{
		uint[] freeSectors;
		foreach (i, s; occupiedSectors)
			if (!s) freeSectors ~= i;

		bool isValidAction(Action a)
		{
			return a.type == ActionType.deployShips && a.clientId == playerId;
		}

		while(true) // Wait for deployShips action
		{
			server.sendTo(playerId, DeployShipsArgsPacket(freeSectors));

			Action action;
			do
			{
				action = waitForAction();
				writefln("%s %s", playerId, action.type);
			}
			while (!isValidAction(action));

			auto packet = server.unpackPacket!DeployShipsResultPacket(action.packetData);
			uint sector = sectorNumber(HexCoords(cast(ubyte)packet.x, cast(ubyte)packet.y));
			
			if (packet.x >= boardWidth || packet.y >= boardHeight) continue;
			if (sector == 4 || sector >= 9) continue;
			if (occupiedSectors[sector]) continue;
			if (board[packet.x, packet.y].systemLevel != 1) continue;

			occupiedSectors[sector] = true;

			board[packet.x, packet.y].playerId = playerId;
			board[packet.x, packet.y].numShips = 2;
			getClient(playerId).numShips += 2;

			server.sendToAll(HexDataPacket(packet.x, packet.y, playerId, 2));
			break;
		}
	}
  
	void deployShips()
	{
		import std.range : chain, retro;

		bool[9] occupiedSectors;
		occupiedSectors[4] = true;

		foreach(playerId; chain(players, players.retro))
		{
			server.sendToAll(ClientTurnPacket(ClientTurn.deployShips, playerId));
			deployShip(playerId, occupiedSectors);
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
			writefln("%s %(%s -> %)", pid, getClient(pid).commands);
	}

	static struct PlayerCommand
	{
		Command command;
		ClientId playerId;
		uint numTurns; // 1-3
	}

	// phase 2
	void perform()
	{
		import std.algorithm : count, sort, SwapStrategy;
		import std.range : moveFront;

		foreach(_; 0..3)
		{
			// Get first command of all players.
			PlayerCommand[] playerCommands;
			foreach(player; players)
			{
				playerCommands ~= PlayerCommand(getClient(player).commands.getPopFront, player);
			}

			sort!("a.command < b.command", SwapStrategy.stable)(playerCommands);
			foreach(ref command; playerCommands)
			{
				command.numTurns = 4 - count!((a, b) => a.command == b.command)(playerCommands, command);
			}

			foreach(playerCommand; playerCommands)
			foreach(__; 0..playerCommand.numTurns)
			final switch(playerCommand.command)
			{
				case Command.expand:
					expand(playerCommand.playerId);
					break;
				case Command.explore:
					explore(playerCommand.playerId);
					break;
				case Command.exterminate:
					exterminate(playerCommand.playerId);
					break;
			}
		}
	}

	void expand(ClientId playerId)
	{
		writefln("expand %s", playerId);
		return;
		//server.sendToAll(ClientTurnPacket(ClientTurn.expand, playerId));
	}

	void explore(ClientId playerId)
	{
		writefln("explore %s", playerId);
		return;
		//server.sendToAll(ClientTurnPacket(ClientTurn.explore, playerId));
	}

	void exterminate(ClientId playerId)
	{
		writefln("exterminate %s", playerId);
		return;
		//server.sendToAll(ClientTurnPacket(ClientTurn.exterminate, playerId));
	}

	// phase 3
	void exploit()
	{
		sustainShips();
	}

	void sustainShips()
	{
		foreach(hex; board.data)
		{
			if (hex.numShips > hex.systemLevel + 1)
			{
				hex.numShips = hex.systemLevel + 1;
			}
		}
	}

	void endGame()
	{
		import std.algorithm : sort;

		uint maxScorePlayer, maxScore;

		foreach(p; players)
		{
			if (getClient(p).score > maxScore)
			{
				maxScorePlayer = p;
				maxScore = getClient(p).score;
			}
		}

		writefln("%s won with %s points", maxScorePlayer, maxScore);
	}
}