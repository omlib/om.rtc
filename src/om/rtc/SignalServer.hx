package om.rtc;

#if nodejs

import haxe.Json;
import haxe.crypto.Base64;
import haxe.ds.IntMap;
import js.Promise;
import js.node.Buffer;
import js.node.Net;
import js.node.net.Socket;
import om.net.WebSocket;

private class Peer {

    static var peer_id = 0;

    public var id(default,null) : String;
    public var n(default,null) : Int;
    //public var time(default,null) : Float;

    @:allow(letterspace.net.Server)
    public var config(default,null) : Dynamic;

    var socket : Socket;

    public function new( socket : Socket, id : String ) {
        this.socket = socket;
        this.id = id;
        n = peer_id++;
    }

    public function send( msg : Dynamic ) {
        var str = Json.stringify( msg );
        socket.write( WebSocket.writeFrame( new Buffer( str ) ) );
    }

    public function disconnect() {
        socket.end();
    }
}

class SignalServer {

    public dynamic function onPeerConnect( peer : Peer ) {}
    public dynamic function onPeerDisconnect( peer : Peer ) {}
    public dynamic function onPeerMessage( peer : Peer, msg : Dynamic ) {}

    public var ip(default,null) : String;
    public var port(default,null) : Int;
    public var peers(default,null) : Map<String,Peer>;
    public var numPeers(default,null) : Int;

    var net : js.node.net.Server;

    public function new( ip : String, port : Int ) {
        this.ip = ip;
        this.port = port;
    }

    public function start() : Promise<Dynamic> {

        return new Promise( (resolve,reject)->{

            numPeers = 0;
            peers = new Map();

            net = Net.createServer( (socket:Socket)->{

                var id = Util.createRandomString( 4 );
                var peer = new Peer( socket, id );
                peers.set( id, cast peer );
                numPeers++;

                socket.once( 'close', function(e) {
                    peers.remove( peer.id );
                    numPeers--;
                    //log( peer.id + ' disconnected ['+peer.id+']['+numPeers+']' );
                    onPeerDisconnect( peer );
                    //log( 'Peer[$id] disconnected ['+numPeers+']' );
                });

                socket.once( 'data', buf -> {

                    socket.write( WebSocket.createHandshake( buf ) );

                    //log( 'Peer $numPeers connected [$id]' );
                    //log( 'connected $id' );
                    //log( peer.id + ' connected ['+peer.n+']['+numPeers+']' );
                    onPeerConnect( peer );

                    peer.send( {
                        type: 'init',
                        id: id,
                        peers: [for(p in peers) if(p.id != id) p.id]
                    });

                    var buffer = '';

                    socket.addListener( 'data', function(buf){

                        if( buf == null ) return;
                        buf = WebSocket.readFrame( buf );
                        if( buf == null ) return;

                        buffer += buf.toString();
                        var msg : Dynamic;
                        //var str = buffer + buf.toString();
                        try {
                            msg = Json.parse( buffer );
                        } catch(e:Dynamic) {
                            return;
                        }

                        onPeerMessage( peer, msg );

                        buffer = '';

                        //log( 'Peer[$id] message '+haxe.format.JsonPrinter.print(msg) );
                        //var peerId : Int = msg.id;
                        //log( 'Message from '+peer.id+' for'+msg.id+' of type '+msg.type );

                        switch msg.type {

                        case 'offer','answer','candidate':


                            var receiver = peers.get( msg.id );

                            //log( peer.id +' >> '+receiver.id + ' '+ msg.type );

                            msg.id = id;
                            receiver.send( msg );

                        default:
                            trace( 'Unknown type message: '+msg );
                        }
                    } );
                });
            });

            net.listen( port, ip, ()->{
                resolve( null );
            });
        });
    }
}

#end
