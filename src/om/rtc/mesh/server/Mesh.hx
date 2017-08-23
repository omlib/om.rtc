package om.rtc.mesh.server;

import js.Node.console;

class Mesh {

    public var id(default,null) : String;
    public var nodes(default,null): Map<String,Node>;

    public function new( id : String ) {
        this.id = id;
        nodes = new Map();
    }

    //public function start() {}
    //public function stop() {}

    public inline function iterator() : Iterator<Node>
        return nodes.iterator();

    public inline function has( id : String ) : Bool
        return nodes.exists( id );

    public function add( node : Node ) : Bool {
        if( has( id ) )
            return false;
        nodes.set( node.id, node );
        node.meshes.push( id );
        return true;
    }

    public function remove( id : String ) : Bool {
        if( !has( id ) )
            return false;
        var node = nodes.get( id );
        nodes.remove( id );
        node.meshes.remove( this.id );
        return true;
    }

    public function broadcast( str : String )
        for( n in nodes ) n.sendString( str );

}
