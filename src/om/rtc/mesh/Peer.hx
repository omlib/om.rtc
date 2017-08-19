package om.rtc.mesh;

import haxe.Json;
import haxe.ds.IntMap;
import js.Browser.console;
import js.Promise;
import js.html.MediaStream;
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
    public var connection(default,null) : PeerConnection;
    public var channel(default,null) : DataChannel;

    public function new( id : String, ?config : Configuration ) {

        this.id = id;

        connection = new PeerConnection( config );
        connection.onicecandidate = function(e){
            if( e.candidate != null ) {
                onCandidate( e.candidate );
            }
        }
        connection.oniceconnectionstatechange = function(e){
            //console.log(e);
            switch e.iceConnectionState {
            case 'disconnected':
                connected = false;
                //channel.close();
                onDisconnect();
            }
        }
    }

    public function sendMessage( msg : Dynamic ) {
        if( connected ) {
            channel.send( Json.stringify( msg ) );
        }
    }

    public function send( str : String ) {
        if( connected ) {
            channel.send( str );
        }
    }

    public function addStream( stream : MediaStream ) {
        connection.addStream( stream );
    }

    @:allow(om.rtc.mesh.Pool)
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

    @:allow(om.rtc.mesh.Pool)
    function connectFrom( sdp : Dynamic ) {

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

    @:allow(om.rtc.mesh.Pool)
    function addIceCandidate( candidate : Dynamic ) {
        connection.addIceCandidate( new IceCandidate( candidate ) );
    }

    @:allow(om.rtc.mesh.Pool)
    function setRemoteDescription( sdp : Dynamic ) {
        //if( !initiator )
        return connection.setRemoteDescription( new SessionDescription( sdp ) );
    }

    @:allow(om.rtc.mesh.Pool)
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
            connected = true;
            onConnect();
        }
        channel.onmessage = function(e) {
            onMessage( e.data );
        };
        channel.onclose = function(e) {
            //connection.close();
            connected = false;
            onDisconnect();
        }
        channel.onerror = function(e) {
            //connection.close();
            connected = false;
            onDisconnect();
        }
    }
}
