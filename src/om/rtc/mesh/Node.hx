package om.rtc.mesh;

import haxe.Json;
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

class Node {

    public dynamic function onCandidate( e : IceCandidate ) {}
    public dynamic function onConnect() {}
    public dynamic function onDisconnect() {}
    public dynamic function onMessage( msg : Message ) {}

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
            switch e.iceConnectionState {
            case 'disconnected':
                connected = false;
                onDisconnect();
            }
        }
    }

    @:overload( function( data : String ) : Void {} )
	@:overload( function( data : js.html.Blob ) : Void {} )
	@:overload( function( data : js.html.ArrayBuffer ) : Void {} )
    public function send( data : String ) {
        if( connected ) {
            channel.send( data );
        }
    }

    public function sendMessage( msg : Message ) {
        if( connected ) {
            var str = try Json.stringify( msg ) catch(e:Dynamic){
                console.error(e);
                return;
            }
            channel.send( str );
        }
    }

    public function addStream( stream : MediaStream ) {
        connection.addStream( stream );
    }

    public function createDataChannel( id : String, config : DataChannelInit ) : DataChannel {
        return connection.createDataChannel( id, config );
    }

    @:allow(om.rtc.mesh.Mesh)
    function connectTo( ?channelConfig : DataChannelInit ) {

        initiator = true;

        setDataChannel( connection.createDataChannel( createDataChannelId(), channelConfig ) );

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

    @:allow(om.rtc.mesh.Mesh)
    function connectFrom( sdp : SessionDescription ) {

        initiator = false;

        connection.ondatachannel = function(e){
            setDataChannel( e.channel );
        }

        return new Promise( function(resolve,reject) {
            connection.setRemoteDescription( sdp ).then( function(_){
                connection.createAnswer().then( function(answer){
                    connection.setLocalDescription( answer ).then( function(e){
                        resolve( connection.localDescription );
                    });
                });
            });
        });
    }

    @:allow(om.rtc.mesh.Mesh)
    function addIceCandidate( candidate : IceCandidate ) : Promise<Void> {
        return connection.addIceCandidate( new IceCandidate( candidate ) );
    }

    @:allow(om.rtc.mesh.Mesh)
    function setRemoteDescription( sdp : SessionDescription ) {
        //if( !initiator )
        return connection.setRemoteDescription( sdp );
    }

    @:allow(om.rtc.mesh.Mesh)
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
            onMessage( Json.parse( e.data ) );
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

    function createDataChannelId( length = 16 ) : String {
        return Util.createRandomString( length );
    }
}
