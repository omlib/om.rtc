package om.rtc;

import haxe.Json;
import haxe.ds.IntMap;
import js.Browser.console;
import js.Promise;
import js.html.WebSocket;
import js.html.rtc.Configuration;
import js.html.rtc.DataChannel;
import js.html.rtc.DataChannelInit;
import js.html.rtc.IceCandidate;
import js.html.rtc.PeerConnection;
import js.html.rtc.SessionDescription;

class Peer {

    public dynamic function onCandidate( e : IceCandidate ) {}
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
        connection.onicecandidate = function(e){
            if( e.candidate != null ) {
                onCandidate( e.candidate );
            }
        }
        connection.oniceconnectionstatechange = function(e){
            //trace(e);
        }
    }

    public function send( msg : Dynamic ) {
        if( connected ) {
            channel.send( msg );
        }
    }

    @:allow(om.rtc.Pool)
    function connectTo( channelId : String, ?channelConfig : DataChannelInit ) {

        initiator = true;

        setDataChannel( connection.createDataChannel( channelId, channelConfig ) );

        return new Promise( function(resolve,reject){
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
    function connectFrom( sdp : Dynamic, candidates : Array<Dynamic> ) {

        initiator = false;

        connection.ondatachannel = function(e){
            setDataChannel( e.channel );
        }

        return new Promise( function(resolve,reject) {
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
    function addIceCandidate( candidate : Dynamic ) {
        connection.addIceCandidate( new IceCandidate( candidate ) );
    }

    @:allow(om.rtc.Pool)
    function setRemoteDescription( sdp : Dynamic ) {
        //if( !initiator )
        return connection.setRemoteDescription( new SessionDescription( sdp ) );
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
        channel.onopen = function(e) {
            //trace( "Data channel opened" );
            connected = true;
            onConnect();
        }
        channel.onmessage = function(e) {
            //var msg = Json.parse( e.data );
            onMessage( e.data );
        };
        channel.onclose = function(e) {
            //trace( "Data channel closed" );
            connected = false;
            onDisconnect();
        }
        channel.onerror = function(e) {
            //trace( "Data channel error" );
            connected = false;
            onDisconnect();
        }
    }
}
