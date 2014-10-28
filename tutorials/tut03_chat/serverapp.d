/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

import std.datetime;
import std.stdio;

import derelict.enet.enet;

import server;

void serverWorker()
{
	writefln("Server: Starting");
	
	Server server = new Server;

	ServerSettings settings = {1234, 32, 2, 0, 0};
	server.start(settings);

	while (server.isRunning)
	{
		server.update(50);
	}

	server.stop();
}

void main()
{
	DerelictENet.load();

	int err = enet_initialize();

	if (err != 0)
	{
		writefln("Error loading ENet library");
		return;
	}
	else
	{
		ENetVersion ever = enet_linked_version();
		writefln("Loaded ENet library v%s.%s.%s",
			ENET_VERSION_GET_MAJOR(ever),
			ENET_VERSION_GET_MINOR(ever),
			ENET_VERSION_GET_PATCH(ever));
	}

	serverWorker();
}