package om.rtc.mesh.signal;

import haxe.Json;
import js.node.Buffer;
import js.node.net.Socket;
import om.net.WebSocket;
import om.rtc.mesh.signal.Message;

class Peer {

    public dynamic function onConnect() {}
    public dynamic function onDisconnect() {}
    public dynamic function onMessage( msg : Buffer ) {}

    public var id(default,null) : String;
    public var pools(default,null) : Map<String,Pool>;
    //public var pools(default,null) : Array<Pool>;

    public var ip(get,null) : String;
    inline function get_ip() return socket.remoteAddress;

    var socket : Socket;
    var isWebSocket : Bool;

    public function new( socket : Socket, id : String ) {

        this.socket = socket;
        this.id = id;

        pools = new Map();

        socket.once( 'close', function(e) {
            onDisconnect();
        });

        socket.addListener( 'data', function(buf:Buffer) {

            if( buf == null ) return;

            if( isWebSocket == null ) {
                if( buf.slice( 0, 10 ).toString() == 'GET / HTTP' ) {
                    isWebSocket = true;
                    socket.write( WebSocket.createHandshake( buf ) );
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

            onMessage( buf );
        });
    }

    public function sendBuffer( buf : Buffer ) {
        if( isWebSocket ) buf = WebSocket.writeFrame( buf );
        socket.write( buf );
    }

    public inline function sendString( str : String ) {
        sendBuffer( new Buffer( str ) );
    }

    public function sendMessage( msg : Dynamic ) {
        var str = try Json.stringify( msg ) catch(e:Dynamic) {
            trace( e );
            return;
        }
        sendString( str );
    }

    public function disconnect() {
        socket.end();
    }
}
