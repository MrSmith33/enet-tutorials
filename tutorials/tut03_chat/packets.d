/**
Copyright: Copyright (c) 2014 Andrey Penechko.
License: a$(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors: Andrey Penechko.
*/

module packets;

// client request
struct LoginPacket
{
	string userName;
}

// server response
struct SessionInfoPacket
{
	size_t yourId;
	string[size_t] userNames;
}

struct UserLoggedInPacket
{
	size_t userId;
	string userName;
}

struct UserLoggedOutPacket
{
	size_t userId;
}

// sent from client with peer == 0 and from server with userId of sender.
struct MessagePacket
{
	size_t userId; // from. Set to 0 when sending from client
	string msg;
}