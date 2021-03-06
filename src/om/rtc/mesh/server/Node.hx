package om.rtc.mesh.server;

import js.node.Buffer;
import js.node.net.Socket;
import js.Node.console;
import om.net.WebSocket;

@:require(nodejs)
class Node {

    public dynamic function onConnect() {}
    public dynamic function onDisconnect() {}
    public dynamic function onMessage( msg : Dynamic ) {}

    public var id(default,null) : String;
    public var meshes(default,null) : Array<String>;

    public var ip(get,null) : String;
    inline function get_ip() return socket.remoteAddress;

    public var isWebSocket(default,null) : Null<Bool>;

    var socket : Socket;

    public function new( id : String, socket : Socket ) {

        this.id = id;
        this.socket = socket;

        meshes = [];

        socket.once( 'close', function(e) {
            onDisconnect();
        });
        socket.addListener( 'data', function(buf:Buffer) {

            if( buf == null ) return;

            if( isWebSocket == null ) {
                if( buf.slice( 0, 10 ).toString() == 'GET / HTTP' ) { //TODO
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

            var str = buf.toString();
            var msg = try Json.parse( str ) catch(e:Dynamic){
                console.warn(e);
                return;
            }
            onMessage( msg );
        });
    }

    public inline function sendError( message : String ) {
        sendMessage( { type: 'error', data: message } );
    }

    public function sendMessage( msg : Dynamic ) {
        var str = try Json.stringify( msg ) catch(e:Dynamic) {
            trace( e );
            return;
        }
        sendString( str );
    }

    public inline function sendString( str : String ) {
        sendBuffer( new Buffer( str ) );
    }

    public function sendBuffer( buf : Buffer ) {
        if( isWebSocket ) buf = WebSocket.writeFrame( buf );
        socket.write( buf );
    }

    public function disconnect() {
        socket.end();
    }
}
