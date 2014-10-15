module client;

import core.thread;
import std.conv : to;
import std.stdio;
import std.string : format;
import std.random : uniform;

import derelict.enet.enet;

import connection;
import packets;

immutable randomNames = [
"Bob", "Steve", "Alanakai", "Tyler", "Carmine", "Carrol", "Randy", "Tim",
"Robbie", "Xavier", "Jerrell", "Robby", "Clinton", "Bob", "Berry", "Maximo",
"Emmett", "Napoleon", "Jeffery", "Ali", "Hubert", "Jordan", "Rickey", "Jamey",
"Bret", "Gene", "Cornell", "Garret", "Randal", "Luther", "Raymundo", "Brady",
"Reid", "Asha", "Tari", "Isela", "Qiana", "Nada", "Nicole", "Waneta", "Mammie",
"Deedra", "Shizuko", "Tammy", "Rachelle", "Tu", "Yon", "Torie", "Lauryn",
"Nikia", "Alaina", "Kelsey", "Velva", "Luna", "Nicola", "Darla", "Kelle",
"Valarie", "Bernardina", "Isidra", ];

class Client : Connection
{
	bool isRunning;

	ENetAddress serverAddress;
	ENetPeer* server;

	size_t myId;
	string[size_t] userNames;
	string userName(size_t userId)
	{
		return userId in userNames ? userNames[userId] : format("? %s", userId);
	}

	void start(string address = "127.0.0.1", ushort port = 1234)
	{
		registerPacket!LoginPacket;
		registerPacket!LoginInfoPacket(&handleLoginInfoPacket);
		registerPacket!UserLoggedInPacket;
		registerPacket!UserLoggedOutPacket;
		registerPacket!MessagePacket(&handleMessagePacket);

		enet_address_set_host(&serverAddress, cast(char*)address);
		serverAddress.port = port;

		host = enet_host_create(null /* create a client host */,
			1 /* only allow 1 outgoing connection */,
			2,
			57600 / 8 /* 56K modem with 56 Kbps downstream bandwidth */,
			14400 / 8 /* 56K modem with 14 Kbps upstream bandwidth */);

		if (host is null)
		{
			writeln("Client: An error occured while trying to create an ENet server host");
			return;
		}

		server = enet_host_connect(host, &serverAddress, 2, 42);
		enet_peer_timeout(server, 0, 0, 5000);

		if (server is null)
		{
			writeln("Client: An error occured while trying to create an ENet server peer");
			return;
		}

		side = "Client";

		writeln("Client: Started");
		isRunning = true;
	}

	override void stop()
	{
		super.stop();
		writefln("Client: Stopped");
	}

	void send(ubyte[] data, ubyte channel = 0)
	{
		ENetPacket* packet = enet_packet_create(data.ptr, data.length,
				ENET_PACKET_FLAG_RELIABLE);
		enet_peer_send(server, channel, packet);
	}

	override void onConnect(ref ENetEvent event)
	{
		writefln("Client: Connection to 127.0.0.1:1234 established");

		PeerInfo* peer = new PeerInfo(0, event.peer);
		event.peer.data = cast(void*)peer;

		string randomName = randomNames[uniform(0, randomNames.length)];
		send(createPacket(LoginPacket(randomName)));
		// Send 3 hello packets.
		foreach(i; 0..3)
		{
			string str = format("hello from %s %s", randomName, i);
			ubyte[] packet = createPacket(MessagePacket(0, str));
			send(packet);
			Thread.sleep(200.msecs);
		}
	}

	void handleLoginInfoPacket(ubyte[] packetData, ref PeerInfo peer)
	{
		LoginInfoPacket loginInfo = unpackPacket!LoginInfoPacket(packetData);

		userNames = loginInfo.userNames;
		myId = loginInfo.yourId;

		writefln("Client: my id is %s", myId);
	}

	void handleMessagePacket(ubyte[] packetData, ref PeerInfo peer)
	{
		MessagePacket msg = unpackPacket!MessagePacket(packetData);
		writefln("Client: %s> %s", userName(msg.userId), msg.msg);
	}

	override void onDisconnect(ref ENetEvent event)
	{
		writefln("Client: disconnected with data %s", event.data);

		// Reset server's information
		event.peer.data = null;
		
		isRunning = false;
	}
}