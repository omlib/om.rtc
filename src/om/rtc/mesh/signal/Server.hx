package om.rtc.mesh.signal;

#if nodejs

import haxe.Json;
import haxe.crypto.Base64;
import haxe.ds.IntMap;
import js.Promise;
import js.node.Buffer;
import js.node.Net;
import js.node.net.Socket;
import om.net.WebSocket;
import om.rtc.mesh.signal.Message;

private class Peer {

    public dynamic function onConnect() {}
    public dynamic function onDisconnect() {}
    public dynamic function onMessage( msg : Buffer ) {}

    public var id(default,null) : String;
    //public var pools(default,null) : Array<Pool>;
    public var pools(default,null) : Map<String,Pool>;

    var socket : Socket;
    var isWebSocket : Bool;

    public function new( socket : Socket, id : String ) {

        this.socket = socket;
        this.id = id;

        isWebSocket = null;
        pools = new Map();

        socket.once( 'close', function(e) {
            onDisconnect();
        });

        socket.addListener( 'data', function(buf:Buffer) {

            if( buf == null ) return;

            if( isWebSocket == null ) {
                if( buf.slice( 0, 10 ).toString() == 'GET / HTTP' ) {
                    socket.write( WebSocket.createHandshake( buf ) );
                    isWebSocket = true;
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

    public function send( msg : Dynamic ) {
        var str = try Json.stringify( msg ) catch(e:Dynamic) {
            trace( e );
            return;
        }
        if( isWebSocket ) {
            socket.write( WebSocket.writeFrame( new Buffer( str ) ) );
        } else {
            socket.write( new Buffer( str ) );
        }
    }

    public function disconnect() {
        socket.end();
    }
}

class Pool {

    public var id(default,null) : String;

    var map : Map<String,Peer>;

    function new( id : String ) {
        this.id = id;
        map = new Map();
    }

    public inline function iterator()
        return map.iterator();

    public inline function get( id : String ) : Peer
        return map.get( id );

    public function add( peer : Peer ) {

        if( map.exists( peer.id ) )
            return false;

        peer.send( {
            type: join,
            pool: id,
            data: {
                id: peer.id,
                //peers: [for(p in map) if(p.id != peer.id) p.id]
                peers: [for( p in map ) p.id]
            }
        });

        map.set( peer.id, peer );
        peer.pools.set( this.id, this );

        return true;
    }

    public function remove( peer : Peer ) {

        if( !map.exists( peer.id ) )
            return false;

        map.remove( peer.id );
        peer.pools.remove( this.id );

        return true;
    }
}

class Server {

    public dynamic function onPeerConnect( peer : Peer ) {}
    public dynamic function onPeerDisconnect( peer : Peer ) {}
    public dynamic function onPeerMessage( peer : Peer, msg : Dynamic ) {}

    public dynamic function onPoolCreate( pool : Pool ) {}
    public dynamic function onPoolJoin( pool : Pool, peer : Peer ) {}
    public dynamic function onPoolLeave( pool : Pool, peer : Peer ) {}

    public var ip(default,null) : String;
    public var port(default,null) : Int;

    var net : js.node.net.Server;
    var pools : Map<String,Pool>;
    var peers : Map<String,Peer>;

    public function new( ip : String, port : Int ) {
        this.ip = ip;
        this.port = port;
        peers = new Map();
        pools = new Map();
    }

    public function start() : Promise<Dynamic> {
        return new Promise( function(resolve,reject){
            net = Net.createServer( handleSocketConnect );
            net.listen( port, ip, function(){
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

    @:access(om.rtc.mesh.signal.Pool)
    public function createPool( id : String ) : Pool {
        if( pools.exists( id ) )
            return null;
        var pool = new Pool( id );
        pools.set( pool.id, pool );
        onPoolCreate( pool );
        return pool;
    }

    function handleSocketConnect( socket : Socket ) {

        var id = Util.createRandomString( 4 );
        var peer = new Peer( socket, id );
        peers.set( id, peer );
        peer.onConnect = function() {
            onPeerConnect( peer );
        }
        peer.onDisconnect = function() {
            for( pool in peer.pools ) {
                pool.remove( peer );
                onPoolLeave( pool, peer );
            }
            onPeerDisconnect( peer );
        }
        peer.onMessage = function(buf) {

            var str = buf.toString();
            var msg : Message = try Json.parse( str ) catch(e:Dynamic) {
                trace(e);
                return;
            }

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
                        //trace( 'New peer for '+pool.id+' : '+peer.id );
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

            case error:
                trace(msg);

            case offer,candidate,answer:
                if( pools.exists( msg.pool ) ) {
                    var pool = pools.get( msg.pool );
                    var receiver = pool.get( msg.peer );
                    msg.peer = id;
                    receiver.send( msg );
                } else {
                    trace( 'Pool does not exist '+msg.pool );
                }

            default:
                trace( 'Unknown type message: '+msg );
            }
        }
    }
}

#end
