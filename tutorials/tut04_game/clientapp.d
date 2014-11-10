/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module clientapp;

import core.thread;
import std.conv : to;
import std.stdio : writefln, writeln;
import std.string : format;

import derelict.enet.enet;

import connection;
import baseclient;

import packets;
import gameboard;


immutable randomNames = [
"Bob", "Steve", "Alanakai", "Tyler", "Carmine", "Randy", "Tim",
"Robbie", "Xavier", "Jerrell", "Clinton", "Bob", "Berry", "Maximo",
"Emmett", "Napoleon", "Jeffery", "Ali", "Hubert", "Jordan", "Rickey", "Jamey",
"Bret", "Gene", "Cornell", "Garret", "Randal", "Luther", "Raymundo", "Brady",
"Reid", "Asha", "Tari", "Isela", "Qiana", "Nada", "Nicole", "Waneta", "Mammie",
"Deedra", "Shizuko", "Tammy", "Rachelle", "Tu", "Yon", "Torie", "Lauryn",
"Nikia", "Alaina", "Kelsey", "Velva", "Luna", "Nicola", "Darla", "Kelle",
"Valarie", "Bernardina", "Isidra", ];

class Client : BaseClient
{
	ENetAddress serverAddress;
	ENetPeer* server;

	ClientId myId;
	string myName;

	GameBoard board;

	string[ClientId] clientNames;
	
	string clientName(ClientId clientId)
	{
		return clientId in clientNames ? clientNames[clientId] : format("? %s", clientId);
	}

	override void start(ConnectionSettings settings)
	{
		registerPackets(this);
		super.start(settings);
		
		registerPacketHandler!SessionInfoPacket(&handleSessionInfoPacket);
		registerPacketHandler!ClientLoggedInPacket(&handleUserLoggedInPacket);
		registerPacketHandler!ClientLoggedOutPacket(&handleUserLoggedOutPacket);
		registerPacketHandler!MessagePacket(&handleMessagePacket);
		registerPacketHandler!BoardDataPacket(&handleBoardDataPacket);
		registerPacketHandler!ClientTurnPacket(&handleClientTurnPacket);
		registerPacketHandler!DeployShipsArgsPacket(&handleDeployShipsArgsPacket);
		registerPacketHandler!HexDataPacket(&handleHexDataPacket);
	}

	override void onConnect(ref ENetEvent event)
	{
		writefln("Connection to 127.0.0.1:1234 established");

		// generate random name
		import std.random : uniform;
		myName = randomNames[uniform(0, randomNames.length)];
		send(LoginPacket(myName));
	}

	void handleSessionInfoPacket(ubyte[] packetData, ClientId peer)
	{
		SessionInfoPacket loginInfo = unpackPacket!SessionInfoPacket(packetData);

		clientNames = loginInfo.clientNames;
		myId = loginInfo.yourId;

		writefln("My id %s", myId);

		send(ReadyPacket(true));
		send(ReadyPacket(false));
		send(ReadyPacket(true));
		send(ReadyPacket(true));
		flush();
	}

	void handleUserLoggedInPacket(ubyte[] packetData, ClientId peer)
	{
		ClientLoggedInPacket newUser = unpackPacket!ClientLoggedInPacket(packetData);
		clientNames[newUser.clientId] = newUser.clientName;
		writefln("%s has connected", newUser.clientName);
	}

	void handleUserLoggedOutPacket(ubyte[] packetData, ClientId peer)
	{
		ClientLoggedOutPacket packet = unpackPacket!ClientLoggedOutPacket(packetData);
		writefln("%s has disconnected", clientName(packet.clientId));
		clientNames.remove(packet.clientId);
	}

	void handleMessagePacket(ubyte[] packetData, ClientId peer)
	{
		MessagePacket msg = unpackPacket!MessagePacket(packetData);
		if (msg.clientId == 0)
			writefln("%s", msg.msg);
		else
			writefln("%s> %s", clientName(msg.clientId), msg.msg);
	}

	override void onDisconnect(ref ENetEvent event)
	{
		writefln("disconnected with data %s", event.data);

		// Reset server's information
		event.peer.data = null;
		
		isRunning = false;
	}

	void handleBoardDataPacket(ubyte[] packetData, ClientId peer)
	{
		auto packet = unpackPacket!BoardDataPacket(packetData);
		foreach(i, level; packet.systemLevels)
		{
			if (i >= board.data.length) break;
			board.data[i].systemLevel = level;
		}
	}

	void handleClientTurnPacket(ubyte[] packetData, ClientId peer)
	{
		auto packet = unpackPacket!ClientTurnPacket(packetData);
		if (packet.id == myId || packet.id == 0)
		{
			with(ClientTurn) 
			final switch(packet.turn)
			{
				case deployShips:
					break;
				case plan:
					writefln("on plan");
					import std.random : randomShuffle;
					Command[] commands = [Command.expand, Command.explore, Command.exterminate];
					randomShuffle(commands);
					send(PlanResultPacket(commands));
					break;
				case expand:
					break;
				case explore:
					break;
				case exterminate:
					break;
				case chooseScoreSector:
					break;
			}
		}
	}

	void handleDeployShipsArgsPacket(ubyte[] packetData, ClientId peer)
	{
		auto packet = unpackPacket!DeployShipsArgsPacket(packetData);
		writefln("free sectors %s", packet.freeSectors);
		HexCoords freeHex;
		foreach(hexCoords; board.sectorHexes(cast(ubyte)packet.freeSectors[0]))
			if (board[hexCoords.x, hexCoords.y].systemLevel == 1)
			{
				freeHex = hexCoords;
				break;
			}
		send(DeployShipsResultPacket(freeHex.x, freeHex.y));
	}

	void handleHexDataPacket(ubyte[] packetData, ClientId peer)
	{
		auto packet = unpackPacket!HexDataPacket(packetData);
		writeln(packet);
	}
}

void main(string[] args)
{
	loadEnet();

	auto client = new Client;
	ConnectionSettings settings = {null, 1, 2, 0, 0};
	
	client.start(settings);
	client.connect("127.0.0.1", 1234);

	while (client.isRunning)
	{
		client.update(100);
	}

	client.stop();
}