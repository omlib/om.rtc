package om.rtc.mesh;

import haxe.Json;
import haxe.ds.IntMap;
import js.Browser.console;
import js.Promise;
import js.html.WebSocket;
import js.html.rtc.Configuration;
import js.html.rtc.DataChannel;
import js.html.rtc.IceCandidate;
import js.html.rtc.PeerConnection;
import js.html.rtc.SessionDescription;
import om.rtc.mesh.signal.Message;

class Pool {

    //public dynamic function onSignal( msg : Dynamic ) {}
    public dynamic function onDisconnect( e : Dynamic ) {}

    public dynamic function onPeerConnect( peer : Peer ) {}
    public dynamic function onPeerDisconnect( peer : Peer ) {}
    public dynamic function onPeerMessage( peer : Peer, msg : String ) {}

    public var id(default,null) : String;
    public var ip(default,null) : String;
    public var port(default,null) : Int;
    public var peers(default,null) : Map<String,Peer>;
    public var numPeers(default,null) = 0;
    public var myid(default,null) : String;

    var connectionConfig : Configuration;
    var dataChannelConfig : Dynamic;
    var server : WebSocket;
    var statusRequested = false;

    public function new( id : String, ip : String, port : Int, connectionConfig : Configuration, dataChannelConfig : Dynamic ) {
        this.id = id;
        this.ip = ip;
        this.port = port;
        this.connectionConfig = connectionConfig;
        this.dataChannelConfig = dataChannelConfig;
    }

    public function connect() {

        peers = new Map();
        numPeers = 0;

        return new Promise( function(resolve,reject){

            server = new WebSocket( 'ws://$ip:$port' );
            server.addEventListener( 'open', function(e){
                trace( 'Singal server connected' );
                signal({ type: MessageType.join, pool: id });
            });
            server.addEventListener( 'close', function(e){
                console.log( e);
                onDisconnect( 'server disconnected' );
                reject( 'server error '+e.code );
            });
            server.addEventListener( 'error', function(e){
                console.log( e);
                onDisconnect( 'server error '+e.code );
                reject( 'server error '+e.code );
            });
            server.addEventListener( 'message', function(e){

                var msg : Message = try Json.parse( e.data ) catch(e:Dynamic) {
                    console.error(e);
                    //onDisconnect( 'server error '+e.code );
                    //reject( e );
                    return;
                }

                console.log(msg);

                switch msg.type {

                case join:
                    myid = msg.data.id;
                    var peerIds : Array<Dynamic> = msg.data.peers;
                    if( peerIds.length == 0 ) {
                        statusRequested = true;
                    } else {
                        for( id in peerIds ) {
                            var peer = createPeer( id );
                            peer.connectTo( createDataChannelId(), dataChannelConfig ).then( function(sdp){
                                signal( { type: offer, peer: peer.id, data: sdp } );
                            }).catchError( function(e){
                                trace(e);
                            });
                        }
                    }

                    resolve( cast null );

                case leave:

                case offer:
                    var peer = createPeer( msg.peer );
                    peer.connectFrom( msg.data ).then( function(sdp){
                        signal( { type: answer, peer: peer.id, data: sdp } );
                    }).catchError( function(e){
                        trace('ERROR '+e);
                    });

                case candidate:
                    var peer = peers.get( msg.peer );
                    peer.addIceCandidate( msg.data );

                case answer:
                    var peer = peers.get( msg.peer );
                    peer.setRemoteDescription( msg.data );//.then( function(_){
                        //trace('oi');
                        //peer.send({type:"fucvk"});
                    //});

                case error:
                    trace("TODO handle signal error msg");

                }
            });
        });
    }

    public function disconnect() {
        for( peer in peers ) peer.disconnect();
        peers = new Map();
        numPeers = 0;
        server.close();
    }

    public function signal( msg : Dynamic ) {
        //Reflect.setField( msg, 'pool', id );
        msg.pool = this.id;
        var str = Json.stringify( msg );
        server.send( str );
    }

    public inline function broadcast( msg : Dynamic  ) {
        for( peer in peers )
            peer.send( Json.stringify( msg ) );
    }

    function createDataChannelId() : String {
        return Util.createRandomString( 8 );
    }

    function createPeer( id : String ) : Peer {
        var peer = new Peer( id, connectionConfig );
        peer.onCandidate = function(e) {
            signal( {
                type: candidate,
                peer: peer.id,
                data: e,
            } );
        }
        peer.onConnect = function() {
            if( !statusRequested ) {
                peer.send( Json.stringify( { type: join } ) );
                statusRequested = true;
            }
            onPeerConnect( peer );
        }
        peer.onMessage = function(msg) {
            onPeerMessage( peer, msg );
        }
        peer.onDisconnect = function(){
            peers.remove( peer.id );
            numPeers--;
            onPeerDisconnect( peer );
        }
        peers.set( peer.id, peer );
        numPeers++;
        return peer;
    }

    function cleanup() {
        peers = new Map();
        numPeers = 0;
    }
}
