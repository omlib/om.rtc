package om.rtc.mesh;

import js.Promise;
import js.html.WebSocket;
import js.Browser.console;
import om.Nil;

class Server {

    public dynamic function onConnect() {}
    public dynamic function onDisconnect( ?error : String ) {}

    public dynamic function onSignal( msg : Message ) {}

    public var ip(default,null) : String;
    public var port(default,null) : Int;
    public var connected(default,null) : Bool;

    var socket : WebSocket;

    public function new() {
        connected = false;
    }

    public function connect( ip : String, port : Int ) : Promise<Server> {

        this.ip = ip;
        this.port = port;
        connected = false;

        return new Promise( function(resolve,reject){

            socket = new WebSocket( 'ws://$ip:$port' );
            socket.addEventListener( 'open', function(e){
                resolve( this );
                onConnect();
            });
            socket.addEventListener( 'close', function(e){
                reject( null );
                onDisconnect( null );

            });
            socket.addEventListener( 'error', function(e){
                reject( e );
                onDisconnect( e );
            });
            socket.addEventListener( 'message', handleSocketMessage, false );
        });
    }

    public function disconnect() {
        if( socket != null ) {
            socket.removeEventListener( 'message', handleSocketMessage );
            socket.close();
            socket = null;
        }
    }

    public function sendSignal( msg : Message ) : String {
        var str = try Json.stringify( msg ) catch(e:Dynamic) {
            trace(e);
            return null;
        }
        socket.send( str );
        return str;
    }

    /*
    public function join( mesh : String ) {
        send( { type: 'join', data: { mesh: mesh } } );
    }
    */

    public inline function leave( mesh : String ) {
        sendSignal( { type: 'leave', data: { mesh: mesh } } );
    }

    /*
    function handleSocketConnect( e ) {
    }

    function handleSocketDisconnect( e ) {
        trace(e);
    }
    */

    function handleSocketMessage( e ) {
        var msg : Message = try Json.parse( e.data ) catch(e:Dynamic) {
            console.warn( e );
            return;
        }
        handleMessage( msg );
    }

    function handleMessage( msg : Message ) {
        onSignal( msg );
    }
}
