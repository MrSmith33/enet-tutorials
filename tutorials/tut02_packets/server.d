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
}

struct UserStorage
{
	private User*[size_t] users;

	size_t addUser()
	{
		size_t id = nextPeerId;
		User* user = new User;
		users[id] = user;
		return id;
	}

	void removeUser(size_t id)
	{
		users.remove(id);
	}

	User* findUser(size_t id)
	{
		return users.get(id, null);
	}

	size_t nextPeerId() @property
	{
		return _nextPeerId++;
	}

	string[size_t] userNames()
	{
		string[size_t] names;
		foreach(id, user; users)
		{
			names[id] = user.name;
		}

		return names;
	}

	string userName(size_t id)
	{
		return users[id].name;
	}

	size_t length()
	{
		return users.length;
	}

	private size_t _nextPeerId = 1;
}

class Server : Connection
{
	bool isRunning;

	ENetAddress address;
	ServerSettings settings;

	PeerInfo*[size_t] clients;

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

	override void stop()
	{
		super.stop();
		writefln("Server: Stopped");
	}

	/// Sending
	void sendTo(R)(R peerInfos, ubyte[] data, ubyte channel = 0)
		if (isInputRange!R && is(ElementType!R == PeerInfo))
	{
		ENetPacket *packet = enet_packet_create(data.ptr, data.length,
				ENET_PACKET_FLAG_RELIABLE);
		sendTo(peerInfos, packet, channel);
	}

	/// ditto
	void sendTo(R)(R peerInfos, ENetPacket* packet, ubyte channel = 0)
		if (isInputRange!R && is(ElementType!R == PeerInfo))
	{
		foreach(peerInfo; peerInfos)
		{
			enet_peer_send(peerInfo.peer, channel, packet);
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

		PeerInfo* pinfo = new PeerInfo(userStorage.addUser, event.peer);
		clients[pinfo.id] = pinfo;
		event.peer.data = cast(void*)pinfo;
		enet_peer_timeout(event.peer, 0, 0, 2000);
	}

	void handleLoginPacket(ubyte[] packetData, ref PeerInfo peer)
	{
		LoginPacket packet = unpackPacket!LoginPacket(packetData);
		
		userStorage.findUser(peer.id).name = packet.userName;
		writefln("Server: %s logged in", packet.userName);
		
		sendTo(only(peer), createPacket(SessionInfoPacket(peer.id, userStorage.userNames)));
		sendToAll(createPacket(UserLoggedInPacket(peer.id, packet.userName)));
	}

	void handleMessagePacket(ubyte[] packetData, ref PeerInfo peer)
	{
		MessagePacket packet = unpackPacket!MessagePacket(packetData);
		
		writefln("Server: %s> %s", userStorage.userName(peer.id), packet.msg);
		packet.userId = peer.id;
		
		sendToAll(createPacket(packet));
	}

	override void onDisconnect(ref ENetEvent event)
	{
		size_t userId = (cast(PeerInfo*)event.peer.data).id;
		
		writefln("Server: %s disconnected", userStorage.userName(userId));
		
		userStorage.removeUser(userId);
		clients.remove(userId);

		sendToAll(createPacket(UserLoggedOutPacket(userId)));

		// Reset client's information
		event.peer.data = null;

		if (userStorage.length == 0)
			isRunning = false;
	}
}