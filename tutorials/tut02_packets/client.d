module client;

import core.thread;
import std.conv : to;
import std.stdio : writefln, writeln;
import std.string : format;
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
	
	string userName(UserId userId)
	{
		return userId in userNames ? userNames[userId] : format("? %s", userId);
	}

	void start(string address = "127.0.0.1", ushort port = 1234)
	{
		registerPacket!LoginPacket;
		registerPacket!SessionInfoPacket(&handleSessionInfoPacket);
		registerPacket!UserLoggedInPacket(&handleUserLoggedInPacket);
		registerPacket!UserLoggedOutPacket(&handleUserLoggedOutPacket);
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

		// generate random name
		myName = randomNames[uniform(0, randomNames.length)];
		send(createPacket(LoginPacket(myName)));
	}

	void handleSessionInfoPacket(ubyte[] packetData, UserId peer)
	{
		SessionInfoPacket loginInfo = unpackPacket!SessionInfoPacket(packetData);

		userNames = loginInfo.userNames;
		myId = loginInfo.yourId;

		writefln("Client %s: my id is %s", myName[0], myId);

		// Send 3 hello message packets.
		foreach(i; 0..3)
		{
			string str = format("hello from %s %s", myName, i);
			ubyte[] packet = createPacket(MessagePacket(0, str));
			send(packet);
		}

		//send(createPacket(MessagePacket(0, "/stop")));
		flush();
	}

	void handleUserLoggedInPacket(ubyte[] packetData, UserId peer)
	{
		UserLoggedInPacket newUser = unpackPacket!UserLoggedInPacket(packetData);
		userNames[newUser.userId] = newUser.userName;
		writefln("Client %s: %s has connected", myName[0], newUser.userName);
	}

	void handleUserLoggedOutPacket(ubyte[] packetData, UserId peer)
	{
		UserLoggedOutPacket packet = unpackPacket!UserLoggedOutPacket(packetData);
		writefln("Client %s: %s has disconnected", myName[0], userName(packet.userId));
		userNames.remove(packet.userId);
	}

	void handleMessagePacket(ubyte[] packetData, UserId peer)
	{
		MessagePacket msg = unpackPacket!MessagePacket(packetData);
		if (msg.userId == 0)
			writefln("Client %s: %s", myName[0], msg.msg);
		else
			writefln("Client %s: %s> %s", myName[0], userName(msg.userId), msg.msg);
	}

	override void onDisconnect(ref ENetEvent event)
	{
		writefln("Client: disconnected with data %s", event.data);

		// Reset server's information
		event.peer.data = null;
		
		isRunning = false;
	}
}