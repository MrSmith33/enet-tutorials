/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module baseserver;

import std.stdio;
import std.range;

import derelict.enet.enet;

import connection;
import clientstorage;

abstract class BaseServer(Client) : Connection
{
	ClientStorage!Client clientStorage;
	
	void start(ConnectionSettings settings, uint host, ushort port)
	{
		ENetAddress address;
		address.host = host;
		address.port = port;
		settings.address = &address;

		super.start(settings);
	}

	void disconnectAll()
	{
		foreach(user; clientStorage.byClient)
		{
			enet_peer_disconnect(user.peer, 0);
		}
	}

	/// Sending
	void sendTo(R)(R clients, ubyte[] data, ubyte channel = 0)
		if (isInputRange!R && is(ElementType!R == UserId))
	{
		ENetPacket *packet = enet_packet_create(data.ptr, data.length,
				ENET_PACKET_FLAG_RELIABLE);
		sendTo(clients, packet, channel);
	}

	/// ditto
	void sendTo(R)(R clients, ENetPacket* packet, ubyte channel = 0)
		if (isInputRange!R && is(ElementType!R == UserId))
	{
		foreach(clientId; clients)
		{
			if (auto client = clientStorage[clientId])
				enet_peer_send(client.peer, channel, packet);
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
}