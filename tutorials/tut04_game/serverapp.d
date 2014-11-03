/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

import connection : ConnectionSettings, loadEnet;
import derelict.enet.enet;
import packets : registerPackets;
import server : Server;

void main()
{
	loadEnet();

	auto server = new Server();
	

	ConnectionSettings settings = {null, 32, 2, 0, 0};
	server.start(settings, ENET_HOST_ANY, 1234);
	while (server.isRunning)
	{
		server.update(100);
	}

	server.stop();
}