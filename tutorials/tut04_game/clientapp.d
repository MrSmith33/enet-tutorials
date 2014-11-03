/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module clientapp;

import core.thread;
import std.conv : to;
import std.stdio : writefln, writeln;
import std.string : format;
import std.random : uniform;

import derelict.enet.enet;

import connection;
import baseclient;
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

class Client : BaseClient
{
	ENetAddress serverAddress;
	ENetPeer* server;

	ClientId myId;
	string myName;

	string[ClientId] clientNames;
	
	string clientName(ClientId clientId)
	{
		return clientId in clientNames ? clientNames[clientId] : format("? %s", clientId);
	}

	override void start(ConnectionSettings settings)
	{
		registerPackets(this);
		super.start(settings);
		
		registerPacketHandler!SessionInfoPacket(&handleSessionInfoPacket);
		registerPacketHandler!ClientLoggedInPacket(&handleUserLoggedInPacket);
		registerPacketHandler!ClientLoggedOutPacket(&handleUserLoggedOutPacket);
		registerPacketHandler!MessagePacket(&handleMessagePacket);
	}

	override void onConnect(ref ENetEvent event)
	{
		writefln("Client: Connection to 127.0.0.1:1234 established");

		// generate random name
		myName = randomNames[uniform(0, randomNames.length)];
		send(createPacket(LoginPacket(myName)));
	}

	void handleSessionInfoPacket(ubyte[] packetData, ClientId peer)
	{
		SessionInfoPacket loginInfo = unpackPacket!SessionInfoPacket(packetData);

		clientNames = loginInfo.clientNames;
		myId = loginInfo.yourId;

		send(createPacket(ReadyPacket(true)));
		flush();
	}

	void handleUserLoggedInPacket(ubyte[] packetData, ClientId peer)
	{
		ClientLoggedInPacket newUser = unpackPacket!ClientLoggedInPacket(packetData);
		clientNames[newUser.clientId] = newUser.clientName;
		writefln("Client %s: %s has connected", myName[0], newUser.clientName);
	}

	void handleUserLoggedOutPacket(ubyte[] packetData, ClientId peer)
	{
		ClientLoggedOutPacket packet = unpackPacket!ClientLoggedOutPacket(packetData);
		writefln("Client %s: %s has disconnected", myName[0], clientName(packet.clientId));
		clientNames.remove(packet.clientId);
	}

	void handleMessagePacket(ubyte[] packetData, ClientId peer)
	{
		MessagePacket msg = unpackPacket!MessagePacket(packetData);
		if (msg.clientId == 0)
			writefln("Client %s: %s", myName[0], msg.msg);
		else
			writefln("Client %s: %s> %s", myName[0], clientName(msg.clientId), msg.msg);
	}

	override void onDisconnect(ref ENetEvent event)
	{
		writefln("Client: disconnected with data %s", event.data);

		// Reset server's information
		event.peer.data = null;
		
		isRunning = false;
	}
}

void main(string[] args)
{
	loadEnet();

	auto client = new Client;

	ConnectionSettings settings = {null, 1, 2, 0, 0};
	client.start(settings);
	writefln("%s", client.isRunning);
	client.connect("127.0.0.1", 1234);
	while (client.isRunning)
	{
		client.update(100);
	}

	client.stop();
}