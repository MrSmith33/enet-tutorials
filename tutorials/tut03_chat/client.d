module client;

import core.thread;
import std.conv : to;
import std.stdio : writefln, writeln;
import std.string : format, toStringz;
import std.random : uniform;

import derelict.enet.enet;

import connection;
import packets;

immutable randomNames = [
"Bob", "Steve", "Alanakai", "Tyler", "Carmine", "Randy", "Tim",
"Robbie", "Xavier", "Jerrell", "Clinton", "Bob", "Berry", "Maximo",
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

	UserId myId;
	string myName;

	string[UserId] userNames;

	void delegate() disconnectHandler;
	
	string userName(UserId userId)
	{
		return userId in userNames ? userNames[userId] : format("? %s", userId);
	}

	this()
	{
		registerPacket!LoginPacket;
		registerPacket!SessionInfoPacket;
		registerPacket!UserLoggedInPacket;
		registerPacket!UserLoggedOutPacket;
		registerPacket!MessagePacket;
	}

	void start()
	{
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
	}

	void connect(string name, string address = "127.0.0.1", ushort port = 1234)
	{
		myName = name;

		enet_address_set_host(&serverAddress, address.toStringz);
		serverAddress.port = port;

		server = enet_host_connect(host, &serverAddress, 2, 42);
		enet_peer_timeout(server, 0, 0, 5000);

		if (server is null)
		{
			writeln("An error occured while trying to create an ENet server peer");
			return;
		}

		writeln("Started");
		isRunning = true;
	}

	override void stop()
	{
		super.stop();
		writefln("Stopped");
	}

	void send(ubyte[] data, ubyte channel = 0)
	{
		ENetPacket* packet = enet_packet_create(data.ptr, data.length,
				ENET_PACKET_FLAG_RELIABLE);
		enet_peer_send(server, channel, packet);
	}

	override void onConnect(ref ENetEvent event)
	{
		writefln("Connection to 127.0.0.1:1234 established");

		// generate random name
		//myName = randomNames[uniform(0, randomNames.length)];
		send(createPacket(LoginPacket(myName)));
	}

	override void onDisconnect(ref ENetEvent event)
	{
		writefln("disconnected with data %s", event.data);

		// Reset server's information
		event.peer.data = null;
		
		isRunning = false;

		if (disconnectHandler) disconnectHandler();
	}
}