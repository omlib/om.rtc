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

    public dynamic function onConnect() {}
    public dynamic function onDisconnect() {}
    public dynamic function onMessage( msg : Dynamic ) {}

    public var id(default,null) : String;
    //public var time(default,null) : Float;

    //@:allow(letterspace.net.Server)
    //public var config(default,null) : Dynamic;

    var socket : Socket;
    var isWebSocket : Bool;

    public function new( socket : Socket, id : String ) {

        this.socket = socket;
        this.id = id;

        isWebSocket = null;

        socket.once( 'close', function(e) {
            onDisconnect();
        });

        socket.addListener( 'data', function(buf:Buffer) {

            if( buf == null ) return;

            if( isWebSocket == null ) {
                if( buf.slice( 0, 10 ).toString() == 'GET / HTTP' ) {
                    socket.write( WebSocket.createHandshake( buf ) );
                    isWebSocket = true;
                    onConnect();
                    return;
                } else {
                    isWebSocket = false;
                    onConnect();
                }
            } else if( isWebSocket ) {
                buf = WebSocket.readFrame( buf );
                if( buf == null ) return;
            }

            //var str = buffer + buf.toString();
            var msg : Dynamic;
            try {
                msg = Json.parse( buf.toString() );
            } catch(e:Dynamic) {
                trace( e );
                return;
            }

            onMessage( msg );
        });
    }

    public function send( msg : Dynamic ) {
        var str = try Json.stringify( msg ) catch(e:Dynamic) {
            trace( e );
            return;
        }
        if( isWebSocket ) {
            socket.write( WebSocket.writeFrame( new Buffer( str ) ) );
        } else {
            socket.write( new Buffer( str ) );
        }
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
    public var numPeers(default,null) : Int;

    var net : js.node.net.Server;
    var peers : Map<String,Peer>;

    public function new( ip : String, port : Int ) {
        this.ip = ip;
        this.port = port;
    }

    public function start() : Promise<Dynamic> {

        peers = new Map();
        numPeers = 0;

        return new Promise( (resolve,reject)->{

            net = Net.createServer( (socket:Socket)->{

                var id = Util.createRandomString( 4 );
                var peer = new Peer( socket, id );
                peer.onConnect = function() {
                    peer.send( {
                        type: 'init',
                        id: id,
                        peers: [for(p in peers) if(p.id != id) p.id]
                    });
                    onPeerConnect( peer );
                }
                peer.onDisconnect = function() {
                    peers.remove( peer.id );
                    numPeers--;
                    onPeerDisconnect( peer );
                }
                peer.onMessage = function(msg) {
                    switch msg.type {
                    case 'offer','answer','candidate':
                        var receiver = peers.get( msg.id );
                        //log( peer.id +' >> '+receiver.id + ' '+ msg.type );
                        msg.id = id;
                        receiver.send( msg );
                    default:
                        trace( 'Unknown type message: '+msg );
                    }
                    onPeerMessage( peer, msg );
                }
                peers.set( id, cast peer );
                numPeers++;
            });

            net.listen( port, ip, function(){
                resolve( null );
            });
        });
    }
}

#end
