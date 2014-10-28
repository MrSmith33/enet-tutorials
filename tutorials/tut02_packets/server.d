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


struct ServerSettings
{
	ushort port;
	size_t maxClients;
	size_t numChannels;
	uint incomingBandwidth;
	uint outgoingBandwidth;
}

struct User
{
	string name;
	ENetPeer* peer;
}

struct UserStorage
{
	private User*[UserId] users;

	UserId addUser(ENetPeer* peer)
	{
		UserId id = nextPeerId;
		User* user = new User;
		user.peer = peer;
		users[id] = user;
		return id;
	}

	void removeUser(UserId id)
	{
		users.remove(id);
	}

	User* findUser(UserId id)
	{
		return users.get(id, null);
	}

	UserId nextPeerId() @property
	{
		return _nextPeerId++;
	}

	string[UserId] userNames()
	{
		string[UserId] names;
		foreach(id, user; users)
		{
			names[id] = user.name;
		}

		return names;
	}

	string userName(UserId id)
	{
		return users[id].name;
	}

	ENetPeer* userPeer(UserId id)
	{
		return users[id].peer;
	}

	size_t length()
	{
		return users.length;
	}

	private UserId _nextPeerId = 1;
}

class Server : Connection
{
	bool isRunning;

	ENetAddress address;
	ServerSettings settings;

	UserStorage userStorage;

	void start(ServerSettings _settings)
	{
		side = "Server";

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
			writeln("Server: An error occured while trying to create an ENet server host");
			return;
		}

		isRunning = true;
	}

	void sendMessageTo(UserId userId, string message)
	{
		sendTo(only(userId), createPacket(MessagePacket(0, message)));
	}

	void handleCommand(string command, UserId userId)
	{
		import std.algorithm : splitter;
		import std.string : format;
		writefln("Server: %s Command> %s", userStorage.userName(userId), command);
		
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
			isRunning = false;
		else
			sendMessageTo(userId, format("Unknown command %s", commName));
	}

	override void stop()
	{
		super.stop();
		writefln("Server: Stopped");
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
		writefln("Server: A new client connected from %(%s.%):%s", 
			*cast(ubyte[4]*)(&event.peer.address.host),
			event.peer.address.port);

		event.peer.data = cast(void*)userStorage.addUser(event.peer);
		enet_peer_timeout(event.peer, 0, 0, 2000);
	}

	void handleLoginPacket(ubyte[] packetData, UserId userId)
	{
		LoginPacket packet = unpackPacket!LoginPacket(packetData);
		
		userStorage.findUser(userId).name = packet.userName;
		writefln("Server: %s logged in", packet.userName);
		
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

		writefln("Server: %s> %s", userStorage.userName(userId), packet.msg);
		
		sendToAll(createPacket(packet));
	}

	override void onDisconnect(ref ENetEvent event)
	{
		UserId userId = cast(UserId)event.peer.data;
		
		writefln("Server: %s disconnected", userStorage.userName(userId));
		
		userStorage.removeUser(userId);

		sendToAll(createPacket(UserLoggedOutPacket(userId)));

		// Reset client's information
		event.peer.data = null;

		if (userStorage.length == 0)
			isRunning = false;
	}
}