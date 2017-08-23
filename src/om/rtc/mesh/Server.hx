package om.rtc.mesh;

import js.Promise;
import js.html.WebSocket;
import js.Browser.console;
import om.Nil;

class Server {

    public dynamic function signal( msg : Message ) {}

    public dynamic function onConnect() {}
    public dynamic function onDisconnect( ?error : String ) {}

    public var ip(default,null) : String;
    public var port(default,null) : Int;
    public var connected(default,null) : Bool;

    var socket : WebSocket;

    public function new( ip : String, port : Int ) {
        this.ip = ip;
        this.port = port;
        connected = false;
    }

    public function connect() : Promise<Server> {

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

    public function send( msg : Message ) {
        var str = Json.stringify( msg );
        socket.send( str );
    }

    /*
    public function join( mesh : String ) {
        send( { type: 'join', data: { mesh: mesh } } );
    }

    public function leave( mesh : String ) {
        send( { type: 'leave', data: { mesh: mesh } } );
    }
    */

    public function disconnect() {
        if( socket != null ) {
            socket.removeEventListener( 'message', handleSocketMessage );
            socket.close();
            socket = null;
        }
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
        signal( msg );
    }
}
