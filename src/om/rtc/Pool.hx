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
    public dynamic function onPeerMessage( peer : Peer, msg : Dynamic ) {}

    public var ip(default,null) : String;
    public var port(default,null) : Int;

    public var peers(default,null) : Map<String,Peer>;
    public var numPeers(default,null) = 0;

    var server : WebSocket;
    var myId : String;
    var timeJoinded : Float;
    var statusRequested = false;
    var config : Dynamic; // my config

    public function new( ip : String, port : Int ) {
        this.ip = ip;
        this.port = port;
    }

    public function join( config : Dynamic ) {

        this.config = config;

        return new Promise( function(resolve,reject){

            peers = new Map();

            server = new WebSocket( 'ws://$ip:$port' );
            server.addEventListener( 'open', function(e){
                trace( 'Singal server connected' );
                //var msg : Dynamic = { type: 'init' };
                //if( config != null ) Reflect.setField( msg, 'config', config );
                //signal( msg );
            });
            server.addEventListener( 'close', function(e){
                switch e.code {
                case 1000: onDisconnect( null );
                //case 1006:
                default: onDisconnect( 'close' );
                }
            });
            server.addEventListener( 'error', function(e){
                console.log( e.toString() );
                reject( 'server error' );
                switch e.code {
                case 1000: onDisconnect( null );
                //case 1006:
                default: onDisconnect( 'error' );
                }
            });
            server.addEventListener( 'message', function(e){

                var msg = Json.parse( e.data );
                console.log(msg);

                switch msg.type {

                case 'init':

                    myId = msg.id;

                    trace( "My id:"+Std.string( msg.id ) );

                    //resolve( cast null );

                    var peerIds : Array<Dynamic> = msg.peers;
                    if( peerIds.length == 0 ) {
                        statusRequested = true;
                        resolve( cast null );
                    } else {
                        for( id in peerIds ) {
                            var peer = createPeer( id );
                            peer.connectTo().then( function(sdp){
                                //signal( { type: 'offer', id: id, sdp: res.sdp, candidates: res.candidates } );
                                signal( { type: 'offer', id: id, sdp: sdp } );
                            }).catchError( function(e){
                                trace(e);
                            });
                        }
                        resolve( cast null );
                    }

                case 'offer':
                    var peer = createPeer( msg.id );
                    peer.connectFrom( msg.sdp, msg.candidates ).then( function(sdp){
                        //signal( { type: 'answer', id: peer.id, sdp: res.sdp, candidates: res.candidates } );
                        signal( { type: 'answer', id: peer.id, sdp: sdp } );
                    }).catchError( function(e){
                        trace(e);
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

    public inline function signal( msg : Dynamic ) {
        server.send( Json.stringify( msg ) );
    }

    public inline function broadcast( msg : Dynamic  ) {
        for( peer in peers ) {
            peer.send( msg );
        }
    }

    public function leave() {
        for( peer in peers ) peer.disconnect();
        peers = null;
        server.close();
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
            trace( "onConnect "+statusRequested );
            if( !statusRequested ) {
                peer.send( { type: 'join' } );
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
}
