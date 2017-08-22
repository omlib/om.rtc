package om.rtc.mesh.server;

import js.Promise;
import js.node.Buffer;
import js.node.Net;
import js.node.net.Socket;
import js.Node.console;
import om.Nil;

class Server {

    public dynamic function onNodeConnect( node : Node ) {}
    public dynamic function onNodeDisconnect( node : Node ) {}
    public dynamic function onNodeMessage( node : Node, msg : Dynamic ) {}

    public var ip(default,null) : String;
    public var port(default,null) : Int;

    var net : js.node.net.Server;
    var nodes : Map<String,Node>;
    var meshes : Map<String,Mesh>;

    public function new( ip : String, port : Int ) {
        this.ip = ip;
        this.port = port;
        nodes = new Map();
        meshes = new Map();
    }

    public function start() {
        return new Promise( function(resolve,reject){
            net = Net.createServer( handleSocketConnect );
            net.on( 'error', function(e){
                reject( e );
            });
            net.listen( port, ip, function(){
                resolve( nil );
            });
        });
    }

    public function stop( ?callback : Void->Void ) {
        if( net != null ) {
            for( node in nodes ) node.disconnect();
            nodes = null;
            meshes = null;
            net.close( callback );
        }
    }

    public function createMesh( id : String ) : Mesh {
        if( meshes.exists( id ) )
            return null;
        var mesh = new Mesh( id );
        meshes.set( id, mesh );
        return mesh;
    }

    public function addMesh( mesh : Mesh ) : Bool {
        if( meshes.exists( mesh.id ) )
            return false;
        meshes.set( mesh.id, mesh );
        return true;
    }

    function handleSocketConnect( socket : Socket ) {

        socket.setKeepAlive( true );

        var node = new Node( createNodeId(), socket );
        nodes.set( node.id, node );
        node.onConnect = function() {
            onNodeConnect( node );
        }
        node.onDisconnect = function() {
            nodes.remove( node.id );
            onNodeDisconnect( node );
        }
        node.onMessage = function(msg) {
            onNodeMessage( node, msg );
            handleNodeMessage( node, msg );
        }
    }

    function handleNodeMessage( node : Node, msg : Dynamic ) {

        switch msg.type {

        case 'init':
            //TODO
            if( msg.data != null ) {
                trace(msg.data);
                trace(msg.data.key);
                trace(msg.data.monitor);
            }

        case 'join':
            if( !meshes.exists( msg.data.mesh ) ) {
                node.sendError( 'mesh does not exist' );
                return;
            }
            var mesh = meshes.get( msg.data.mesh );
            //mesh.handleNodeMessage( node, msg );
            if( mesh.addNode( node ) ) {
                node.sendMessage( {
                    type: 'join',
                    data: {
                        mesh: mesh.id,
                        nodes: [for(n in mesh.nodes) if(n != node) n.id]
                    }
                } );
            }

        case 'leave':
            if( !meshes.exists( msg.data.mesh ) ) {
                node.sendError( 'mesh does not exist' );
                return;
            }
            var mesh = meshes.get( msg.data.mesh );
            mesh.removeNode( node.id );

        case 'offer','answer','candidate':
            var receiver = nodes.get( msg.data.node );
            if( receiver == null ) {
                node.sendError( 'node does not exist' );
                return;
            }
            msg.data.node = node.id;
            receiver.sendMessage( msg );

        default:
            console.warn( 'Unknown message type: '+msg.type );
            node.sendError( 'unknown message type' );
        }
    }

    function createNodeId( length = 16 ) : String {
        var id : String = null;
        while( nodes.exists( id = Util.createRandomString( length ) ) ) {}
        return id;
    }
}
