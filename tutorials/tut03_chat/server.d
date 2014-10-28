/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module server;

import std.stdio;
import std.range;

import derelict.enet.enet;

import connection;
import packets;
import userstorage;


struct ServerSettings
{
	ushort port;
	size_t maxClients;
	size_t numChannels;
	uint incomingBandwidth;
	uint outgoingBandwidth;
}

class Server : Connection
{
	bool isRunning = false;
	bool isStopping = false;

	ENetAddress address;
	ServerSettings settings;

	UserStorage userStorage;

	void start(ServerSettings _settings)
	{
		registerPacket!LoginPacket(&handleLoginPacket);
		registerPacket!SessionInfoPacket;
		registerPacket!UserLoggedInPacket;
		registerPacket!UserLoggedOutPacket;
		registerPacket!MessagePacket(&handleMessagePacket);

		printPacketMap();

		settings = _settings;

		address.host = ENET_HOST_ANY;
		address.port = settings.port;

		host = enet_host_create(&address,
			settings.maxClients,
			settings.numChannels,
			settings.incomingBandwidth,
			settings.outgoingBandwidth);

		if (host is null)
		{
			writeln("An error occured while trying to create an ENet server host");
			return;
		}

		isRunning = true;

		writefln("Started on port %s", settings.port);
	}

	void sendMessageTo(UserId userId, string message)
	{
		sendTo(only(userId), createPacket(MessagePacket(0, message)));
	}

	void handleCommand(string command, UserId userId)
	{
		import std.algorithm : splitter;
		import std.string : format;
		writefln("%s:> %s", userStorage.userName(userId), command);
		
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

	void disconnectAll()
	{
		foreach(user; userStorage.byUser)
		{
			enet_peer_disconnect(user.peer, 0);
		}
	}

	override void stop()
	{
		super.stop();
		writefln("Stopped");
	}

	/// Sending
	void sendTo(R)(R users, ubyte[] data, ubyte channel = 0)
		if (isInputRange!R && is(ElementType!R == UserId))
	{
		ENetPacket *packet = enet_packet_create(data.ptr, data.length,
				ENET_PACKET_FLAG_RELIABLE);
		sendTo(users, packet, channel);
	}

	/// ditto
	void sendTo(R)(R users, ENetPacket* packet, ubyte channel = 0)
		if (isInputRange!R && is(ElementType!R == UserId))
	{
		foreach(userId; users)
		{
			enet_peer_send(userStorage.userPeer(userId), channel, packet);
		}
	}

	/// ditto
	void sendToAll(ubyte[] data, ubyte channel = 0)
	{
		ENetPacket *packet = enet_packet_create(data.ptr, data.length,
					ENET_PACKET_FLAG_RELIABLE);
		sendToAll(packet, channel);
	}

	/// ditto
	void sendToAll(ENetPacket* packet, ubyte channel = 0)
	{
		enet_host_broadcast(host, channel, packet);
	}

	//-------------------------------------------------------------------------
	// Handlers

	override void onConnect(ref ENetEvent event)
	{
		writefln("A new client connected from %(%s.%):%s", 
			*cast(ubyte[4]*)(&event.peer.address.host),
			event.peer.address.port);

		event.peer.data = cast(void*)userStorage.addUser(event.peer);
		enet_peer_timeout(event.peer, 0, 0, 2000);
	}

	void handleLoginPacket(ubyte[] packetData, UserId userId)
	{
		LoginPacket packet = unpackPacket!LoginPacket(packetData);
		
		userStorage.findUser(userId).name = packet.userName;
		writefln("%s logged in", packet.userName);
		
		sendTo(only(userId), createPacket(SessionInfoPacket(userId, userStorage.userNames)));
		sendToAll(createPacket(UserLoggedInPacket(userId, packet.userName)));
	}

	void handleMessagePacket(ubyte[] packetData, UserId userId)
	{
		import std.algorithm : startsWith;
		import std.string : strip;

		MessagePacket packet = unpackPacket!MessagePacket(packetData);
			
		packet.userId = userId;
		string strippedMsg = packet.msg.strip;
		
		if (strippedMsg.startsWith("/"))
		{
			handleCommand(strippedMsg, userId);
			return;
		}

		writefln("%s> %s", userStorage.userName(userId), packet.msg);
		
		sendToAll(createPacket(packet));
	}

	override void onDisconnect(ref ENetEvent event)
	{
		UserId userId = cast(UserId)event.peer.data;
		
		writefln("%s disconnected", userStorage.userName(userId));
		
		userStorage.removeUser(userId);

		sendToAll(createPacket(UserLoggedOutPacket(userId)));

		// Reset client's information
		event.peer.data = null;

		if (userStorage.length == 0 && isStopping)
		{
			isRunning = false;
		}
	}
}