package om.rtc.mesh.server;

import js.Node.console;

class Mesh {

    public var id(default,null) : String;
    public var nodes(default,null): Map<String,Node>;

    public function new( id : String ) {
        this.id = id;
        nodes = new Map();
    }

    public inline function iterator() : Iterator<Node> {
        return nodes.iterator();
    }

    //public function start() {}
    //public function stop() {}

    public inline function hasNode( id : String ) : Bool {
        return nodes.exists( id );
    }

    public function addNode( node : Node ) : Bool {
        if( hasNode( id ) )
            return false;
        nodes.set( node.id, node );
        return true;
    }

    public function removeNode( id : String ) : Bool {
        if( !hasNode( id ) )
            return false;
        nodes.remove( id );
        return true;
    }

    public function handleNodeMessage( node : Node, msg : Dynamic ) {

        /*
        switch msg.type {
        case 'join':
            node.sendMessage( { type: 'join', mesh: id, data: [for(n in nodes) if(n != node) n.id] } );
            if( !hasNode( node.id ) )
                nodes.set( node.id, node );
        }
        */
        /*
        if( !hasNode( node.id ) ) {
            if( msg.type != 'join' ) {
                node.sendError( 'not joined' );
                return;
            }
            node.sendMessage( { type: 'join', mesh: id, data: [for(n in nodes) n.id] } );
            nodes.set( node.id, node );
            return;
        }
        trace( msg );
        */
            //case 'join':
            //    node.sendMessage( { type: 'join', data: [for(n in nodes) n.id] } );
            //}
    }

    public function broadcast( str : String ) {
        for( node in nodes ) {
            node.sendString( str );
        }
    }
}
