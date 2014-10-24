#Enet tutorials

##About

This is a collection of ENet tutorials and examples written in D programming language.

## Tutorials

1. Simple client/server example. It has Server and Client structs with some convenience methods.<br/>
To build use `dub build :tut01`.

2. Extends first example by adding abstract Connection class from which both client and server are derived. In this tutorial a packet system is implemented. Serialization/deserealization is done with cbor-d package. Packet system allows for easy sending and receiving of structs. It has a basic chat protocol.<br/>
To build use `dub build :tut02`.

3. A client/server chat application. Client is a gui application that uses anchovy library for gui. A simple user storage on server is implemented. Client and server implemented as separate configurations, with client being the default one.<br/>
You can build a client with `dub build :tut03 --config=client`, or simply by `dub build :tut03`.<br/>
A server is built like `dub build :tut03 --config=server`.

### Tutorial 3 animation
![chat](https://cloud.githubusercontent.com/assets/1129910/4772200/de819eca-5b95-11e4-875f-48f20939fc8e.gif)
