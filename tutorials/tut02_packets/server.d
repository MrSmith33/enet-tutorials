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
	bool loggedIn;
}

class Server : Connection
{
	uint numConnected;
	private size_t _nextPeerId = 1;
	bool isRunning;

	ENetAddress address;
	ServerSettings settings;

	PeerInfo*[] clients;
	string[size_t] userNames;

	size_t nextPeerId() @property
	{
		return _nextPeerId++;
	}

	void start(ServerSettings _settings)
	{
		side = "Server";

		registerPacket!LoginPacket(&handleLoginPacket);
		registerPacket!LoginInfoPacket;
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

		PeerInfo* client = new PeerInfo(nextPeerId, event.peer);
		clients ~= client;
		event.peer.data = cast(void*)client;
		enet_peer_timeout(event.peer, 0, 0, 2000);

		++numConnected;
	}

	void handleLoginPacket(ubyte[] packetData, ref PeerInfo peer)
	{
		LoginPacket packet = unpackPacket!LoginPacket(packetData);
		userNames[peer.id] = packet.userName;
		writefln("Server: %s logged in", packet.userName);
		sendTo(only(peer), createPacket(LoginInfoPacket(peer.id, userNames)));
	}

	void handleMessagePacket(ubyte[] packetData, ref PeerInfo peer)
	{
		MessagePacket packet = unpackPacket!MessagePacket(packetData);
		writefln("Server: %s> %s", userNames[peer.id], packet.msg);
		packet.userId = peer.id;
		sendToAll(createPacket(packet));
	}

	override void onDisconnect(ref ENetEvent event)
	{
		writefln("Server: %s disconnected", userNames[(cast(PeerInfo*)event.peer.data).id]);

		// Reset client's information
		event.peer.data = null;
		--numConnected;

		if (numConnected == 0)
			isRunning = false;
	}
}