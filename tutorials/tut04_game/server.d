module server;

import connection;
import derelict.enet.enet;
import baseserver;
import packets;

struct Client
{
	ENetPeer* peer;
}

class Server : BaseServer!Client
{

}