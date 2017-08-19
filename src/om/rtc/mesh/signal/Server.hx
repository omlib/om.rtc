package om.rtc.mesh.signal;

import haxe.Json;
import haxe.Timer;
import haxe.crypto.Base64;
import haxe.ds.IntMap;
import js.Promise;
import js.node.Buffer;
import js.node.Net;
import js.node.net.Socket;
import om.net.WebSocket;
import om.rtc.mesh.signal.Message;

class Server {

    public dynamic function onError( error : String ) {}

    public dynamic function onPeerConnect( peer : Peer ) {}
    public dynamic function onPeerDisconnect( peer : Peer ) {}
    public dynamic function onPeerMessage( peer : Peer, msg : Dynamic ) {}

    public dynamic function onPoolCreate( pool : Pool ) {}
    public dynamic function onPoolJoin( pool : Pool, peer : Peer ) {}
    public dynamic function onPoolLeave( pool : Pool, peer : Peer ) {}

    public var ip(default,null) : String;
    public var port(default,null) : Int;
    public var updateInterval(default,null) : Int;

    var net : js.node.net.Server;
    var pools : Map<String,Pool>;
    var peers : Map<String,Peer>;
    var numPeers : Int;
    var timer : Timer;

    public function new( ip : String, port : Int, updateInterval : Int ) {
        this.ip = ip;
        this.port = port;
        this.updateInterval = updateInterval;
        peers = new Map();
        pools = new Map();
        numPeers = 0;
    }

    public function start() : Promise<Nil> {

        return new Promise( function(resolve,reject){

            net = Net.createServer( handleSocketConnect );
            net.on( 'error', function(e){
                onError(e);
            });
            net.listen( port, ip, function(){

                timer = new Timer( updateInterval );
                timer.run = update;

                resolve( null );
            });
        });
    }

    public function stop( callback : Void->Void ) {
        if( net != null ) {
            for( peer in peers ) peer.disconnect();
            peers = new Map();
            pools = new Map();
            net.close( callback );
        }
    }

    public function update() {
        for( pool in pools ) pool.update();
    }

    public function addPool( pool : Pool ) : Bool {
        if( pools.exists( pool.id ) )
            return false;
        pools.set( pool.id, pool );
        return true;
    }

    function createPool( id : String ) : Pool {
        if( pools.exists( id ) )
            return null;
        var pool = new Pool( id );
        pools.set( pool.id, pool );
        onPoolCreate( pool );
        return pool;
    }

    function createId( length = 16 ) : String {
        var id : String = null;
        while( true ) {
            id = Util.createRandomString( length );
            if( !peers.exists( id ) ) break;
        }
        return id;
    }

    function handleSocketConnect( socket : Socket ) {

        //socket.setTimeout();
        socket.setKeepAlive( true );

        var peer = new Peer( socket, createId() );
        peers.set( peer.id, peer );
        numPeers++;

        peer.onConnect = function() {
            onPeerConnect( peer );
        }
        peer.onDisconnect = function() {
            for( pool in peer.pools ) {
                pool.remove( peer );
                onPoolLeave( pool, peer );
            }
            peers.remove( peer.id );
            numPeers--;
            onPeerDisconnect( peer );
        }
        peer.onMessage = function(buf) {

            var str = buf.toString();
            var msg : Message = try Json.parse( str ) catch(e:Dynamic) {
                trace(e);
                return;
            }

            handlePeerMessage( peer, msg );
        }
    }

    function handlePeerMessage( peer : Peer, msg : Message ) {

        //Sys.println( haxe.format.JsonPrinter.print(msg));
        //Sys.println( 'Message '+peer.id+' > '+msg.peer+' : '+msg.type );
        onPeerMessage( peer, msg );

        switch msg.type {

        case join:
            //var pool = pools.exists( msg.pool ) ? pools.get( msg.pool ) : createPool( msg.pool );
            var pool : Pool;
            if( pools.exists( msg.pool ) ) {
                pool = pools.get( msg.pool );
            } else {
                pool = createPool( msg.pool );
            }
            if( pool != null ) {
                if( pool.add( peer ) ) {
                    onPoolJoin( pool, peer );
                }
            } else {
                //TODO send error
            }

        case leave:
            if( pools.exists( msg.pool ) ) {
                var pool = pools.get( msg.pool );
                pool.remove( peer );
            }

        case ping:
            peer.sendMessage( { type: pong } );

        case pong:
            //

        case error:
            trace(msg);

        case offer,candidate,answer:
            if( pools.exists( msg.pool ) ) {
                var pool = pools.get( msg.pool );
                var receiver = pool.get( msg.peer );
                if( receiver != null ) {
                    //msg.peer = id;
                    msg.peer = peer.id;
                    receiver.sendMessage( msg );
                } else {
                }
            } else {
                trace( 'Pool does not exist '+msg.pool );
            }

        default:
            trace( 'Unknown type message: '+haxe.format.JsonPrinter.print(msg) );
        }
    }
}
