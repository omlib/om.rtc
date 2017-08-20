package om.rtc.mesh.signal;

import js.Promise;
import js.Node.console;
import js.node.Buffer;
import js.node.Net;
import js.node.net.Socket;
import om.Nil;
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
    public var numPeers(default,null) : Int;

    var net : js.node.net.Server;
    var peers : Map<String,Peer>;
    var pools : Map<String,Pool>;

    public function new( ip : String, port : Int ) {
        this.ip = ip;
        this.port = port;
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
                resolve( nil );
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

    public function addPool<T:Pool>( pool : T ) : T {
        if( pools.exists( pool.id ) )
            return null;
        pools.set( pool.id, pool );
        return pool;
    }

    function createPool<T:Pool>( id : String ) : T {
        return addPool( cast new Pool( id ) );
    }

    function createPeerId( length = 16 ) : String {
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

        var peer = new Peer( socket, createPeerId() );
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
                console.error( e );
                return;
            }
            handlePeerMessage( peer, msg );
        }
    }

    function handlePeerMessage( peer : Peer, msg : Message ) {

        //Sys.println( 'Message '+peer.id+' > '+msg.peer+' : '+msg.type );
        //onPeerMessage( peer, msg );
        //console.log(haxe.format.JsonPrinter.print(msg,'\t'));
        //onsole.log(msg.type);

        switch msg.type {

        case join:
            //var pool = pools.exists( msg.pool ) ? pools.get( msg.pool ) : createPool( msg.pool );
            if( !pools.exists( msg.pool ) ) {
                console.error( 'pool does not exist '+msg.pool );
                return;
            }
            var pool = pools.get( msg.pool );
            if( pool.add( peer ) ) {
                onPoolJoin( pool, peer );
            }
            /*
            var pool : Pool;
            if( pools.exists( msg.pool ) ) {
                pool = pools.get( msg.pool );
            } else {
                if( (pool = createPool( msg.pool )) != null ) {
                    onPoolCreate( pool );
                    pool.start();
                }
            }
            if( pool != null ) {
                if( pool.add( peer ) ) {
                    onPoolJoin( pool, peer );
                }
            } else {
                //TODO send error
            }
            */

        case leave:
            if( pools.exists( msg.pool ) ) {
                var pool = pools.get( msg.pool );
                pool.remove( peer );
            }

        case ping:
            peer.sendMessage( { type: pong } );

        case pong:
            //

        case data:
            if( pools.exists( msg.pool ) ) {
                var pool = pools.get( msg.pool );
                if( pool.has( peer ) ) {
                    pool.receive( peer, msg );
                }
            }

        case error:
            //console.error(msg);

        case offer,candidate,answer:
            if( pools.exists( msg.pool ) ) {
                var pool = pools.get( msg.pool );
                var receiver = pool.get( msg.peer );
                if( receiver != null ) {
                    msg.peer = peer.id;
                    receiver.sendMessage( msg );
                } else {
                }
            } else {
                console.warn( 'Pool does not exist '+msg.pool );
            }

        /*
        #if om_rtc_monitor
        case monitor:
            peer.sendMessage( {
                type: monitor,
                data: [for(peer in peers){
                    id: peer.id
                }] } );
        #end
        */

        default:
            console.warn( 'Unknown type message: '+haxe.format.JsonPrinter.print(msg) );

        }
    }
}
