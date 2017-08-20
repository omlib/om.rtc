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
import om.Nil;
import om.rtc.mesh.signal.Message;

class Pool {

    public dynamic function onData( data : Dynamic ) {}
    public dynamic function onDisconnect( e : Dynamic ) {}

    public dynamic function onPeerConnect( peer : Peer ) {}
    public dynamic function onPeerDisconnect( peer : Peer ) {}
    public dynamic function onPeerMessage( peer : Peer, msg : String ) {}

    public var ip(default,null) : String;
    public var port(default,null) : Int;

    public var id(default,null) : String;
    public var peerId(default,null) : String;
    public var peers(default,null) : Map<String,Peer>;
    public var numPeers(default,null) = 0;

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

    public function connect() : Promise<Nil> {

        return new Promise( function(resolve,reject){

            peers = new Map();

            server = new WebSocket( 'ws://$ip:$port' );
            server.addEventListener( 'open', function(e){
                //trace( 'Singal server connected' );
                signal({ type: MessageType.join, pool: id });
                resolve( nil );
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

                //handleSignal( msg );

                switch msg.type {

                case join:

                    peerId = msg.data.id;

                    var peerIds : Array<Dynamic> = msg.data.peers;
                    if( peerIds.length == 0 ) {
                        statusRequested = true;
                    } else {
                        for( id in peerIds ) {
                            var peer = createPeer( id );
                            peer.connectTo( dataChannelConfig ).then( function(sdp){
                                signal( { type: offer, peer: peer.id, data: sdp } );
                            }).catchError( function(e){
                                trace(e);
                            });
                        }
                    }

                    //TODO
                    resolve( nil );

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
                    peer.addIceCandidate( msg.data ).then( function(e){
                    });

                case answer:
                    var peer = peers.get( msg.peer );
                    peer.setRemoteDescription( msg.data );//.then( function(_){
                        //trace('oi');
                        //peer.send({type:"fucvk"});
                    //});

                case ping:
                    signal( { type: pong } );

                case pong:
                    //

                case data:
                    onData( msg.data );

                case error:
                    trace("TODO handle signal error msg");

                }
            });
        });
    }

    /*
    public function handleSignal( msg : Message ) {

        switch msg.type {

        case join:

            peerId = msg.data.id;

            var peerIds : Array<Dynamic> = msg.data.peers;
            if( peerIds.length == 0 ) {
                statusRequested = true;
            } else {
                for( id in peerIds ) {
                    var peer = createPeer( id );
                    peer.connectTo( dataChannelConfig ).then( function(sdp){
                        signal( { type: offer, peer: peer.id, data: sdp } );
                    }).catchError( function(e){
                        trace(e);
                    });
                }
            }

            //TODO
            //resolve( nil );

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
            peer.addIceCandidate( msg.data ).then( function(e){
            });

        case answer:
            var peer = peers.get( msg.peer );
            peer.setRemoteDescription( msg.data );//.then( function(_){
                //trace('oi');
                //peer.send({type:"fucvk"});
            //});

        case ping:
            signal( { type: pong } );

        case pong:
            //

        case data:
            onData( msg.data );

        case error:
            trace("TODO handle signal error msg");

        }
    }
    */

    public function signal( msg : Dynamic ) {
        msg.pool = this.id;
        var str = try Json.stringify( msg ) catch(e:Dynamic) {
            console.error(e);
            return;
        }
        server.send( str );
    }

    public function ping() {
        server.send( Json.stringify( { type: MessageType.ping } ) );
    }

    public inline function broadcast( data : String  ) {
        for( peer in peers ) peer.send( data );
    }

    public function destroy() {

        for( peer in peers ) peer.disconnect();
        peers = new Map();
        numPeers = 0;

        server.close();
    }

    //function addPeer( id : String ) : Peer {}

    function createPeer( id : String ) : Peer {

        var peer = new Peer( id, connectionConfig );
        peers.set( peer.id, peer );
        numPeers++;

        peer.onCandidate = function(e) {
            signal( {
                type: candidate,
                peer: peer.id,
                data: e,
            } );
        }
        peer.onConnect = function() {
            onPeerConnect( peer );
            if( !statusRequested ) {
                peer.sendMessage( { type: join } );
                statusRequested = true;
            }
        }
        peer.onMessage = function(msg) {
            onPeerMessage( peer, msg );
        }
        peer.onDisconnect = function(){
            peers.remove( peer.id );
            numPeers--;
            onPeerDisconnect( peer );
        }

        return peer;
    }

    function cleanup() {
        peers = new Map();
        numPeers = 0;
    }
}
