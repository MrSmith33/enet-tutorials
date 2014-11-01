module server;

import std.range;

import connection;
import derelict.enet.enet;
import baseserver;
import packets;

struct Client
{
	string name;
	ENetPeer* peer;
}

class Server : BaseServer!Client
{
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

	void sendMessageTo(ClientId userId, string message)
	{
		sendTo(only(userId), createPacket(MessagePacket(0, message)));
	}

	void handleCommand(string command, ClientId userId)
	{
		import std.algorithm : splitter;
		import std.string : format;
		
		if (command.length <= 1)
		{
			sendMessageTo(userId, "Invalid command");
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
			sendMessageTo(userId, format("Unknown command %s", commName));
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
}