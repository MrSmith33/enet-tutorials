import derelict.enet.enet;
import std.stdio;
import std.logger;
import std.parallelism;
import std.conv : to;

struct PeerInfo
{
	uint id;
	ENetPeer* peer;
}

struct ServerSettings
{
	ushort port;
	size_t maxClients;
	size_t numChannels;
	uint incomingBandwidth;
	uint outgoingBandwidth;
}

struct Server
{
	uint numConnected;
	bool isRunning;

	ENetHost* host;
	ENetAddress address;
	ServerSettings settings;

	PeerInfo*[] clients;

	void start(ServerSettings _settings)
	{
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

		logf("Server started");
		isRunning = true;
	}

	void update(uint msecs = 1000)
	{
		ENetEvent event;
		int eventStatus = enet_host_service(host, &event, msecs);

		if (eventStatus == 0) return;

		final switch (event.type)
		{
			case ENET_EVENT_TYPE_NONE:
				break;
			case ENET_EVENT_TYPE_CONNECT:
				onConnect(event);
				break;
			case ENET_EVENT_TYPE_RECEIVE:
				onPacketReceived(event);
				break;
			case ENET_EVENT_TYPE_DISCONNECT:
				onDisconnect(event);
				break;
		}
	}

	void sendTo(PeerInfo[] _clients, ubyte[] data, ubyte channel = 0)
	{
		foreach(client; _clients)
		{
			ENetPacket *packet = enet_packet_create(data.ptr, data.length,
					ENET_PACKET_FLAG_RELIABLE);
			enet_peer_send(client.peer, channel, packet);
		}
	}

	void sendToAll(ubyte[] data, ubyte channel = 0)
	{
		ENetPacket *packet = enet_packet_create(data.ptr, data.length,
					ENET_PACKET_FLAG_RELIABLE);
		enet_host_broadcast(host, channel, packet);
	}

	void sendToAll(ENetPacket* packet, ubyte channel = 0)
	{
		enet_host_broadcast(host, channel, packet);
	}

	void stop()
	{
		enet_host_destroy(host);
		writefln("Server stopped");
	}

	void onConnect(ref ENetEvent event)
	{
		writefln("A new client connected from %(%s.%):%s", 
			*cast(ubyte[4]*)(&event.peer.address.host),
			event.peer.address.port);

		PeerInfo* client = new PeerInfo(numConnected, event.peer);
		clients ~= client;
		event.peer.data = cast(void*)client;
		enet_peer_timeout(event.peer, 0, 0, 2000);

		++numConnected;
	}

	void onPacketReceived(ref ENetEvent event)
	{
		writefln ("A packet of length %d containing \"%s\" was received from client %s on channel %d",
			event.packet.dataLength,
			(cast(char*)event.packet.data)[0..event.packet.dataLength],
			(cast(PeerInfo*)event.peer.data).id,
			event.channelID);

		// Lets broadcast this message to all
		// packet is automatically destroyed by broadcast
		sendToAll(event.packet);
	}

	void onDisconnect(ref ENetEvent event)
	{
		writefln("client %s disconnected", (cast(PeerInfo*)event.peer.data).id);

		// Reset client's information
		event.peer.data = null;
		--numConnected;

		if (numConnected == 0)
			isRunning = false;
	}
}

struct Client
{
	bool isRunning;

	ENetHost* host;
	ENetAddress serverAddress;
	ENetPeer* server;

	uint numReceived;

	void start(string address = "127.0.0.1", ushort port = 1234)
	{
		enet_address_set_host(&serverAddress, cast(char*)address);
		serverAddress.port = 1234;

		host = enet_host_create(null /* create a client host */,
			1 /* only allow 1 outgoing connection */,
			2,
			57600 / 8 /* 56K modem with 56 Kbps downstream bandwidth */,
			14400 / 8 /* 56K modem with 14 Kbps upstream bandwidth */);

		if (host is null)
		{
			writeln("An error occured while trying to create an ENet server host");
			return;
		}

		server = enet_host_connect(host, &serverAddress, 2, 42);
		enet_peer_timeout(server, 0, 0, 5000);

		if (server is null)
		{
			writeln("An error occured while trying to create an ENet server peer");
			return;
		}

		writeln("Client started");
		isRunning = true;
	}

	void update(uint msecs = 1000)
	{
		ENetEvent event;
		int eventStatus = enet_host_service(host, &event, msecs);

		if (eventStatus == 0) return;

		final switch (event.type)
		{
			case ENET_EVENT_TYPE_NONE:
				break;
			case ENET_EVENT_TYPE_CONNECT:
				onConnect(event);
				break;
			case ENET_EVENT_TYPE_RECEIVE:
				onPacketReceived(event);
				break;
			case ENET_EVENT_TYPE_DISCONNECT:
				onDisconnect(event);
				break;
		}
	}

	void stop()
	{
		enet_host_destroy(host);
		writefln("Client stopped");
	}

	void send(ubyte[] data, ubyte channel = 0)
	{
		ENetPacket *packet = enet_packet_create(data.ptr, data.length,
				ENET_PACKET_FLAG_RELIABLE);
		enet_peer_send(server, channel, packet);
	}

	void onConnect(ref ENetEvent event)
	{
		writefln("Connection to 127.0.0.1:1234 established");

		// Send 10 hello packets.
		foreach(i; 0..10)
		{
			string str = "hello "~to!string(i);
			send(cast(ubyte[])str);

			enet_host_flush(host);
		}
	}

	void onPacketReceived(ref ENetEvent event)
	{
		writefln ("A packet of length %d containing \"%s\" was received from server %s on channel %d",
			event.packet.dataLength,
			(cast(char*)event.packet.data)[0..event.packet.dataLength],
			event.peer.data,
			event.channelID);

		++numReceived;
		if (numReceived == 10)
		{
			enet_peer_disconnect_later(server, 0);
		}
	}

	void onDisconnect(ref ENetEvent event)
	{
		writefln("client onDisconnect with data %s", event.data);

		// Reset server's information
		event.peer.data = null;
		
		isRunning = false;
	}
}

void clientWorker()
{
	Client client;

	client.start();

	while (client.isRunning)
	{
		client.update();
	}

	client.stop();
}

void serverWorker()
{
	writefln("Starting server");
	
	Server server;

	ServerSettings settings = {1234, 32, 2, 0, 0};
	server.start(settings);

	while (server.isRunning)
	{
		server.update();
	}

	server.stop();
}

void main()
{
	DerelictENet.load();

	int err = enet_initialize();

	if (err != 0)
	{
		writefln("Error loading ENet library");
		return;
	}
	else
	{
		ENetVersion ever = enet_linked_version();
		writefln("Loaded ENet library %s.%s.%s",
			ENET_VERSION_GET_MAJOR(ever),
			ENET_VERSION_GET_MINOR(ever),
			ENET_VERSION_GET_PATCH(ever));
	}

	auto pool = taskPool();

	pool.put(task!clientWorker);
	pool.put(task!clientWorker); // more clients
	pool.put(task!serverWorker);
}