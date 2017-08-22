package om.rtc.mesh;

import js.Promise;
import js.html.WebSocket;
import js.Browser.console;
import om.Nil;

class Server {

    public dynamic function signal( msg : Message ) {}

    public var ip(default,null) : String;
    public var port(default,null) : Int;
    public var connected(default,null) : Bool;

    var socket : WebSocket;

    public function new( ip : String, port : Int ) {
        this.ip = ip;
        this.port = port;
        connected = false;
    }

    public function connect() : Promise<Nil> {

        return new Promise( function(resolve,reject){

            socket = new WebSocket( 'ws://$ip:$port' );
            socket.addEventListener( 'open', function(e){
                resolve( nil );
            });
            socket.addEventListener( 'close', function(e){
                console.log( e);
                reject( 'server error '+e.code );
            });
            socket.addEventListener( 'error', function(e){
                console.log( e);
                reject( 'server error '+e.code );
            });
            socket.addEventListener( 'message', function(e){
                var msg : Message = try Json.parse( e.data ) catch(e:Dynamic) {
                    console.warn(e);
                    return;
                }
                handleMessage( msg );
            });
        });
    }

    public function disconnect() {
        socket.close();
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

    function handleMessage( msg : Message ) {
        signal( msg );
    }
}
