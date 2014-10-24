module clientapp;

import std.datetime;
import std.stdio;
import std.conv : to;


import derelict.enet.enet;

import anchovy.gui;
import anchovy.graphics.windows.glfwwindow;
import anchovy.gui.application.application;
import anchovy.gui.databinding.list;

import client;
import connection;
import packets;

class MessageInputBehavior : EditBehavior
{
	void delegate() onEnter;

	override bool keyPressed(Widget widget, KeyPressEvent event)
	{
		if (event.keyCode == KeyCode.KEY_ENTER)
		{
			if (onEnter) onEnter();
			return true;
		}
		else
		{
			return super.keyPressed(widget, event);
		}
	}
}

class ChatClientApp : Application!GlfwWindow
{
	Client client;
	SimpleList!dstring messageList;
	Widget msgInput;
	MessageInputBehavior messageInput;

	this(uvec2 windowSize, string caption)
	{
		super(windowSize, caption);
	}

	override void update(double dt)
	{
		if (client) client.update(0);

		fpsHelper.update(dt);
		timerManager.updateTimers(window.elapsedTime);
		context.update(dt);
	}

	override void load(in string[] args)
	{
		renderer.setClearColor(Color(255,255,255));
		messageList = new SimpleList!dstring;

		context.behaviorFactories["messageInput"] ~= delegate IWidgetBehavior (){return new MessageInputBehavior;};

		templateManager.parseFile("chat.sdl");

		auto mainLayer = context.createWidget("mainLayer");
		context.addRoot(mainLayer);

		msgInput = context.getWidgetById("messsageInput");
		messageInput = msgInput.getWidgetBehavior!MessageInputBehavior();
		messageInput.onEnter = &onEnter;

		context.getWidgetById("connect").addEventHandler(&onConnect);
		context.getWidgetById("messages").setProperty!("list", List!dstring)(messageList);
		messageList.push("first");
	}

	override void unload()
	{
		if (client) client.stop();
	}

	void printfln(Args...)(string fmt, Args args)
	{
		writefln(fmt, args);
		messageList.push(format(fmt, args).to!dstring);
	}

	bool onConnect(Widget widget, PointerClickEvent event)
	{
		string address = context.getWidgetById("ip")["text"].coerce!string;
		ushort port = context.getWidgetById("port")["text"].coerce!ushort;
		string name = context.getWidgetById("nick")["text"].coerce!string;

		if (!client)
		{
			client = new Client();
			client.registerPacketHandler!SessionInfoPacket(&handleSessionInfoPacket);
			client.registerPacketHandler!UserLoggedInPacket(&handleUserLoggedInPacket);
			client.registerPacketHandler!UserLoggedOutPacket(&handleUserLoggedOutPacket);
			client.registerPacketHandler!MessagePacket(&handleMessagePacket);

			client.disconnectHandler = &onDisconnect;

			client.start();
		}

		writefln("%s", address);

		client.connect(name, address, port);

		return true;
	}

	void onDisconnect()
	{
		printfln("Disconnected from server");
	}

	void onEnter()
	{
		if (client && client.isRunning)
		{
			if (messageInput.text.length > 0)
			{
				writefln("enter");
				sendMessage(messageInput.text.to!string);
				messageInput.text = null;
			}
		}
	}

	void sendMessage(string msg)
	{
		ubyte[] packet = client.createPacket(MessagePacket(0, msg));
		client.send(packet);
	}

	void handleSessionInfoPacket(ubyte[] packetData, UserId peer)
	{
		SessionInfoPacket loginInfo = client.unpackPacket!SessionInfoPacket(packetData);

		client.userNames = loginInfo.userNames;
		client.myId = loginInfo.yourId;

		writefln("my id is %s", client.myId);
	}

	void handleUserLoggedInPacket(ubyte[] packetData, UserId peer)
	{
		UserLoggedInPacket newUser = client.unpackPacket!UserLoggedInPacket(packetData);
		client.userNames[newUser.userId] = newUser.userName;
		printfln("%s has connected", newUser.userName);
	}

	void handleUserLoggedOutPacket(ubyte[] packetData, UserId peer)
	{
		UserLoggedOutPacket packet = client.unpackPacket!UserLoggedOutPacket(packetData);
		printfln("%s has disconnected", client.userName(packet.userId));
		client.userNames.remove(packet.userId);
	}

	void handleMessagePacket(ubyte[] packetData, UserId peer)
	{
		MessagePacket msg = client.unpackPacket!MessagePacket(packetData);
		if (msg.userId == 0)
			printfln("%s", msg.msg);
		else
			printfln("%s> %s", client.userName(msg.userId), msg.msg);
	}

	override void closePressed()
	{
		isRunning = false;
	}
}

version(linux)
{
	pragma(lib, "dl");
}

void main(string[] args)
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

	auto app = new ChatClientApp(uvec2(450, 500), "Chat");
	app.run(args);
}