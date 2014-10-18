module connection;

import std.stdio;

import derelict.enet.enet;
import cbor;


//version = debug_packets;

// Stores info about connected peer. Used in server
struct PeerInfo
{
	size_t id;
	ENetPeer* peer;
}

/// Packet handler.
/// Returns true if data was valid and false otherwise.
alias PacketHandler = void delegate(ubyte[] packetData, ref PeerInfo peer);

struct PacketInfo
{
	string name;
	PacketHandler handler;
	TypeInfo packetType;
	size_t id;
}

abstract class Connection
{
	// Local side of connection.
	ENetHost* host;

	// Used when handling packet based on its id.
	PacketInfo[] packetArray;
	// Used to get packet id when sending packet.
	PacketInfo[TypeInfo] packetMap;

	ubyte[] buffer = new ubyte[1024*1024];

	string side;

	size_t packetId(P)()
	{
		return packetMap[typeid(P)].id;
	}

	string packetName(size_t packetId)
	{
		if (packetId >= packetArray.length) return "!Unknown!";
		return packetArray[packetId].name;
	}

	void registerPacket(P)(PacketHandler handler = null, string packetName = P.stringof)
	{
		size_t newId = packetArray.length;
		PacketInfo pinfo = PacketInfo(packetName, handler, typeid(P), newId);
		packetArray ~= pinfo;
		assert(typeid(P) !in packetMap);
		packetMap[typeid(P)] = pinfo;
	}

	bool handlePacket(size_t packetId, ubyte[] packetData, ref PeerInfo peerInfo)
	{
		if (packetId >= packetArray.length)
			return false; // invalid packet

		auto handler = packetArray[packetId].handler;
		if (handler is null)
			return false; // handler is not set

		handler(packetData, peerInfo);
		return true;
	}

	ubyte[] createPacket(P)(auto ref P packet)
	{
		ubyte[] bufferTemp = buffer;
		size_t size;

		version(debug_packets) writefln("%s: creating packet %s with id %s", side, P.stringof, packetId!P);
		version(debug_packets) writefln("%s: with fields {%s}:%s", side, packet.tupleof, numEncodableMembers!(packet));
		
		size = encodeCbor(bufferTemp[], packetId!P);
		
		version(debug_packets) writef("%s: size %s, bufferTemp[0]%02x", side, size, bufferTemp[0]);
		version(debug_packets) writefln(" %s", decodeCbor(bufferTemp[0..1]));
		
		size += encodeCbor(bufferTemp[size..$], packet);
		return bufferTemp[0..size];
	}

	// packetData must contain data with packet id stripped off.
	auto ref P unpackPacket(P)(ubyte[] packetData)
	{
		return decodeCborSingleDup!P(packetData); // TODO: check for excess data.
	}

	void printPacketMap()
	{
		foreach(i, packetInfo; packetArray)
		{
			writefln("% 2s: %s", i, packetInfo.name);
		}
	}

	void flush()
	{
		enet_host_flush(host);
	}

	void stop()
	{
		enet_host_destroy(host);
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

	void onConnect(ref ENetEvent event)
	{
	}

	void onPacketReceived(ref ENetEvent event)
	{
		try
		{
			ubyte[] packetData = event.packet.data[0..event.packet.dataLength];
			auto fullPacketData = packetData;
			size_t packetId = cast(size_t)decodeCborSingle!ulong(packetData); // decodes and pops ulong from range.

			version(debug_packets) writefln("%s: %s:%s received len %s | text %s | hex %(%02x%)",
				side, packetName(packetId), packetId,
				event.packet.dataLength, cast(char[])fullPacketData, fullPacketData);

			handlePacket(packetId, packetData, *cast(PeerInfo*)event.peer.data);
		}
		catch(CborException e)
		{
			writeln(e);
		}
	}

	void onDisconnect(ref ENetEvent event)
	{
	}
}