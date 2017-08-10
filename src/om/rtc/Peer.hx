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

class Peer {

    public dynamic function onCandidate( e : Dynamic ) {}
    public dynamic function onConnect() {}
    public dynamic function onDisconnect() {}
    public dynamic function onMessage( msg : Dynamic ) {}

    public var id(default,null) : String;
    public var connected(default,null) = false;
    public var initiator(default,null) : Bool;

    var connection : PeerConnection;
    var channel : DataChannel;

    public function new( id : String, ?config : Configuration ) {
        this.id = id;
        connection = new PeerConnection( config );
    }

    public function send( msg : Dynamic ) {
        if( connected ) {
            channel.send( Json.stringify( msg ) );
        }
    }

    @:allow(om.rtc.Pool)
    function connectTo() {

        initiator = true;

        return new Promise( function(resolve,reject){

            connection.onicecandidate = function(e){
                if( e.candidate != null ) {
                    onCandidate( e.candidate );
                }
            }

            setDataChannel( connection.createDataChannel( "letterspace-"+id, {
                //ordered: false,
                //outOfOrderAllowed: true,
                //maxRetransmitTime: 400,
                //maxPacketLifeTime: 1000
            } ) );

            connection.onnegotiationneeded = function() {
                connection.createOffer()
                    .then( function(desc) connection.setLocalDescription( desc ) )
                    .then( function(_) {
                        resolve( connection.localDescription );
                    }
                );
            }
        });
    }

    @:allow(om.rtc.Pool)
    function addIceCandidate( candidate : Dynamic ) {
        connection.addIceCandidate( new IceCandidate( candidate ) );
    }

    @:allow(om.rtc.Pool)
    function connectFrom( sdp : Dynamic, candidates : Array<Dynamic> ) {

        initiator = false;

        return new Promise( function(resolve,reject) {

            connection.oniceconnectionstatechange = function(e){
                //trace(e);
            }
            connection.onicecandidate = function(e){
                if( e.candidate != null ) {
                    onCandidate( e.candidate );
                }
            }
            connection.ondatachannel = function(e){
                setDataChannel( e.channel );
            }
            connection.setRemoteDescription( new SessionDescription( sdp ) ).then( function(_){
                connection.createAnswer().then( function(answer){
                    connection.setLocalDescription( answer ).then( function(e){
                        resolve( connection.localDescription );
                    });
                });
            });
        });
    }

    @:allow(om.rtc.Pool)
    function setRemoteDescription( sdp : Dynamic ) {
        connection.setRemoteDescription( new SessionDescription( sdp ) ).then( function(e){
        });
    }

    @:allow(om.rtc.Pool)
    function disconnect() {
        if( connected ) {
            connected = false;
            channel.close();
            connection.close();
        }
    }

    function setDataChannel( channel : DataChannel ) {
        this.channel = channel;
        channel.onopen = e -> {
            trace( "Data channel opened" );
            connected = true;
            onConnect();
        }
        channel.onmessage = e -> {
            var msg = Json.parse( e.data );
            onMessage( msg );
        };
        channel.onclose = e -> {
            trace( "Data channel closed" );
            connected = false;
            onDisconnect();
        }
        channel.onerror = e -> {
            trace( "Data channel error" );
            connected = false;
            onDisconnect();
        }
    }
}
