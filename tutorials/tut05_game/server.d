module server;

import connection;
import derelict.enet.enet;
import baseserver;

struct Client
{
	ENetPeer* peer;
}

class Server : BaseServer!Client
{
	this(ConnectionSettings settings, uint host, ushort port)
	{
		super(settings, host, port);
	}
}