/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

import connection;
import derelict.enet.enet;

void main()
{
	loadEnet();

	ENetAddress* address = new ENetAddress(ENET_HOST_ANY, 1234);
	ConnectionSettings settings = {address, 32, 2, 0, 0};
	//auto server = new Server();

	//server.start(settings);

	//while (server.isRunning)
	//{
	//	server.update(100);
	//}

	//server.stop();
}