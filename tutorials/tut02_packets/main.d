import std.concurrency;
import std.datetime;
import core.thread;
import std.stdio;

import derelict.enet.enet;

import client;
import server;


void clientWorker(uint workTimeMsecs)
{
	Client client = new Client;

	client.start();

	TickDuration startTime = Clock.currAppTick;

	while (client.isRunning)
	{
		client.update(50);

		if (Clock.currAppTick - startTime > TickDuration.from!"msecs"(workTimeMsecs))
		{
			client.isRunning = false;
		}
	}

	client.stop();
}

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

	spawn(&serverWorker);
	spawn(&clientWorker, 2500);
	spawn(&clientWorker, 10);
	spawn(&clientWorker, 10);

	thread_joinAll;
}