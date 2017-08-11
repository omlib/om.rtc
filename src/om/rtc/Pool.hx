package om.rtc;

import haxe.Json;
import haxe.ds.IntMap;
import js.Browser.console;
import js.Promise;
import js.html.WebSocket;
import js.html.rtc.DataChannel;
import js.html.rtc.IceCandidate;
import js.html.rtc.PeerConnection;
import js.html.rtc.Configuration;
import js.html.rtc.SessionDescription;

class Pool {

    public dynamic function onDisconnect( e : Dynamic ) {}
    //public dynamic function onSignal( msg : Dynamic ) {}

    public dynamic function onPeerConnect( peer : Peer ) {}
    public dynamic function onPeerDisconnect( peer : Peer ) {}
    public dynamic function onPeerMessage( peer : Peer, msg : String ) {}

    public var ip(default,null) : String;
    public var port(default,null) : Int;
    public var peers(default,null) : Map<String,Peer>;
    public var numPeers(default,null) = 0;
    public var myid(default,null) : String;

    var statusRequested = false;
    var config : Dynamic; // my config
    var server : WebSocket;

    //TODO
    var dataChannelConfig = {
        ordered: false,
        outOfOrderAllowed: true,
        //maxRetransmitTime: 400,
        //maxPacketLifeTime: 1000
    };

    public function new( ip : String, port : Int, config : Dynamic ) {
        this.ip = ip;
        this.port = port;
        this.config = config;
    }

    public function connect() {

        peers = new Map();
        numPeers = 0;

        return new Promise( function(resolve,reject){

            server = new WebSocket( 'ws://$ip:$port' );
            server.addEventListener( 'open', function(e){
                trace( 'Singal server connected' );
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

                var msg = Json.parse( e.data );
                //console.log(msg);

                switch msg.type {

                case 'init':

                    myid = msg.id;
                    trace( "My id:"+Std.string( msg.id ) );

                    var peerIds : Array<Dynamic> = msg.peers;
                    if( peerIds.length == 0 ) {
                        statusRequested = true;
                    } else {
                        for( id in peerIds ) {
                            var peer = createPeer( id );
                            peer.connectTo( createDataChannelId(), dataChannelConfig ).then( function(sdp){
                                signal( { type: 'offer', id: id, sdp: sdp } );
                            }).catchError( function(e){
                                trace(e);
                            });
                        }
                    }

                    resolve( cast null );

                case 'offer':
                    var peer = createPeer( msg.id );
                    peer.connectFrom( msg.sdp, msg.candidates ).then( function(sdp){
                        signal( { type: 'answer', id: peer.id, sdp: sdp } );
                    }).catchError( function(e){
                        trace('ERROR');
                    });

                case 'candidate':
                    var peer = peers.get( msg.id );
                    peer.addIceCandidate( msg.candidate );

                case 'answer':
                    var peer = peers.get( msg.id );
                    peer.setRemoteDescription( msg.sdp );//.then( function(_){
                        //trace('oi');
                        //peer.send({type:"fucvk"});
                    //});
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

    public inline function signal( msg : Dynamic ) {
        server.send( Json.stringify( msg ) );
    }

    public inline function broadcast( msg : Dynamic  ) {
        for( peer in peers ) peer.send( Json.stringify( msg ) );
    }

    function createDataChannelId() : String {
        return Util.createRandomString( 8 );
    }

    function createPeer( id : String ) : Peer {

        var config = {
            'iceServers': [
                { 'url': 'stun:stun.l.google.com:19302' },
                { 'url': 'stun:stun1.l.google.com:19302' },
                { 'url': 'stun:stun2.l.google.com:19302' },
                { 'url': 'stun:stun3.l.google.com:19302' },
                { 'url': 'stun:stun4.l.google.com:19302' },
            ]
        };

        var peer = new Peer( id, config );
        peers.set( peer.id, peer );
        numPeers++;

        peer.onCandidate = function(e) {
            server.send( Json.stringify( {
                type: 'candidate',
                id: peer.id,
                candidate: e,
            } ) );
        }
        peer.onConnect = function() {
            if( !statusRequested ) {
                peer.send( Json.stringify( { type: 'join' } ) );
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

        return peer;
    }

    function cleanup() {
        peers = new Map();
        numPeers = 0;
    }
}
