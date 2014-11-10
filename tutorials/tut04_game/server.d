module server;

import std.range;

import connection;
import derelict.enet.enet;
import baseserver;
import packets;
import serverlogic;

struct Client
{
	bool isReady;
	string name;
	ENetPeer* peer;
	Command[] commands;
}

class Server : BaseServer!Client
{
	ServerLogicFiber logic;
	DList!Action actionQueue;
	bool isStopping;

	string[ClientId] clientNames()
	{
		string[ClientId] names;
		foreach(id, client; clientStorage.clients)
		{
			names[id] = client.name;
		}

		return names;
	}

	override void start(ConnectionSettings settings, uint host, ushort port)
	{
		registerPackets(this);
		super.start(settings, host, port);
		
		logic = new ServerLogicFiber(&actionQueue, this);
		registerPacketHandler!LoginPacket(&handleLoginPacket);
		registerPacketHandler!MessagePacket(&handleMessagePacket);
		registerPacketHandler!ReadyPacket(&handleReadyPacket);
		registerPacketHandler!DeployShipsResultPacket(&handleDeployShipsResultPacket);
		registerPacketHandler!PlanResultPacket(&handlePlanResultPacket);
	}

	override void update(uint msecs)
	{
		super.update(msecs);
		if (logic.state == Fiber.State.HOLD)
			logic.call();
	}

	void sendMessageTo(ClientId clientId, string message)
	{
		sendTo(only(clientId), createPacket(MessagePacket(0, message)));
	}

	void handleCommand(string command, ClientId clientId)
	{
		import std.algorithm : splitter;
		import std.string : format;
		
		if (command.length <= 1)
		{
			sendMessageTo(clientId, "Invalid command");
			return;
		}

		// Split without leading '/'
		auto splitted = command[1..$].splitter;
		string commName = splitted.front;
		splitted.popFront;

		if (commName == "stop")
		{
			isStopping = true;
			disconnectAll();
		}
		else
			sendMessageTo(clientId, format("Unknown command %s", commName));
	}

	override void onConnect(ref ENetEvent event)
	{
		event.peer.data = cast(void*)clientStorage.addClient(event.peer);
		enet_peer_timeout(event.peer, 0, 0, 2000);
	}

	void handleLoginPacket(ubyte[] packetData, ClientId clientId)
	{
		LoginPacket packet = unpackPacket!LoginPacket(packetData);
		
		clientStorage[clientId].name = packet.clientName;
		
		sendTo(only(clientId), createPacket(SessionInfoPacket(clientId, clientNames)));
		sendToAll(createPacket(ClientLoggedInPacket(clientId, packet.clientName)));
	}

	void handleMessagePacket(ubyte[] packetData, ClientId clientId)
	{
		import std.algorithm : startsWith;
		import std.string : strip;

		MessagePacket packet = unpackPacket!MessagePacket(packetData);
			
		packet.clientId = clientId;
		string strippedMsg = packet.msg.strip;
		
		if (strippedMsg.startsWith("/"))
		{
			handleCommand(strippedMsg, clientId);
			return;
		}
		
		sendToAll(createPacket(packet));
	}

	override void onDisconnect(ref ENetEvent event)
	{
		ClientId clientId = cast(ClientId)event.peer.data;
		
		clientStorage.removeClient(clientId);

		sendToAll(createPacket(ClientLoggedOutPacket(clientId)));

		// Reset client's information
		event.peer.data = null;

		if (clientStorage.length == 0 && isStopping)
		{
			isRunning = false;
		}
	}

	// Game packet handlers

	void handleReadyPacket(ubyte[] packetData, ClientId clientId)
	{
		ReadyPacket packet = unpackPacket!ReadyPacket(packetData);
		if (packet.isReady)
			actionQueue.insertBack(Action(ActionType.ready, clientId));
		else
			actionQueue.insertBack(Action(ActionType.unready, clientId));
	}

	void handleDeployShipsResultPacket(ubyte[] packetData, ClientId clientId)
	{
		actionQueue.insertBack(Action(ActionType.deployShips, clientId, packetData));
	}

	void handlePlanResultPacket(ubyte[] packetData, ClientId clientId)
	{
		actionQueue.insertBack(Action(ActionType.plan, clientId, packetData));
	}
}